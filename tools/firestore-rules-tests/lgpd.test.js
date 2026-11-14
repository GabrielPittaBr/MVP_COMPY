/**
 * Regras da LGPD e do ECA Digital (chore/lgpd): aceite com data de
 * nascimento, bloqueios, denúncias e o chat de quem tem 16 ou 17 anos só
 * com amigos.
 *
 *   npm --prefix tools/firestore-rules-tests test
 */
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const ANA = 'uid_ana';         // adulta
const BETO = 'uid_beto';       // adulto
const CAIO = 'uid_caio';       // 17 anos
const DUDA = 'uid_duda';       // 16 anos, amiga do Beto
const ADMIN = 'uid_admin';

let testEnv;

const YEAR_MS = 365.25 * 24 * 60 * 60 * 1000;

/** Data de nascimento de quem tem [years] anos hoje (com folga de 10 dias). */
const bornYearsAgo = (years) => new Date(Date.now() - years * YEAR_MS - 10 * 24 * 3600 * 1000);

const adultAtOf = (birth) => {
  const adult = new Date(birth);
  adult.setFullYear(adult.getFullYear() + 18);
  return adult;
};

const consent = (birth, overrides = {}) => ({
  termsVersion: '2026-11-14',
  acceptedAt: serverTimestamp(),
  birthDate: birth,
  adultAt: adultAtOf(birth),
  ...overrides,
});

const pair = (a, b) => (a < b ? `${a}:${b}` : `${b}:${a}`);

const conversationDoc = (members) => ({
  members,
  memberSummaries: Object.fromEntries(
    members.map((uid) => [uid, { id: uid, name: uid, handle: `@${uid}`, avatarUrl: '' }]),
  ),
  lastMessage: '',
  lastMessageAt: new Date(),
  unreadCounts: Object.fromEntries(members.map((uid) => [uid, 0])),
});

const message = (senderId, text = 'Oi!') => ({ senderId, text, sentAt: serverTimestamp() });

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-compy',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of [ANA, BETO, CAIO, DUDA]) {
      await setDoc(doc(db, 'users', uid), { id: uid, name: uid, handle: `@${uid}` });
    }
    await setDoc(doc(db, 'users', ANA, 'private', 'consent'), consent(bornYearsAgo(30), { acceptedAt: new Date() }));
    await setDoc(doc(db, 'users', CAIO, 'private', 'consent'), consent(bornYearsAgo(17), { acceptedAt: new Date() }));
    await setDoc(doc(db, 'users', DUDA, 'private', 'consent'), consent(bornYearsAgo(16), { acceptedAt: new Date() }));
    // Beto não tem aceite: conta anterior à LGPD, vale como adulto.
    const requested = new Date();
    await setDoc(doc(db, 'friendships', pair(BETO, DUDA)), {
      members: [BETO, DUDA].sort(),
      senderId: DUDA,
      status: 'accepted',
      requestedAt: requested,
      acceptedAt: requested,
    });
    await setDoc(doc(db, 'conversations', 'ana_caio'), conversationDoc([ANA, CAIO]));
    await setDoc(doc(db, 'conversations', 'ana_beto'), conversationDoc([ANA, BETO]));
    await setDoc(doc(db, 'conversations', 'beto_duda'), conversationDoc([BETO, DUDA]));
    await setDoc(doc(db, 'conversations', 'ana_beto', 'messages', 'm1'), {
      senderId: BETO,
      text: 'Mensagem ofensiva',
      sentAt: new Date(),
    });
    await setDoc(doc(db, 'events', 'evento1'), {
      creator: { id: BETO, name: BETO, handle: `@${BETO}`, avatarUrl: '' },
      title: 'Futebol',
    });
  });
});

const as = (uid, claims) => testEnv.authenticatedContext(uid, claims).firestore();

