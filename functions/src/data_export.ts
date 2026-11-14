import { getAuth } from 'firebase-admin/auth';
import { DocumentReference, GeoPoint, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall, type CallableRequest } from 'firebase-functions/v2/https';

import { administrativeFunctionsRegion } from './config.js';

/**
 * "Baixar meus dados" (chore/lgpd; LGPD art. 18, II e V, e art. 19, §3º).
 *
 * Devolve, em JSON, tudo o que o COMPY guarda sobre quem chamou: conta,
 * perfil, aceite, notificações, amizades, bloqueios, eventos, as mensagens que
 * a pessoa enviou, as avaliações que ela fez, a média que recebeu e as
 * denúncias que fez. Mensagens dos outros ficam de fora: são dados deles.
 */

export const exportFormat = 'compy-dados-v1';

/** Timestamps viram ISO 8601, GeoPoints viram coordenadas, referências viram caminho. */
export function serializeForExport(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (value instanceof GeoPoint) return { latitude: value.latitude, longitude: value.longitude };
  if (value instanceof DocumentReference) return value.path;
  if (Array.isArray(value)) return value.map(serializeForExport);
  if (value !== null && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serializeForExport(item)]));
  }
  return value;
}

export interface DataExportGateway {
  collect(uid: string): Promise<Record<string, unknown>>;
}

export function createExportMyDataHandler(gateway: DataExportGateway, now: () => Date = () => new Date()) {
  return async (request: Pick<CallableRequest<unknown>, 'auth'>): Promise<Record<string, unknown>> => {
    const uid = request.auth?.uid;
    if (uid === undefined) throw new HttpsError('unauthenticated', 'Entre na sua conta para baixar seus dados.');
    const data = await gateway.collect(uid);
    return {
      formato: exportFormat,
      geradoEm: now().toISOString(),
      ...(serializeForExport(data) as Record<string, unknown>),
    };
  };
}

export function createFirestoreDataExportGateway(): DataExportGateway {
  const firestore = getFirestore();

  const withId = (doc: FirebaseFirestore.QueryDocumentSnapshot) => ({ id: doc.id, ...doc.data() });

  return {
    collect: async (uid) => {
      const userRef = firestore.collection('users').doc(uid);
      const authUser = await getAuth().getUser(uid).catch(() => null);

      const [
        profile, contact, consent, notifications, blocks, friendships,
        createdEvents, joinedEvents, conversations, ratings, summary, reports,
      ] = await Promise.all([
        userRef.get(),
        userRef.collection('private').doc('contact').get(),
        userRef.collection('private').doc('consent').get(),
        userRef.collection('notifications').get(),
        userRef.collection('blocks').get(),
        firestore.collection('friendships').where('members', 'array-contains', uid).get(),
        firestore.collection('events').where('creator.id', '==', uid).get(),
        firestore.collection('events').where('participantIds', 'array-contains', uid).get(),
        firestore.collection('conversations').where('members', 'array-contains', uid).get(),
        firestore.collection('ratings').where('fromUid', '==', uid).get(),
        firestore.collection('ratingSummaries').doc(`user_${uid}`).get(),
        firestore.collection('reports').where('reporterId', '==', uid).get(),
      ]);

      const conversationExports = await Promise.all(conversations.docs.map(async (conversation) => {
        const sent = await conversation.ref.collection('messages').where('senderId', '==', uid).get();
        const data = conversation.data();
        return {
          id: conversation.id,
          participantes: data.members ?? [],
          mensagensEnviadas: sent.docs.map(withId),
        };
      }));

      return {
        conta: authUser === null ? null : {
          uid: authUser.uid,
          email: authUser.email ?? null,
          emailVerificado: authUser.emailVerified,
          provedores: authUser.providerData.map((provider) => provider.providerId),
          criadaEm: authUser.metadata.creationTime,
          ultimoAcesso: authUser.metadata.lastSignInTime,
        },
        perfil: profile.data() ?? null,
        contato: contact.data() ?? null,
        aceiteETermos: consent.data() ?? null,
        notificacoes: notifications.docs.map(withId),
        bloqueios: blocks.docs.map((doc) => ({ uidBloqueado: doc.id, ...doc.data() })),
        amizades: friendships.docs.map(withId),
        eventosCriados: createdEvents.docs.map(withId),
        eventosInscritos: joinedEvents.docs.filter((doc) => !createdEvents.docs.some((own) => own.id === doc.id))
          .map(withId),
        conversas: conversationExports,
        avaliacoesFeitas: ratings.docs.map(withId),
        mediaRecebida: summary.data() ?? null,
        denunciasFeitas: reports.docs.map((doc) => {
          // Quem fechou a denúncia é um Administrador: o uid dele não é
          // dado de quem denunciou.
          const { resolvedBy, ...rest } = doc.data();
          void resolvedBy;
          return { id: doc.id, ...rest };
        }),
      };
    },
  };
}

// App Check desligado pelo mesmo motivo de `submitEventRatings`: sem a
// imposição no projeto, ligar aqui só quebraria o build debug e a web.
export const exportMyData = onCall(
  { region: administrativeFunctionsRegion, enforceAppCheck: false, timeoutSeconds: 120 },
  (request) => createExportMyDataHandler(createFirestoreDataExportGateway())(request),
);
