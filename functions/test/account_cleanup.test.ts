import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  createAccountCleanupHandler,
  deletedAccountSummary,
  planEventCleanup,
  type AccountCleanupGateway,
  type CleanupEvent,
  type EventCleanupResult,
} from '../src/account_cleanup.js';

const uid = 'saiu';
const now = Date.parse('2026-11-14T12:00:00.000Z');
const hour = 60 * 60 * 1000;

const summary = (id: string) => ({ id, name: id, handle: `@${id}`, avatarUrl: `https://foto/${id}` });

const event = (data: Record<string, unknown>, startsAtMs: number | null = now + 24 * hour): CleanupEvent => ({
  id: 'evento',
  data,
  startsAtMs,
});

describe('planEventCleanup', () => {
  it('cancela o evento futuro criado por quem saiu e avisa os outros participantes', () => {
    const plan = planEventCleanup(uid, event({
      creator: summary(uid),
      title: 'Futebol no parque',
      sport: 'futebol',
      participants: [summary(uid), summary('ana')],
      participantIds: [uid, 'ana'],
    }), now);
    assert.deepEqual(plan, {
      kind: 'cancel',
      eventId: 'evento',
      notifyUids: ['ana'],
      eventTitle: 'Futebol no parque',
      sport: 'futebol',
    });
  });

  it('tira quem saiu do evento futuro e devolve a vaga', () => {
    const plan = planEventCleanup(uid, event({
      creator: summary('ana'),
      participants: [summary('ana'), summary(uid)],
      participantIds: ['ana', uid],
      remainingSpots: 3,
      totalSpots: 5,
    }), now);
    assert.deepEqual(plan, {
      kind: 'update',
      eventId: 'evento',
      fields: { participants: [summary('ana')], participantIds: ['ana'], remainingSpots: 4 },
    });
  });

  it('a vaga devolvida não passa do total', () => {
    const plan = planEventCleanup(uid, event({
      creator: summary('ana'),
      participants: [summary(uid)],
      participantIds: [uid],
      remainingSpots: 5,
      totalSpots: 5,
    }), now);
    assert.equal(plan.kind === 'update' && plan.fields.remainingSpots, 5);
  });

  it('no evento passado troca nome e foto por "Conta excluída"', () => {
    const plan = planEventCleanup(uid, event({
      creator: summary(uid),
      participants: [summary(uid), summary('ana')],
      participantIds: [uid, 'ana'],
    }, now - 2 * hour), now);
    assert.deepEqual(plan, {
      kind: 'update',
      eventId: 'evento',
      fields: {
        creator: deletedAccountSummary(uid),
        participants: [deletedAccountSummary(uid), summary('ana')],
      },
    });
  });

  it('evento futuro já encerrado conta como passado', () => {
    const plan = planEventCleanup(uid, event({
      creator: summary(uid),
      endedAt: new Date(now),
      participants: [],
      participantIds: [],
    }), now);
    assert.equal(plan.kind, 'update');
  });

  it('evento sem ligação com quem saiu não muda', () => {
    const plan = planEventCleanup(uid, event({
      creator: summary('ana'),
      participants: [summary('ana')],
      participantIds: ['ana'],
    }), now);
    assert.deepEqual(plan, { kind: 'none', eventId: 'evento' });
  });

  it('documento anterior à tarefa 12, sem participantIds, também é limpo', () => {
    const plan = planEventCleanup(uid, event({
      creator: summary('ana'),
      participants: [summary('ana'), summary(uid)],
      remainingSpots: 0,
      totalSpots: 2,
    }), now);
    assert.deepEqual(plan, {
      kind: 'update',
      eventId: 'evento',
      fields: { participants: [summary('ana')], remainingSpots: 1 },
    });
  });
});

class FakeCleanupGateway implements AccountCleanupGateway {
  profile = false;
  readonly calls: string[] = [];
  readonly events = new Map<string, EventCleanupResult>([['e1', 'cancelled'], ['e2', 'updated'], ['e3', 'unchanged']]);

  async profileExists() { return this.profile; }
  // e1 aparece como criado e como inscrito: precisa ser tratado uma vez só.
  async eventIdsOf() { return ['e1', 'e2', 'e1', 'e3']; }
  async cleanEvent(eventId: string) {
    this.calls.push(`event:${eventId}`);
    return this.events.get(eventId) ?? 'unchanged';
  }
  async conversationIdsOf() { return ['c1', 'c2']; }
  async cleanConversation(conversationId: string) { this.calls.push(`conversation:${conversationId}`); }
  async anonymizeRatingsBy() { this.calls.push('ratingsBy'); return 2; }
  async deleteRatingsAbout() { this.calls.push('ratingsAbout'); return 1; }
  async deleteStorage() { this.calls.push('storage'); }
  async deletePrivateData() { this.calls.push('private'); }
}

describe('createAccountCleanupHandler', () => {
  it('limpa eventos, conversas, avaliações, Storage e o que restar do perfil', async () => {
    const gateway = new FakeCleanupGateway();
    const report = await createAccountCleanupHandler(gateway, () => now)(uid);
    assert.deepEqual(report, {
      skipped: false,
      eventsCancelled: 1,
      eventsUpdated: 1,
      conversations: 2,
      ratingsAnonymized: 2,
      ratingsDeleted: 1,
    });
    assert.deepEqual(gateway.calls, [
      'event:e1', 'event:e2', 'event:e3',
      'conversation:c1', 'conversation:c2',
      'ratingsBy', 'ratingsAbout', 'storage', 'private',
    ]);
  });

  it('não mexe em nada quando o perfil foi recriado antes do gatilho', async () => {
    const gateway = new FakeCleanupGateway();
    gateway.profile = true;
    const report = await createAccountCleanupHandler(gateway, () => now)(uid);
    assert.equal(report.skipped, true);
    assert.deepEqual(gateway.calls, []);
  });

  it('propaga a falha para o retry do gatilho', async () => {
    const gateway = new FakeCleanupGateway();
    gateway.cleanConversation = async () => { throw new Error('unavailable'); };
    await assert.rejects(createAccountCleanupHandler(gateway, () => now)(uid), /unavailable/);
  });
});
