import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createDeleteEventHandler,
  type DeletableEvent,
  type EventDeletionGateway,
} from '../src/event_deletion.js';
import {
  adminRequest,
  assertHttpsError,
  completedAt,
  FakeDeletionOperations,
  operationId,
  reason,
} from './deletion_fakes.js';

const EVENTO = 'evt_1';

const entrada = (overrides: Record<string, unknown> = {}) => ({
  eventId: EVENTO,
  reason,
  operationId,
  ...overrides,
});

/** Coleção `events` de mentira; [falhasRestantes] derruba as próximas exclusões. */
class EventosFalsos implements EventDeletionGateway {
  constructor(readonly eventos = new Map<string, DeletableEvent>()) {}

  readonly excluidos: Array<{ eventId: string; event: DeletableEvent }> = [];
  falhasRestantes = 0;

  async readEvent(eventId: string): Promise<DeletableEvent | null> {
    return this.eventos.get(eventId) ?? null;
  }

  async deleteEvent(eventId: string, event: DeletableEvent): Promise<void> {
    if (this.falhasRestantes > 0) {
      this.falhasRestantes--;
      throw new Error('Firestore indisponível no meio da exclusão');
    }
    this.excluidos.push({ eventId, event });
    this.eventos.delete(eventId);
  }
}

const comEvento = () =>
  new EventosFalsos(new Map([[EVENTO, { participantIds: ['uid_criador', 'uid_a'], ratedBy: ['uid_a'] }]]));

test('exclui o evento com o que depende dele e registra quem, o quê e por quê', async () => {
  const eventos = comEvento();
  const operacoes = new FakeDeletionOperations();

  const resultado = await createDeleteEventHandler(eventos, operacoes)(
    adminRequest(entrada({ reason: `  ${reason.replace(' ', '   ')} ` })),
  );

  assert.deepEqual(resultado, { eventId: EVENTO, completedAt: completedAt.toISOString() });
  assert.deepEqual(eventos.excluidos, [
    { eventId: EVENTO, event: { participantIds: ['uid_criador', 'uid_a'], ratedBy: ['uid_a'] } },
  ]);
  const registro = operacoes.operations.get(operationId);
  assert.equal(registro?.status, 'succeeded');
  assert.equal(registro?.action, 'deleteEvent');
  assert.equal(registro?.adminUid, 'admin-uid');
  assert.equal(registro?.targetId, EVENTO);
  assert.equal(registro?.reason, reason);
});

test('rejeita quem não é Administrador e payload fora do contrato', async () => {
  const eventos = comEvento();
  const handler = createDeleteEventHandler(eventos, new FakeDeletionOperations());

  await assertHttpsError(handler({ data: entrada() }), 'unauthenticated');
  await assertHttpsError(handler({ data: entrada(), auth: { uid: 'u', token: {} } }), 'permission-denied');
  await assertHttpsError(handler(adminRequest(entrada({ extra: true }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ eventId: EVENTO, reason })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(entrada({ eventId: 'events/outro' }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(entrada({ eventId: '__evt__' }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(entrada({ reason: 'curto' }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(entrada({ operationId: 'não-é-uuid' }))), 'invalid-argument');
  assert.deepEqual(eventos.excluidos, []);
});

test('evento inexistente vira falha registrada, e a repetição devolve a mesma falha', async () => {
  const operacoes = new FakeDeletionOperations();
  const handler = createDeleteEventHandler(new EventosFalsos(), operacoes);

  await assertHttpsError(handler(adminRequest(entrada())), 'not-found', { operationStatus: 'failed' });
  assert.equal(operacoes.operations.get(operationId)?.failureCode, 'not-found');
  await assertHttpsError(handler(adminRequest(entrada())), 'not-found', { operationStatus: 'failed' });
});

test('repetir uma exclusão concluída devolve o resultado sem excluir de novo', async () => {
  const eventos = comEvento();
  const handler = createDeleteEventHandler(eventos, new FakeDeletionOperations());

  const primeira = await handler(adminRequest(entrada()));
  const segunda = await handler(adminRequest(entrada()));

  assert.deepEqual(segunda, primeira);
  assert.equal(eventos.excluidos.length, 1);
});

test('o mesmo operationId com outro motivo é recusado', async () => {
  const handler = createDeleteEventHandler(comEvento(), new FakeDeletionOperations());

  await handler(adminRequest(entrada()));
  await assertHttpsError(
    handler(adminRequest(entrada({ reason: 'Outro motivo administrativo válido.' }))),
    'already-exists',
  );
});

test('falha no meio deixa a operação pending, e a repetição termina a exclusão', async () => {
  const eventos = comEvento();
  eventos.falhasRestantes = 1;
  const operacoes = new FakeDeletionOperations();
  const handler = createDeleteEventHandler(eventos, operacoes);

  await assertHttpsError(handler(adminRequest(entrada())), 'internal', { operationStatus: 'pending' });
  assert.equal(operacoes.operations.get(operationId)?.status, 'pending');
  assert.ok(eventos.eventos.has(EVENTO));

  const resultado = await handler(adminRequest(entrada()));
  assert.equal(resultado.eventId, EVENTO);
  assert.equal(eventos.excluidos.length, 1);
});

test('pending com o evento já apagado conclui sem acusar evento inexistente', async () => {
  const operacoes = new FakeDeletionOperations();
  operacoes.seed({
    operationId,
    adminUid: 'admin-uid',
    action: 'deleteEvent',
    targetId: EVENTO,
    reason,
    status: 'pending',
  });
  const eventos = new EventosFalsos();

  const resultado = await createDeleteEventHandler(eventos, operacoes)(adminRequest(entrada()));

  assert.equal(resultado.eventId, EVENTO);
  assert.equal(operacoes.operations.get(operationId)?.status, 'succeeded');
  assert.deepEqual(eventos.excluidos, []);
});
