/**
 * Regras de `events`, replicando o que `EventsRemoteDataSource` grava.
 *
 * O foco é o `participantIds` da tarefa 12: ele é o array que a seção
 * "Participando" consulta, e a regra `isJoin()` passou a exigir que ele
 * cresça junto de `participants`. Errar aqui trava o botão "Participar"
 * em produção com PERMISSION_DENIED — daí a suíte.
 */
import assert from 'node:assert/strict';
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
  GeoPoint,
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

const PLACE = 'place_test';
const address = {
  street: 'Rua Central',
  city: 'Taquara',
  cityLower: 'taquara',
  state: 'RS',
};
const placeCoordinates = new GeoPoint(-29.65, -50.78);

function placeDocument({ status = 'active', sports = ['futebol'] } = {}) {
  return {
    name: 'Quadra Central',
    nameLower: 'quadra central',
    description: 'Espaço esportivo comunitário para atividades locais.',
    address,
    sports,
    primarySport: 'futebol',
    coordinates: placeCoordinates,
    imageUrl: 'https://example.com/place.jpg',
    status,
    createdAt: new Date('2026-01-01T00:00:00Z'),
    updatedAt: new Date('2026-01-01T00:00:00Z'),
  };
}

function eventoComLocal(criador = CRIADOR) {
  return {
    ...eventoNovo(criador),
    placeId: PLACE,
    placeSnapshot: {
      name: 'Quadra Central',
      address,
      coordinates: placeCoordinates,
    },
    coordinates: placeCoordinates,
    geohash: '6gkzwgjzn',
    location: 'Quadra Central, Taquara',
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
  it('nega nova criação de evento pelo writer legado sem placeSnapshot', async () => {
    await assertFails(addDoc(collection(as(CRIADOR), 'events'), eventoNovo(CRIADOR)));
    await assertFails(addDoc(collection(as(CRIADOR), 'events'), {
      ...eventoNovo(CRIADOR),
      placeId: PLACE,
    }));
    const snapshotSemId = {
      ...eventoNovo(CRIADOR),
      placeSnapshot: {
        name: 'Quadra Central',
        address,
        coordinates: placeCoordinates,
      },
    };
    await assertFails(addDoc(collection(as(CRIADOR), 'events'), snapshotSemId));
  });

  it('ninguém cria evento em nome de outro', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
    });
    await assertFails(
      addDoc(collection(as(VISITANTE), 'events'), eventoComLocal(CRIADOR)),
    );
  });

  it('participantIds não pode nascer com terceiros dentro', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
    });
    const forjado = eventoComLocal(CRIADOR);
    forjado.participantIds = [CRIADOR, VISITANTE];
    await assertFails(addDoc(collection(as(CRIADOR), 'events'), forjado));
  });

  it('deslogado não cria evento', async () => {
    await assertFails(
      addDoc(collection(anonimo(), 'events'), eventoComLocal(CRIADOR)),
    );
  });

  it('aceita novo contrato com local ativo, esporte e snapshot atuais', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
    });
    await assertSucceeds(
      addDoc(collection(as(CRIADOR), 'events'), eventoComLocal()),
    );
  });

  it('nega novo evento com local inexistente ou inativo', async () => {
    await assertFails(
      addDoc(collection(as(CRIADOR), 'events'), eventoComLocal()),
    );
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'places', PLACE),
        placeDocument({ status: 'inactive' }),
      );
    });
    await assertFails(
      addDoc(collection(as(CRIADOR), 'events'), eventoComLocal()),
    );
  });

  it('nega modalidade não suportada pelo local', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
    });
    await assertFails(
      addDoc(collection(as(CRIADOR), 'events'), {
        ...eventoComLocal(),
        sport: 'corrida',
      }),
    );
  });

  it('nega snapshot ou coordenadas divergentes do local atual', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
    });
    const badSnapshot = eventoComLocal();
    badSnapshot.placeSnapshot.name = 'Outro nome';
    await assertFails(addDoc(collection(as(CRIADOR), 'events'), badSnapshot));

    const badCoordinates = eventoComLocal();
    badCoordinates.coordinates = new GeoPoint(-29.66, -50.78);
    await assertFails(
      addDoc(collection(as(CRIADOR), 'events'), badCoordinates),
    );
  });

  it('nega snapshot que ficou antigo após editar o local', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
      await setDoc(doc(ctx.firestore(), 'places', PLACE), {
        ...placeDocument(),
        name: 'Quadra Reformada',
        nameLower: 'quadra reformada',
      });
    });
    await assertFails(
      addDoc(collection(as(CRIADOR), 'events'), eventoComLocal()),
    );
  });

  it('leitura histórica mantém snapshot após alterar e inativar o local', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
      await setDoc(
        doc(ctx.firestore(), 'events', EVENTO),
        eventoComLocal(),
      );
      await setDoc(
        doc(ctx.firestore(), 'places', PLACE),
        placeDocument({ status: 'inactive' }),
      );
    });

    const snapshot = await getDoc(doc(as(VISITANTE), 'events', EVENTO));
    assert.equal(snapshot.data().placeSnapshot.name, 'Quadra Central');
    assert.equal(snapshot.data().location, 'Quadra Central, Taquara');
    assert.equal(snapshot.data().coordinates.latitude, -29.65);
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

  it('sport permanece imutável em evento legado', async () => {
    await assertFails(
      updateDoc(doc(as(CRIADOR), 'events', EVENTO), { sport: 'corrida' }),
    );
  });

  it('sport, placeId e snapshot permanecem imutáveis em evento novo', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'places', PLACE), placeDocument());
      await setDoc(
        doc(ctx.firestore(), 'events', EVENTO),
        eventoComLocal(),
      );
    });
    const db = as(CRIADOR);
    await assertFails(
      updateDoc(doc(db, 'events', EVENTO), { sport: 'corrida' }),
    );
    await assertFails(
      updateDoc(doc(db, 'events', EVENTO), { placeId: 'another_place' }),
    );
    await assertFails(
      updateDoc(doc(db, 'events', EVENTO), {
        'placeSnapshot.name': 'Outro nome',
      }),
    );
  });
});