describe('aceite e data de nascimento', () => {
  const novo = 'uid_novo';

  it('o dono grava o aceite com 16 anos ou mais', async () => {
    await assertSucceeds(setDoc(doc(as(novo), 'users', novo, 'private', 'consent'), consent(bornYearsAgo(16))));
  });

  it('recusa quem tem menos de 16 anos', async () => {
    await assertFails(setDoc(doc(as(novo), 'users', novo, 'private', 'consent'), consent(bornYearsAgo(15))));
  });

  it('recusa 18º aniversário incoerente com a data de nascimento', async () => {
    const birth = bornYearsAgo(17);
    await assertFails(setDoc(doc(as(novo), 'users', novo, 'private', 'consent'),
      consent(birth, { adultAt: new Date(Date.now() - 1000) })));
  });

  it('recusa aceite com horário escolhido pelo app', async () => {
    await assertFails(setDoc(doc(as(novo), 'users', novo, 'private', 'consent'),
      consent(bornYearsAgo(20), { acceptedAt: new Date(2020, 0, 1) })));
  });

  it('recusa campos fora da lista e documentos privados desconhecidos', async () => {
    await assertFails(setDoc(doc(as(novo), 'users', novo, 'private', 'consent'),
      consent(bornYearsAgo(20), { apelido: 'x' })));
    await assertFails(setDoc(doc(as(novo), 'users', novo, 'private', 'outro'), { a: 1 }));
  });

  it('ninguém além do dono lê o aceite', async () => {
    await assertSucceeds(getDoc(doc(as(CAIO), 'users', CAIO, 'private', 'consent')));
    await assertFails(getDoc(doc(as(ANA), 'users', CAIO, 'private', 'consent')));
  });

  it('aceita nova versão dos Termos com a hora do servidor', async () => {
    const ref = doc(as(ANA), 'users', ANA, 'private', 'consent');
    await assertSucceeds(updateDoc(ref, { termsVersion: '2027-01-01', acceptedAt: serverTimestamp() }));
  });

  it('não deixa trocar a data de nascimento pelo app', async () => {
    const ref = doc(as(CAIO), 'users', CAIO, 'private', 'consent');
    const birth = bornYearsAgo(25);
    await assertFails(updateDoc(ref, { birthDate: birth, adultAt: adultAtOf(birth), acceptedAt: serverTimestamp() }));
  });

  it('não deixa trocar a versão dos Termos sem novo aceite', async () => {
    const ref = doc(as(ANA), 'users', ANA, 'private', 'consent');
    await assertFails(updateDoc(ref, { termsVersion: '2027-01-01' }));
  });

  it('grava a faixa da Google Play sem mexer no aceite', async () => {
    const ref = doc(as(ANA), 'users', ANA, 'private', 'consent');
    await assertSucceeds(updateDoc(ref, { ageSignal: { lower: 18, checkedAt: new Date() } }));
    await assertFails(updateDoc(ref, { ageSignal: { lower: 'x', checkedAt: new Date() } }));
  });
});

describe('bloqueios', () => {
  it('o dono bloqueia, lista e desbloqueia', async () => {
    const db = as(ANA);
    await assertSucceeds(setDoc(doc(db, 'users', ANA, 'blocks', BETO), { createdAt: serverTimestamp() }));
    await assertSucceeds(getDocs(collection(db, 'users', ANA, 'blocks')));
    await assertSucceeds(deleteDoc(doc(db, 'users', ANA, 'blocks', BETO)));
  });

  it('ninguém vê nem mexe nos bloqueios dos outros', async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'users', ANA, 'blocks', BETO), { createdAt: new Date() }));
    await assertFails(getDoc(doc(as(BETO), 'users', ANA, 'blocks', BETO)));
    await assertFails(deleteDoc(doc(as(BETO), 'users', ANA, 'blocks', BETO)));
  });

  it('não bloqueia a si mesmo nem grava campos extras', async () => {
    await assertFails(setDoc(doc(as(ANA), 'users', ANA, 'blocks', ANA), { createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as(ANA), 'users', ANA, 'blocks', BETO), { createdAt: serverTimestamp(), motivo: 'x' }));
  });
});

describe('conversas com bloqueio e com quem tem 16 ou 17 anos', () => {
  const block = (owner, target) => testEnv.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), 'users', owner, 'blocks', target), { createdAt: new Date() }));

  it('adultos sem bloqueio conversam como antes', async () => {
    await assertSucceeds(setDoc(doc(as(ANA), 'conversations', 'nova'), conversationDoc([ANA, BETO])));
    await assertSucceeds(setDoc(doc(as(ANA), 'conversations', 'ana_beto', 'messages', 'm2'), message(ANA)));
  });

  it('desconhecido não inicia conversa com quem tem 17 anos', async () => {
    await assertFails(setDoc(doc(as(BETO), 'conversations', 'nova'), conversationDoc([BETO, CAIO])));
    await assertFails(setDoc(doc(as(CAIO), 'conversations', 'nova'), conversationDoc([BETO, CAIO])));
  });

  it('amigos conversam mesmo com 16 anos', async () => {
    await assertSucceeds(setDoc(doc(as(BETO), 'conversations', 'nova'), conversationDoc([BETO, DUDA])));
    await assertSucceeds(setDoc(doc(as(DUDA), 'conversations', 'beto_duda', 'messages', 'm2'), message(DUDA)));
  });

  it('conversa antiga com quem tem 17 anos fica fechada sem amizade', async () => {
    await assertFails(setDoc(doc(as(ANA), 'conversations', 'ana_caio', 'messages', 'm2'), message(ANA)));
    await assertFails(setDoc(doc(as(CAIO), 'conversations', 'ana_caio', 'messages', 'm2'), message(CAIO)));
    // Ler o histórico continua permitido.
    await assertSucceeds(getDocs(collection(as(CAIO), 'conversations', 'ana_caio', 'messages')));
  });

  it('faixa da Google Play de 16–17 anos vale mesmo com data adulta', async () => {
    await testEnv.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), 'users', ANA, 'private', 'consent'),
      { ageSignal: { lower: 16, upper: 17, checkedAt: new Date() } }));
    await assertFails(setDoc(doc(as(BETO), 'conversations', 'ana_beto', 'messages', 'm2'), message(BETO)));
  });

  it('bloqueio fecha a conversa nos dois sentidos', async () => {
    await block(ANA, BETO);
    await assertFails(setDoc(doc(as(BETO), 'conversations', 'ana_beto', 'messages', 'm2'), message(BETO)));
    await assertFails(setDoc(doc(as(ANA), 'conversations', 'ana_beto', 'messages', 'm2'), message(ANA)));
    await assertFails(setDoc(doc(as(BETO), 'conversations', 'nova'), conversationDoc([ANA, BETO])));
  });

  it('bloqueio impede pedido de amizade nos dois sentidos', async () => {
    await block(ANA, BETO);
    const request = (sender) => ({
      members: [ANA, BETO].sort(),
      senderId: sender,
      status: 'pending',
      requestedAt: serverTimestamp(),
    });
    await assertFails(setDoc(doc(as(BETO), 'friendships', pair(ANA, BETO)), request(BETO)));
    await assertFails(setDoc(doc(as(ANA), 'friendships', pair(ANA, BETO)), request(ANA)));
  });
});

