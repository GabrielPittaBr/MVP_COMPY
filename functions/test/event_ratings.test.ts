import assert from 'node:assert/strict';
import test from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import {
  createSubmitEventRatingsHandler,
  RatingAlreadyExistsError,
  type RatingEventSnapshot,
  type RatingsCallableRequest,
  type RatingsGateway,
  type RatingsTransaction,
  type RatingWrite,
} from '../src/event_ratings.js';

const agora = new Date('2026-10-21T23:00:00.000Z');
const horas = (n: number) => n * 60 * 60 * 1000;

const CRIADOR = 'uid_criador';
const PARTICIPANTE = 'uid_participante';
const OUTRO = 'uid_outro';
const VISITANTE = 'uid_visitante';
const EVENTO = 'evt_1';
const LOCAL = 'place_1';

function evento(overrides: Partial<RatingEventSnapshot> = {}): RatingEventSnapshot {
  return {
    creatorId: CRIADOR,
    participantIds: [CRIADOR, PARTICIPANTE, OUTRO],
    placeId: LOCAL,
    endedAt: new Date(agora.getTime() - horas(1)),
    plannedEnd: new Date(agora.getTime() - horas(1)),
    ratedBy: [],
    ...overrides,
  };
}

interface Resumo {
  count: number;
  sum: number;
  starCounts: Record<string, number>;
}

/**
 * Firestore de mentira: exige leituras antes das escritas e só aplica as
 * escritas no "commit", tudo ou nada — como a transação real.
 */
class GatewayFalso implements RatingsGateway {
  readonly eventos = new Map<string, RatingEventSnapshot>();
  readonly ratings = new Map<string, RatingWrite>();
  readonly resumos = new Map<string, Resumo>();

  async runTransaction<T>(work: (transaction: RatingsTransaction) => Promise<T>): Promise<T> {
    let escreveu = false;
    const criadas: RatingWrite[] = [];
    const somas: RatingWrite[] = [];
    const avaliaram: Array<{ eventId: string; uid: string }> = [];
    const result = await work({
      readEvent: async (eventId) => {
        if (escreveu) throw new Error('leitura depois de escrita');
        return this.eventos.get(eventId) ?? null;
      },
      createRating: (rating) => {
        escreveu = true;
        criadas.push(rating);
      },
      incrementSummary: (rating) => {
        escreveu = true;
        somas.push(rating);
      },
      addRatedBy: (eventId, uid) => {
        escreveu = true;
        avaliaram.push({ eventId, uid });
      },
    });
    const idDe = (r: RatingWrite) => `${r.eventId}_${r.fromUid}_${r.targetType}_${r.targetId}`;
    if (criadas.some((r) => this.ratings.has(idDe(r)))) throw new RatingAlreadyExistsError();
    for (const r of criadas) this.ratings.set(idDe(r), r);
    for (const r of somas) {
      const id = `${r.targetType}_${r.targetId}`;
      const atual = this.resumos.get(id) ?? { count: 0, sum: 0, starCounts: {} };
      atual.count += 1;
      atual.sum += r.stars;
      atual.starCounts[String(r.stars)] = (atual.starCounts[String(r.stars)] ?? 0) + 1;
      this.resumos.set(id, atual);
    }
    for (const { eventId, uid } of avaliaram) {
      const e = this.eventos.get(eventId)!;
      this.eventos.set(eventId, { ...e, ratedBy: [...e.ratedBy, uid] });
    }
    return result;
  }
}

function cenario(snapshot: RatingEventSnapshot | null = evento()) {
  const gateway = new GatewayFalso();
  if (snapshot !== null) gateway.eventos.set(EVENTO, snapshot);
  const handler = createSubmitEventRatingsHandler(gateway, () => agora);
  const enviar = (uid: string | undefined, data: unknown) => {
    const request: RatingsCallableRequest = uid === undefined ? { data } : { data, auth: { uid } };
    return handler(request);
  };
  return { gateway, enviar };
}

const doParticipante = (overrides: Record<string, unknown> = {}) => ({
  eventId: EVENTO,
  event: { stars: 5 },
  place: { stars: 4, comment: 'Quadra boa.' },
  participants: [],
  ...overrides,
});

async function falhaCom(promessa: Promise<unknown>, codigo: string) {
  await assert.rejects(promessa, (error: unknown) => {
    assert.ok(error instanceof HttpsError, `esperava HttpsError, veio ${String(error)}`);
    assert.equal(error.code, codigo);
    return true;
  });
}

