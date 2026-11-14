import assert from 'node:assert/strict';
import { it } from 'node:test';

import { Timestamp } from 'firebase-admin/firestore';

import { parseRetentionBackfillArguments } from '../src/cli/backfill-retention-expiry.js';
import {
  backfillRetentionExpiry,
  type RetentionBackfillGateway,
  type RetentionCandidate,
} from '../src/retention/retention_backfill.js';

const created = Timestamp.fromDate(new Date('2026-10-22T12:00:00.000Z'));

function gateway(notifications: RetentionCandidate[], operations: RetentionCandidate[]) {
  const writes = new Map<string, Timestamp>();
  const api: RetentionBackfillGateway = {
    async *listNotifications() { yield* notifications; },
    async *listAdminOperations() { yield* operations; },
    setExpiresAt: async (path, expiresAt) => { writes.set(path, expiresAt); },
  };
  return { api, writes };
}

it('completa só quem não tem expiresAt, com 90 dias e 5 anos a partir da criação', async () => {
  const { api, writes } = gateway(
    [
      { path: 'users/a/notifications/n1', createdAt: created, expiresAt: undefined },
      { path: 'users/a/notifications/n2', createdAt: created, expiresAt: Timestamp.now() },
    ],
    [{ path: 'adminOperations/o1', createdAt: created, expiresAt: null }],
  );
  const result = await backfillRetentionExpiry(api, { dryRun: false });
  assert.deepEqual(result, { notificationsUpdated: 1, operationsUpdated: 1, unchanged: 1 });
  assert.equal(writes.get('users/a/notifications/n1')?.toDate().toISOString(), '2027-01-20T12:00:00.000Z');
  assert.equal(writes.get('adminOperations/o1')?.toDate().toISOString(), '2031-10-22T12:00:00.000Z');
  assert.equal(writes.has('users/a/notifications/n2'), false);
});

it('dry-run conta sem gravar e repetir não muda nada', async () => {
  const { api, writes } = gateway([{ path: 'users/a/notifications/n1', createdAt: created, expiresAt: undefined }], []);
  const result = await backfillRetentionExpiry(api, { dryRun: true });
  assert.equal(result.notificationsUpdated, 1);
  assert.equal(writes.size, 0);
});

it('aceita só --dry-run como argumento', () => {
  assert.deepEqual(parseRetentionBackfillArguments([]), { dryRun: false });
  assert.deepEqual(parseRetentionBackfillArguments(['--dry-run']), { dryRun: true });
  assert.throws(() => parseRetentionBackfillArguments(['--force']));
});
