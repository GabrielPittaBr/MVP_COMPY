import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createOnEventEndedHandler,
  planEventEndedNotifications,
  type EventEndedNotificationDraft,
  type NotificationsGateway,
} from '../src/event_notifications.js';

const EVENTO = 'evt_1';
const CRIADOR = 'uid_criador';

function documento(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    title: 'Rachão',
    sport: 'basquete',
    creator: { id: CRIADOR, name: 'Ana', handle: '@ana', avatarUrl: '' },
    participantIds: [CRIADOR, 'uid_bruno', 'uid_carla'],
    participants: [{ id: CRIADOR }, { id: 'uid_bruno' }, { id: 'uid_carla' }],
    ...overrides,
  };
}

const aberto = documento();
const encerradoAMao = documento({ endedAt: new Date(), endedAutomatically: false });
const encerradoPelaFunction = documento({ endedAt: new Date(), endedAutomatically: true });

class GatewayFalso implements NotificationsGateway {
  readonly criadas = new Map<string, EventEndedNotificationDraft>();

  async createIfAbsent(draft: EventEndedNotificationDraft): Promise<boolean> {
    const chave = `${draft.uid}/${draft.id}`;
    if (this.criadas.has(chave)) return false;
    this.criadas.set(chave, draft);
    return true;
  }
}

test('encerrar cria uma notificação por participante, com id determinístico', () => {
  const rascunhos = planEventEndedNotifications(EVENTO, aberto, encerradoAMao);

  assert.deepEqual(
    rascunhos.map((r) => r.uid),
    [CRIADOR, 'uid_bruno', 'uid_carla'],
  );
  for (const r of rascunhos) {
    assert.equal(r.id, `eventEnded_${EVENTO}`);
    assert.equal(r.eventTitle, 'Rachão');
    assert.equal(r.sport, 'basquete');
    assert.equal(r.creatorId, CRIADOR);
  }
});

test('encerramento manual: a do criador nasce lida, a dos outros não', () => {
  const rascunhos = planEventEndedNotifications(EVENTO, aberto, encerradoAMao);

  assert.equal(rascunhos.find((r) => r.uid === CRIADOR)?.readOnCreate, true);
  assert.equal(rascunhos.find((r) => r.uid === 'uid_bruno')?.readOnCreate, false);
  assert.ok(rascunhos.every((r) => r.endedAutomatically === false));
});

test('encerramento automático: a do criador nasce não lida (dispara o aviso)', () => {
  const rascunhos = planEventEndedNotifications(EVENTO, aberto, encerradoPelaFunction);

  assert.ok(rascunhos.every((r) => r.readOnCreate === false));
  assert.ok(rascunhos.every((r) => r.endedAutomatically === true));
});

test('updates sem a transição não criam nada', () => {
  const comBruno = documento({ participantIds: [CRIADOR, 'uid_bruno', 'uid_carla', 'uid_diego'] });
  // join, ratedBy num evento já encerrado, edição da descrição
  assert.deepEqual(planEventEndedNotifications(EVENTO, aberto, comBruno), []);
  assert.deepEqual(
    planEventEndedNotifications(EVENTO, encerradoAMao, { ...encerradoAMao, ratedBy: ['uid_bruno'] }),
    [],
  );
  assert.deepEqual(
    planEventEndedNotifications(EVENTO, aberto, documento({ description: 'Levar colete' })),
    [],
  );
});

test('documento apagado ou endedAt nulo não criam nada', () => {
  assert.deepEqual(planEventEndedNotifications(EVENTO, aberto, undefined), []);
  assert.deepEqual(planEventEndedNotifications(EVENTO, aberto, documento({ endedAt: null })), []);
});

test('evento legado sem participantIds usa os ids de participants', () => {
  const legado = { ...encerradoAMao };
  delete legado.participantIds;
  const antes = { ...aberto };
  delete antes.participantIds;

  assert.deepEqual(
    planEventEndedNotifications(EVENTO, antes, legado).map((r) => r.uid),
    [CRIADOR, 'uid_bruno', 'uid_carla'],
  );
});

test('a reentrega do gatilho não duplica nada', async () => {
  const gateway = new GatewayFalso();
  const handler = createOnEventEndedHandler(gateway);

  assert.equal(await handler(EVENTO, aberto, encerradoAMao), 3);
  assert.equal(await handler(EVENTO, aberto, encerradoAMao), 0);
  assert.equal(gateway.criadas.size, 3);
});