test('o participante avalia o evento e o local numa transação só', async () => {
  const { gateway, enviar } = cenario();

  assert.deepEqual(await enviar(PARTICIPANTE, doParticipante()), { ratedTargets: 2 });

  const evt = gateway.ratings.get(`${EVENTO}_${PARTICIPANTE}_event_${EVENTO}`);
  const local = gateway.ratings.get(`${EVENTO}_${PARTICIPANTE}_place_${LOCAL}`);
  assert.equal(evt?.stars, 5);
  assert.equal(evt?.comment, null);
  assert.equal(local?.comment, 'Quadra boa.');
  assert.deepEqual(gateway.resumos.get(`event_${EVENTO}`), { count: 1, sum: 5, starCounts: { '5': 1 } });
  assert.deepEqual(gateway.resumos.get(`place_${LOCAL}`), { count: 1, sum: 4, starCounts: { '4': 1 } });
  assert.deepEqual(gateway.eventos.get(EVENTO)?.ratedBy, [PARTICIPANTE]);
});

test('agregados somam as notas de pessoas diferentes', async () => {
  const { gateway, enviar } = cenario();
  await enviar(PARTICIPANTE, doParticipante({ event: { stars: 5 } }));
  await enviar(OUTRO, doParticipante({ event: { stars: 3 } }));

  assert.deepEqual(gateway.resumos.get(`event_${EVENTO}`), {
    count: 2,
    sum: 8,
    starCounts: { '5': 1, '3': 1 },
  });
});

test('o criador avalia só o local (D14)', async () => {
  const { gateway, enviar } = cenario();

  assert.deepEqual(
    await enviar(CRIADOR, { eventId: EVENTO, place: { stars: 3 }, participants: [] }),
    { ratedTargets: 1 },
  );
  assert.equal(gateway.resumos.get(`event_${EVENTO}`), undefined);
  assert.deepEqual(gateway.eventos.get(EVENTO)?.ratedBy, [CRIADOR]);
});

test('o criador avalia o local e quem jogou', async () => {
  const { gateway, enviar } = cenario();

  assert.deepEqual(
    await enviar(CRIADOR, {
      eventId: EVENTO,
      place: { stars: 4 },
      participants: [
        { uid: PARTICIPANTE, stars: 5 },
        { uid: OUTRO, stars: 2, comment: 'Saiu no meio do jogo.' },
      ],
    }),
    { ratedTargets: 3 },
  );
  assert.equal(gateway.ratings.get(`${EVENTO}_${CRIADOR}_user_${OUTRO}`)?.comment, 'Saiu no meio do jogo.');
  assert.deepEqual(gateway.resumos.get(`user_${PARTICIPANTE}`), { count: 1, sum: 5, starCounts: { '5': 1 } });
  assert.deepEqual(gateway.resumos.get(`user_${OUTRO}`), { count: 1, sum: 2, starCounts: { '2': 1 } });
});

test('o participante pode não avaliar ninguém (passo opcional)', async () => {
  const { gateway, enviar } = cenario();

  assert.deepEqual(await enviar(PARTICIPANTE, doParticipante({ participants: [] })), { ratedTargets: 2 });
  assert.equal([...gateway.resumos.keys()].some((id) => id.startsWith('user_')), false);
});

test('avaliações de pessoas diferentes formam a média do Usuário', async () => {
  const { gateway, enviar } = cenario();
  await enviar(PARTICIPANTE, doParticipante({ participants: [{ uid: OUTRO, stars: 5 }] }));
  await enviar(CRIADOR, { eventId: EVENTO, place: { stars: 4 }, participants: [{ uid: OUTRO, stars: 4 }] });

  assert.deepEqual(gateway.resumos.get(`user_${OUTRO}`), { count: 2, sum: 9, starCounts: { '5': 1, '4': 1 } });
});

test('participante de evento legado (só com participants) também é avaliável', async () => {
  // O gateway real deriva os ids de `participants` quando falta `participantIds`.
  const { enviar } = cenario(evento({ participantIds: [CRIADOR, PARTICIPANTE, OUTRO] }));

  assert.deepEqual(
    await enviar(PARTICIPANTE, doParticipante({ participants: [{ uid: OUTRO, stars: 3 }] })),
    { ratedTargets: 3 },
  );
});

test('evento legado sem local: o participante avalia só o evento', async () => {
  const { enviar } = cenario(evento({ placeId: null }));

  assert.deepEqual(
    await enviar(PARTICIPANTE, { eventId: EVENTO, event: { stars: 4 }, participants: [] }),
    { ratedTargets: 1 },
  );
});

test('encerrado pelo tempo, mesmo sem endedAt, já aceita avaliação', async () => {
  const { enviar } = cenario(evento({ endedAt: null, plannedEnd: new Date(agora.getTime() - horas(1)) }));

  assert.deepEqual(await enviar(PARTICIPANTE, doParticipante()), { ratedTargets: 2 });
});

test('comentário só de espaços conta como sem comentário', async () => {
  const { gateway, enviar } = cenario();
  await enviar(PARTICIPANTE, doParticipante({ event: { stars: 4, comment: '   ' } }));

  assert.equal(gateway.ratings.get(`${EVENTO}_${PARTICIPANTE}_event_${EVENTO}`)?.comment, null);
});

