import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createDeleteOwnEventHandler,
  ownDeletableEventOf,
  type EventCancelledNotice,
  type OwnDeletableEvent,
  type OwnEventDeletionGateway,
  type OwnEventDeletionTransaction,
} from '../src/own_event_deletion.js';
import { assertHttpsError } from './deletion_fakes.js';

const EVENTO = 'evt_1';
const DONO = 'uid_dono';

const evento = (overrides: Partial<OwnDeletableEvent> = {}): OwnDeletableEvent => ({
  creatorId: DONO,
  ended: false,
  title: 'Rachão',
  sport: 'basquete',
  participantIds: [DONO, 'uid_a', 'uid_b'],
  ratedBy: [],
  ...overrides,
});

/** Coleção `events` de mentira: as escritas só valem se a transação terminar. */
class EventosFalsos implements OwnEventDeletionGateway {
  constructor(readonly eventos = new Map<string, OwnDeletableEvent>([[EVENTO, evento()]])) {}

  readonly avisos: Array<{ uid: string; notice: EventCancelledNotice }> = [];
  readonly excluidos: string[] = [];

  async runTransaction<T>(work: (transaction: OwnEventDeletionTransaction) => Promise<T>): Promise<T> {
    const avisos: Array<{ uid: string; notice: EventCancelledNotice }> = [];
    const excluidos: string[] = [];
    const resultado = await work({
      readEvent: async (eventId) => this.eventos.get(eventId) ?? null,
      notifyCancelled: (uid, notice) => avisos.push({ uid, notice }),
      deleteEvent: (eventId) => excluidos.push(eventId),
    });
    this.avisos.push(...avisos);
    this.excluidos.push(...excluidos);
    for (const eventId of excluidos) this.eventos.delete(eventId);
    return resultado;
  }
}

const pedido = (data: unknown, uid = DONO) => ({ data, auth: { uid } });

test('o Organizador exclui, e todos menos ele recebem o aviso com o motivo aparado', async () => {
  const eventos = new EventosFalsos();

  const resultado = await createDeleteOwnEventHandler(eventos)(
    pedido({ eventId: EVENTO, reason: '  Choveu demais.  ' }),
  );

  assert.deepEqual(resultado, { eventId: EVENTO, notified: 2 });
  assert.deepEqual(eventos.excluidos, [EVENTO]);
  const aviso = { eventId: EVENTO, eventTitle: 'Rachão', sport: 'basquete', creatorId: DONO, reason: 'Choveu demais.' };
  assert.deepEqual(eventos.avisos, [
    { uid: 'uid_a', notice: aviso },
    { uid: 'uid_b', notice: aviso },
  ]);
});

test('motivo vazio, só com espaços, nulo ou ausente vira motivo nenhum', async () => {
  for (const data of [{ eventId: EVENTO }, { eventId: EVENTO, reason: null }, { eventId: EVENTO, reason: '   ' }]) {
    const eventos = new EventosFalsos();
    await createDeleteOwnEventHandler(eventos)(pedido(data));
    assert.equal(eventos.avisos[0]?.notice.reason, null);
  }
});

test('motivo de 200 caracteres passa; acima disso é recusado sem excluir', async () => {
  const eventos = new EventosFalsos();
  const handler = createDeleteOwnEventHandler(eventos);

  await assertHttpsError(handler(pedido({ eventId: EVENTO, reason: 'a'.repeat(201) })), 'invalid-argument');
  assert.deepEqual(eventos.excluidos, []);

  await handler(pedido({ eventId: EVENTO, reason: ` ${'a'.repeat(200)} ` }));
  assert.deepEqual(eventos.excluidos, [EVENTO]);
});

test('recusa payload fora do contrato e quem não entrou', async () => {
  const handler = createDeleteOwnEventHandler(new EventosFalsos());

  await assertHttpsError(handler({ data: { eventId: EVENTO } }), 'unauthenticated');
  await assertHttpsError(handler(pedido(null)), 'invalid-argument');
  await assertHttpsError(handler(pedido({ eventId: EVENTO, extra: true })), 'invalid-argument');
  await assertHttpsError(handler(pedido({ eventId: 'events/outro' })), 'invalid-argument');
  await assertHttpsError(handler(pedido({ eventId: EVENTO, reason: 42 })), 'invalid-argument');
});

test('quem não é o Organizador é recusado, mesmo participando', async () => {
  const eventos = new EventosFalsos();

  await assertHttpsError(createDeleteOwnEventHandler(eventos)(pedido({ eventId: EVENTO }, 'uid_a')), 'permission-denied');
  assert.deepEqual(eventos.excluidos, []);
  assert.deepEqual(eventos.avisos, []);
});

test('evento encerrado é recusado, e evento inexistente é not-found', async () => {
  const eventos = new EventosFalsos(new Map([[EVENTO, evento({ ended: true })]]));
  const handler = createDeleteOwnEventHandler(eventos);

  await assertHttpsError(handler(pedido({ eventId: EVENTO })), 'failed-precondition');
  await assertHttpsError(handler(pedido({ eventId: 'evt_sumido' })), 'not-found');
  assert.deepEqual(eventos.excluidos, []);
  assert.deepEqual(eventos.avisos, []);
});

test('repetir depois da exclusão dá not-found e não avisa de novo', async () => {
  const eventos = new EventosFalsos();
  const handler = createDeleteOwnEventHandler(eventos);

  await handler(pedido({ eventId: EVENTO }));
  await assertHttpsError(handler(pedido({ eventId: EVENTO })), 'not-found');
  assert.equal(eventos.avisos.length, 2);
});

test('falha inesperada vira internal', async () => {
  const handler = createDeleteOwnEventHandler({
    runTransaction: async () => {
      throw new Error('Firestore indisponível');
    },
  });

  await assertHttpsError(handler(pedido({ eventId: EVENTO })), 'internal');
});

test('evento antigo sem participantIds avisa quem está em participants', async () => {
  const antigo = ownDeletableEventOf({
    title: 'Pelada',
    sport: 'futebol',
    creator: { id: DONO },
    participants: [{ id: DONO }, { id: 'uid_a' }],
    endedAt: null,
  });
  assert.deepEqual(antigo, {
    creatorId: DONO,
    ended: false,
    title: 'Pelada',
    sport: 'futebol',
    participantIds: [DONO, 'uid_a'],
    ratedBy: [],
  });
  const eventos = new EventosFalsos(new Map([[EVENTO, antigo]]));

  await createDeleteOwnEventHandler(eventos)(pedido({ eventId: EVENTO }));

  assert.deepEqual(eventos.avisos.map((aviso) => aviso.uid), ['uid_a']);
});
