/**
 * Regras de `events`, replicando o que `EventsRemoteDataSource` grava.
 *
 * O foco é o `participantIds` da tarefa 12: ele é o array que a seção
 * "Participando" consulta, e a regra `isJoin()` passou a exigir que ele
 * cresça junto de `participants`. Errar aqui trava o botão "Participar"
 * em produção com PERMISSION_DENIED — daí a suíte.
 */
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const CRIADOR = 'uid_criador';
const VISITANTE = 'uid_visitante';
const EVENTO = 'evento_1';

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
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anonimo = () => testEnv.unauthenticatedContext().firestore();

const resumo = (uid) => ({
  id: uid,
  name: uid,
  handle: `@${uid}`,
  avatarUrl: '',
});

/** Espelha `Event.toMap()`: o criador já entra como participante. */
function eventoNovo(criador = CRIADOR, { totalSpots = 4 } = {}) {
  return {
    title: 'Pelada de quinta',
    titleLower: 'pelada de quinta',
    sport: 'futebol',
    location: 'Ginásio Municipal, Taquara',
    dateTime: new Date('2026-09-01T19:00:00Z'),
    durationMinutes: 60,
    endsAt: new Date('2026-09-01T20:00:00Z'),
    skillLevel: 'todos',
    totalSpots,
    remainingSpots: totalSpots - 1,
    bannerUrl: '',
    creator: resumo(criador),
    description: '',
    participants: [resumo(criador)],
    participantIds: [criador],
  };
}

/** Semeia um evento sem passar pelas regras. */
async function semear(dados, id = EVENTO) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'events', id), dados);
  });
}

/** Espelha a transação de `EventsRemoteDataSource.join()`. */
function entrar(db, uid, { remainingSpots }) {
  return updateDoc(doc(db, 'events', EVENTO), {
    participants: arrayUnion(resumo(uid)),
    participantIds: arrayUnion(uid),
    remainingSpots: remainingSpots - 1,
  });
}

describe('events — criar', () => {
  it('o criador cria o próprio evento', async () => {
    await assertSucceeds(
      addDoc(collection(as(CRIADOR), 'events'), eventoNovo(CRIADOR)),
    );
  });

  it('ninguém cria evento em nome de outro', async () => {
    await assertFails(
      addDoc(collection(as(VISITANTE), 'events'), eventoNovo(CRIADOR)),
    );
  });

  it('participantIds não pode nascer com terceiros dentro', async () => {
    const forjado = eventoNovo(CRIADOR);
    forjado.participantIds = [CRIADOR, VISITANTE];
    await assertFails(addDoc(collection(as(CRIADOR), 'events'), forjado));
  });

  it('deslogado não cria evento', async () => {
    await assertFails(
      addDoc(collection(anonimo(), 'events'), eventoNovo(CRIADOR)),
    );
  });
});

describe('events — participar', () => {
  beforeEach(() => semear(eventoNovo(CRIADOR)));

  it('o join do app é autorizado', async () => {
    await assertSucceeds(entrar(as(VISITANTE), VISITANTE, { remainingSpots: 3 }));

    let gravado;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      gravado = (await getDoc(doc(ctx.firestore(), 'events', EVENTO))).data();
    });
    // A seção "Participando" consulta por este array — se ele não crescer,
    // o evento não aparece para quem acabou de entrar.
    if (!gravado.participantIds.includes(VISITANTE)) {
      throw new Error('participantIds não recebeu o uid de quem entrou');
    }
  });

  it('não dá para inscrever outra pessoa', async () => {
    await assertFails(entrar(as(VISITANTE), CRIADOR, { remainingSpots: 3 }));
  });

  it('participantIds não pode crescer sem participants', async () => {
    await assertFails(
      updateDoc(doc(as(VISITANTE), 'events', EVENTO), {
        participantIds: arrayUnion(VISITANTE),
        remainingSpots: 2,
      }),
    );
  });

  it('participants não pode crescer sem participantIds', async () => {
    await assertFails(
      updateDoc(doc(as(VISITANTE), 'events', EVENTO), {
        participants: arrayUnion(resumo(VISITANTE)),
        remainingSpots: 2,
      }),
    );
  });

  it('entrar sem ocupar vaga é negado', async () => {
    await assertFails(entrar(as(VISITANTE), VISITANTE, { remainingSpots: 4 }));
  });

  it('deslogado não entra', async () => {
    await assertFails(entrar(anonimo(), VISITANTE, { remainingSpots: 3 }));
  });

  it('evento lotado não aceita mais ninguém', async () => {
    await semear({ ...eventoNovo(CRIADOR), remainingSpots: 0 });
    await assertFails(entrar(as(VISITANTE), VISITANTE, { remainingSpots: 0 }));
  });

  it('evento anterior à tarefa 12 (sem participantIds) aceita join', async () => {
    const antigo = eventoNovo(CRIADOR);
    delete antigo.participantIds;
    await semear(antigo);
    // Sem o default do `resource.data.get('participantIds', [])` a regra
    // estouraria e o evento ficaria impossível de participar.
    await assertSucceeds(entrar(as(VISITANTE), VISITANTE, { remainingSpots: 3 }));
  });
});

describe('events — editar e apagar', () => {
  beforeEach(() => semear(eventoNovo(CRIADOR)));

  it('o criador edita o próprio evento', async () => {
    await assertSucceeds(
      updateDoc(doc(as(CRIADOR), 'events', EVENTO), { description: 'Levar colete' }),
    );
  });

  it('ninguém edita evento alheio', async () => {
    await assertFails(
      updateDoc(doc(as(VISITANTE), 'events', EVENTO), { dateTime: new Date() }),
    );
  });

  it('nem o criador troca o dono do evento', async () => {
    await assertFails(
      updateDoc(doc(as(CRIADOR), 'events', EVENTO), { creator: resumo(VISITANTE) }),
    );
  });

  it('qualquer autenticado lê a lista de eventos', async () => {
    await assertSucceeds(getDoc(doc(as(VISITANTE), 'events', EVENTO)));
  });

  it('evento não se apaga', async () => {
    await assertFails(deleteDoc(doc(as(CRIADOR), 'events', EVENTO)));
  });
});