test('matriz de validação contra o evento', async (t) => {
  await t.test('deslogado → unauthenticated', async () => {
    await falhaCom(cenario().enviar(undefined, doParticipante()), 'unauthenticated');
  });
  await t.test('evento não existe → not-found', async () => {
    await falhaCom(cenario(null).enviar(PARTICIPANTE, doParticipante()), 'not-found');
  });
  await t.test('evento ainda não terminou → failed-precondition', async () => {
    const aberto = evento({ endedAt: null, plannedEnd: new Date(agora.getTime() - horas(0.5)) });
    await falhaCom(cenario(aberto).enviar(PARTICIPANTE, doParticipante()), 'failed-precondition');
  });
  await t.test('quem não participou → permission-denied', async () => {
    await falhaCom(cenario().enviar(VISITANTE, doParticipante()), 'permission-denied');
  });
  await t.test('quem já avaliou → already-exists', async () => {
    const avaliado = evento({ ratedBy: [PARTICIPANTE] });
    await falhaCom(cenario(avaliado).enviar(PARTICIPANTE, doParticipante()), 'already-exists');
  });
  await t.test('o criador mandou a nota do evento → invalid-argument', async () => {
    await falhaCom(cenario().enviar(CRIADOR, doParticipante()), 'invalid-argument');
  });
  await t.test('o participante não mandou a nota do evento → invalid-argument', async () => {
    await falhaCom(
      cenario().enviar(PARTICIPANTE, { eventId: EVENTO, place: { stars: 4 }, participants: [] }),
      'invalid-argument',
    );
  });
  await t.test('nota de local num evento sem local → invalid-argument', async () => {
    await falhaCom(cenario(evento({ placeId: null })).enviar(PARTICIPANTE, doParticipante()), 'invalid-argument');
  });
  await t.test('evento com local e sem nota do local → invalid-argument', async () => {
    await falhaCom(
      cenario().enviar(PARTICIPANTE, { eventId: EVENTO, event: { stars: 4 }, participants: [] }),
      'invalid-argument',
    );
  });
  await t.test('nota baixa de participante sem motivo → invalid-argument', async () => {
    await falhaCom(
      cenario().enviar(PARTICIPANTE, doParticipante({ participants: [{ uid: OUTRO, stars: 1 }] })),
      'invalid-argument',
    );
  });
  await t.test('avaliar quem não participou, ou a si mesmo → invalid-argument', async () => {
    for (const uid of [VISITANTE, PARTICIPANTE]) {
      await falhaCom(
        cenario().enviar(PARTICIPANTE, doParticipante({ participants: [{ uid, stars: 5 }] })),
        'invalid-argument',
      );
    }
  });
});

test('avaliação duplicada falha inteira, sem gravar nada', async () => {
  const { gateway, enviar } = cenario();
  await enviar(PARTICIPANTE, doParticipante());
  // ratedBy "esquecido", mas as ratings com id composto já existem.
  gateway.eventos.set(EVENTO, { ...gateway.eventos.get(EVENTO)!, ratedBy: [] });

  await falhaCom(enviar(PARTICIPANTE, doParticipante()), 'already-exists');
  assert.equal(gateway.resumos.get(`event_${EVENTO}`)?.count, 1);
  assert.deepEqual(gateway.eventos.get(EVENTO)?.ratedBy, []);
});

test('parse estrito do payload', async (t) => {
  const casos: Array<[string, unknown]> = [
    ['payload que não é objeto', 'oi'],
    ['chave a mais', doParticipante({ extra: true })],
    ['eventId vazio', doParticipante({ eventId: '' })],
    ['eventId longo demais', doParticipante({ eventId: 'x'.repeat(129) })],
    ['sem participants', { eventId: EVENTO, event: { stars: 5 }, place: { stars: 4 } }],
    ['nota zero', doParticipante({ event: { stars: 0 } })],
    ['nota seis', doParticipante({ event: { stars: 6 } })],
    ['nota quebrada', doParticipante({ event: { stars: 4.5 } })],
    ['nota em texto', doParticipante({ event: { stars: '5' } })],
    ['chave a mais na nota', doParticipante({ event: { stars: 5, extra: 1 } })],
    ['comentário longo demais', doParticipante({ event: { stars: 5, comment: 'x'.repeat(501) } })],
    ['nota baixa sem motivo', doParticipante({ event: { stars: 2 } })],
    ['nota baixa com motivo só de espaços', doParticipante({ place: { stars: 1, comment: '  ' } })],
    ['participante repetido', doParticipante({ participants: [{ uid: OUTRO, stars: 5 }, { uid: OUTRO, stars: 4 }] })],
  ];
  for (const [nome, data] of casos) {
    await t.test(`${nome} → invalid-argument`, async () => {
      await falhaCom(cenario().enviar(PARTICIPANTE, data), 'invalid-argument');
    });
  }

  await t.test('comentário de 500 caracteres passa', async () => {
    const { enviar } = cenario();
    const resultado = await enviar(PARTICIPANTE, doParticipante({ event: { stars: 2, comment: 'x'.repeat(500) } }));
    assert.equal(resultado.ratedTargets, 2);
  });
});
