import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { administrativeCallableOptions, type AdministrativeCallableRequest } from './admin_auth_read.js';
import {
  createFirestoreDeletionOperationsGateway,
  deleteDocuments,
  parseDeletionInput,
  refuseDeletion,
  requireAdministrator,
  runDeletionOperation,
  type DeletionOperationsGateway,
} from './admin_deletion.js';

export interface DeletableAuthAccount {
  readonly uid: string;
  readonly customClaims?: Readonly<Record<string, unknown>>;
}

/**
 * Passos da exclusão de conta. Todos toleram o que já foi apagado, porque a
 * repetição de uma operação pending passa por eles de novo.
 */
export interface AccountDeletionGateway {
  /** `null` quando a conta não existe no Firebase Auth. */
  getAccount(uid: string): Promise<DeletableAuthAccount | null>;
  hasProfile(uid: string): Promise<boolean>;
  /** Desabilita a conta e revoga as sessões. */
  disable(uid: string): Promise<void>;
  /** Fotos de perfil em `users/{uid}/` no Storage. */
  deletePhotos(uid: string): Promise<void>;
  /** Reserva em `usernames`, o perfil e as subcoleções dele. */
  deleteProfileData(uid: string): Promise<void>;
  /** Apaga a conta do Auth; conta já ausente não é erro. */
  deleteAccount(uid: string): Promise<void>;
}

export interface UserAccountDeletionResult {
  readonly uid: string;
  readonly completedAt: string;
}

/**
 * Apaga o mesmo que a exclusão feita pelo próprio app: fotos, reserva do
 * username, perfil com os dados privados e as Notificações, e a conta do
 * Auth. Eventos organizados, participações, mensagens e Avaliações ficam,
 * como lá.
 *
 * **A ordem é o contrato:** primeiro a conta é desabilitada, para nenhum
 * login novo acontecer no meio; a conta só some do Auth no fim. Uma falha no
 * meio deixa a conta desabilitada — o estado seguro — e a operação pending,
 * que a repetição termina. Um ID token já emitido continua aceito até
 * expirar (cerca de 1h), o mesmo limite da suspensão.
 */
export function createDeleteUserAccountHandler(
  accounts: AccountDeletionGateway,
  operations: DeletionOperationsGateway,
) {
  return async (request: AdministrativeCallableRequest): Promise<UserAccountDeletionResult> => {
    const adminUid = requireAdministrator(request);
    const input = parseDeletionInput(adminUid, request.data, 'deleteUserAccount', 'uid');
    if (input.targetId === adminUid) {
      throw new HttpsError('failed-precondition', 'Um Administrador não pode excluir a própria conta.');
    }
    const uid = input.targetId;
    const result = await runDeletionOperation(operations, input, async ({ isNew }) => {
      const account = await accounts.getAccount(uid);
      if (account?.customClaims?.admin === true) refuseDeletion('permission-denied');
      // Perfil sem conta (registro órfão) pode ser excluído; sem nenhum dos
      // dois não há o que excluir. Numa repetição, a tentativa anterior pode
      // já ter apagado os dois.
      if (account === null && isNew && !(await accounts.hasProfile(uid))) refuseDeletion('not-found');

      if (account !== null) await accounts.disable(uid);
      await accounts.deletePhotos(uid);
      await accounts.deleteProfileData(uid);
      if (account !== null) await accounts.deleteAccount(uid);
    });
    return { uid: result.targetId, completedAt: result.completedAt };
  };
}

function isUserNotFound(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && error.code === 'auth/user-not-found';
}

export function createFirebaseAccountDeletionGateway(): AccountDeletionGateway {
  const firestore = getFirestore();
  return {
    getAccount: async (uid) => {
      try {
        const user = await getAuth().getUser(uid);
        return { uid: user.uid, ...(user.customClaims === undefined ? {} : { customClaims: user.customClaims }) };
      } catch (error) {
        if (isUserNotFound(error)) return null;
        throw error;
      }
    },
    hasProfile: async (uid) => (await firestore.collection('users').doc(uid).get()).exists,
    disable: async (uid) => {
      await getAuth().updateUser(uid, { disabled: true });
      await getAuth().revokeRefreshTokens(uid);
    },
    deletePhotos: async (uid) => {
      await getStorage().bucket().deleteFiles({ prefix: `users/${uid}/` });
    },
    // A reserva é procurada pelo uid, e não derivada do handle: numa
    // repetição o perfil (e com ele o handle) pode já ter sido apagado.
    deleteProfileData: async (uid) => {
      const usernames = await firestore.collection('usernames').where('uid', '==', uid).get();
      await deleteDocuments(firestore, usernames.docs.map((doc) => doc.ref));
      await firestore.recursiveDelete(firestore.collection('users').doc(uid));
    },
    deleteAccount: async (uid) => {
      try {
        await getAuth().deleteUser(uid);
      } catch (error) {
        if (!isUserNotFound(error)) throw error;
      }
    },
  };
}

export const deleteUserAccount = onCall(administrativeCallableOptions, (request) =>
  createDeleteUserAccountHandler(createFirebaseAccountDeletionGateway(), createFirestoreDeletionOperationsGateway())(
    request,
  ),
);
