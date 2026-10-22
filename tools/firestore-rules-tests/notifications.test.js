/**
 * Regras de `users/{uid}/notifications` (tarefa 14).
 *
 * Quem cria é o gatilho `onEventEnded` e quem marca "Avaliado" é a callable
 * da avaliação, as duas pelo Admin SDK. Pelo cliente, o dono só lê, marca
 * como lida uma única vez (com o horário do servidor) e apaga as suas na
 * exclusão de conta.
 */
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const DONO = 'uid_dono';
const OUTRO = 'uid_outro';
const NOTIFICACAO = 'eventEnded_evt_1';

let testEnv;

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
  await semear(notificacao());
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const ref = (db, uid = DONO) => doc(db, 'users', uid, 'notifications', NOTIFICACAO);

/** Espelha o que o gatilho `onEventEnded` grava. */
function notificacao(overrides = {}) {
  return {
    type: 'eventEnded',
    eventId: 'evt_1',
    eventTitle: 'Rachão',
    sport: 'basquete',
    creatorId: OUTRO,
    endedAutomatically: false,
    createdAt: new Date(),
    readAt: null,
    completedAt: null,
    ...overrides,
  };
}

async function semear(dados) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(ref(ctx.firestore()), dados);
  });
}

describe('notifications — leitura', () => {
  it('o dono lê as próprias notificações', async () => {
    await assertSucceeds(getDoc(ref(as(DONO))));
  });

  it('ninguém lê as notificações de outra pessoa', async () => {
    await assertFails(getDoc(ref(as(OUTRO))));
  });
});

describe('notifications — marcar como lida', () => {
  it('o dono marca como lida com o horário do servidor', async () => {
    await assertSucceeds(updateDoc(ref(as(DONO)), { readAt: serverTimestamp() }));
  });

  it('o horário tem que ser o do servidor', async () => {
    await assertFails(updateDoc(ref(as(DONO)), { readAt: new Date() }));
  });

  it('o dono não mexe em outro campo', async () => {
    await assertFails(updateDoc(ref(as(DONO)), { completedAt: serverTimestamp() }));
    await assertFails(
      updateDoc(ref(as(DONO)), { readAt: serverTimestamp(), eventTitle: 'Outro' }),
    );
  });

  it('não dá para marcar de novo uma notificação já lida', async () => {
    await semear(notificacao({ readAt: new Date() }));
    await assertFails(updateDoc(ref(as(DONO)), { readAt: serverTimestamp() }));
  });

  it('ninguém marca a notificação de outra pessoa', async () => {
    await assertFails(updateDoc(ref(as(OUTRO)), { readAt: serverTimestamp() }));
  });
});

describe('notifications — criar e apagar', () => {
  it('o cliente não cria notificação, nem para si', async () => {
    await assertFails(
      setDoc(doc(as(DONO), 'users', DONO, 'notifications', 'eventEnded_evt_2'), {
        ...notificacao(),
        eventId: 'evt_2',
      }),
    );
  });

  it('o dono apaga as próprias (exclusão de conta)', async () => {
    await assertSucceeds(deleteDoc(ref(as(DONO))));
  });

  it('ninguém apaga as de outra pessoa', async () => {
    await assertFails(deleteDoc(ref(as(OUTRO))));
  });
});