describe('denúncias', () => {
  const report = (overrides = {}) => ({
    reporterId: ANA,
    targetType: 'user',
    targetId: BETO,
    targetUid: BETO,
    reason: 'harassment',
    details: '',
    priority: 1,
    status: 'open',
    createdAt: serverTimestamp(),
    ...overrides,
  });

  it('denuncia perfil, evento e mensagem', async () => {
    const db = as(ANA);
    await assertSucceeds(setDoc(doc(db, 'reports', 'r1'), report()));
    await assertSucceeds(setDoc(doc(db, 'reports', 'r2'), report({ targetType: 'event', targetId: 'evento1' })));
    await assertSucceeds(setDoc(doc(db, 'reports', 'r3'), report({
      targetType: 'message',
      targetId: 'm1',
      conversationId: 'ana_beto',
      messageText: 'Mensagem ofensiva',
    })));
  });

  it('recusa cópia de mensagem adulterada ou de conversa alheia', async () => {
    const forged = report({ targetType: 'message', targetId: 'm1', conversationId: 'ana_beto', messageText: 'outro texto' });
    await assertFails(setDoc(doc(as(ANA), 'reports', 'r1'), forged));
    const outsider = report({
      reporterId: CAIO,
      targetType: 'message',
      targetId: 'm1',
      conversationId: 'ana_beto',
      messageText: 'Mensagem ofensiva',
    });
    await assertFails(setDoc(doc(as(CAIO), 'reports', 'r1'), outsider));
  });

  it('recusa autor errado, denúncia em nome de outro e prioridade trocada', async () => {
    await assertFails(setDoc(doc(as(ANA), 'reports', 'r1'), report({ targetType: 'event', targetId: 'evento1', targetUid: CAIO })));
    await assertFails(setDoc(doc(as(ANA), 'reports', 'r1'), report({ reporterId: CAIO })));
    await assertFails(setDoc(doc(as(ANA), 'reports', 'r1'), report({ reason: 'childSafety', priority: 1 })));
    await assertSucceeds(setDoc(doc(as(ANA), 'reports', 'r1'), report({ reason: 'childSafety', priority: 0 })));
    await assertFails(setDoc(doc(as(ANA), 'reports', 'r2'), report({ targetId: ANA, targetUid: ANA })));
  });

  it('só o Administrador lê e fecha', async () => {
    await assertSucceeds(setDoc(doc(as(ANA), 'reports', 'r1'), report()));
    await assertFails(getDoc(doc(as(ANA), 'reports', 'r1')));
    const admin = as(ADMIN, { admin: true });
    await assertSucceeds(getDocs(collection(admin, 'reports')));
    const close = {
      status: 'resolved',
      resolvedAt: serverTimestamp(),
      resolvedBy: ADMIN,
      resolution: 'Conta suspensa.',
      expiresAt: new Date(Date.now() + 365 * 24 * 3600 * 1000),
    };
    await assertFails(updateDoc(doc(as(BETO), 'reports', 'r1'), close));
    await assertFails(updateDoc(doc(admin, 'reports', 'r1'), { ...close, expiresAt: new Date() }));
    await assertSucceeds(updateDoc(doc(admin, 'reports', 'r1'), close));
    await assertFails(deleteDoc(doc(admin, 'reports', 'r1')));
  });
});

describe('exclusão de conta pelo app', () => {
  it('o dono apaga os documentos privados junto com o perfil', async () => {
    const db = as(CAIO);
    const batch = writeBatch(db);
    batch.delete(doc(db, 'users', CAIO, 'private', 'consent'));
    batch.delete(doc(db, 'users', CAIO, 'private', 'contact'));
    batch.delete(doc(db, 'users', CAIO));
    await assertSucceeds(batch.commit());
  });
});
