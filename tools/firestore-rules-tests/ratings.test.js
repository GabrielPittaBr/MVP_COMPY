/**
 * Regras de `ratings` e `ratingSummaries` (tarefa 14).
 *
 * Quem grava é só a callable `submitEventRatings`, com o Admin SDK. Pelo
 * cliente, `ratings` fica 100% fechada (D13: comentário não é público) e
 * `ratingSummaries` é só leitura para quem está logado.
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
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const AUTOR = 'uid_autor';
const RATING = 'evt_1_uid_autor_event_evt_1';
const RESUMO = 'event_evt_1';

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
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'ratings', RATING), avaliacao());
    await setDoc(doc(ctx.firestore(), 'ratingSummaries', RESUMO), resumo());
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anonimo = () => testEnv.unauthenticatedContext().firestore();

/** Espelha o que a callable grava. */
function avaliacao() {
  return {
    eventId: 'evt_1',
    fromUid: AUTOR,
    targetType: 'event',
    targetId: 'evt_1',
    stars: 5,
    comment: 'Muito bom.',
    createdAt: new Date(),
  };
}

function resumo() {
  return {
    targetType: 'event',
    targetId: 'evt_1',
    count: 1,
    sum: 5,
    starCounts: { 5: 1 },
    updatedAt: new Date(),
  };
}

describe('ratings — fechada ao cliente', () => {
  it('nem o autor lê a própria avaliação (D13)', async () => {
    await assertFails(getDoc(doc(as(AUTOR), 'ratings', RATING)));
  });

  it('o cliente não cria avaliação, nem a própria e válida', async () => {
    await assertFails(
      setDoc(doc(as(AUTOR), 'ratings', 'evt_2_uid_autor_event_evt_2'), {
        ...avaliacao(),
        eventId: 'evt_2',
        targetId: 'evt_2',
      }),
    );
  });

  it('ninguém reescreve uma avaliação', async () => {
    await assertFails(updateDoc(doc(as(AUTOR), 'ratings', RATING), { stars: 1 }));
  });

  it('ninguém apaga uma avaliação', async () => {
    await assertFails(deleteDoc(doc(as(AUTOR), 'ratings', RATING)));
  });
});

describe('ratingSummaries — só leitura', () => {
  it('quem está logado lê a média', async () => {
    await assertSucceeds(getDoc(doc(as('uid_qualquer'), 'ratingSummaries', RESUMO)));
  });

  it('deslogado não lê', async () => {
    await assertFails(getDoc(doc(anonimo(), 'ratingSummaries', RESUMO)));
  });

  it('o cliente não escreve no agregado', async () => {
    await assertFails(
      setDoc(doc(as(AUTOR), 'ratingSummaries', 'place_p1'), {
        ...resumo(),
        targetType: 'place',
        targetId: 'p1',
      }),
    );
    await assertFails(
      updateDoc(doc(as(AUTOR), 'ratingSummaries', RESUMO), { count: 99, sum: 495 }),
    );
    await assertFails(deleteDoc(doc(as(AUTOR), 'ratingSummaries', RESUMO)));
  });
});
