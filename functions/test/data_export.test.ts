import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { GeoPoint, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { createExportMyDataHandler, exportFormat, serializeForExport } from '../src/data_export.js';
import { moderationRecordExpiresAt, notificationExpiresAt } from '../src/retention.js';

describe('serializeForExport', () => {
  it('converte tipos do Firestore em JSON legível', () => {
    const when = new Date('2026-11-14T12:00:00.000Z');
    assert.deepEqual(serializeForExport({
      criadoEm: Timestamp.fromDate(when),
      local: new GeoPoint(-29.65, -50.78),
      lista: [Timestamp.fromDate(when), 'texto', 1, null],
      aninhado: { data: when },
    }), {
      criadoEm: '2026-11-14T12:00:00.000Z',
      local: { latitude: -29.65, longitude: -50.78 },
      lista: ['2026-11-14T12:00:00.000Z', 'texto', 1, null],
      aninhado: { data: '2026-11-14T12:00:00.000Z' },
    });
  });
});

describe('createExportMyDataHandler', () => {
  const now = () => new Date('2026-11-14T12:00:00.000Z');

  it('exporta só os dados de quem chamou', async () => {
    let requested = '';
    const handler = createExportMyDataHandler({
      collect: async (uid) => { requested = uid; return { perfil: { nome: 'Ana' } }; },
    }, now);
    const result = await handler({ auth: { uid: 'ana', token: {} as never, rawToken: '' } });
    assert.equal(requested, 'ana');
    assert.deepEqual(result, { formato: exportFormat, geradoEm: '2026-11-14T12:00:00.000Z', perfil: { nome: 'Ana' } });
  });

  it('recusa quem não está logado', async () => {
    const handler = createExportMyDataHandler({ collect: async () => ({}) }, now);
    await assert.rejects(handler({ auth: undefined }), (error) =>
      error instanceof HttpsError && error.code === 'unauthenticated');
  });
});

describe('prazos de retenção', () => {
  const now = Date.parse('2026-11-14T12:00:00.000Z');

  it('notificações expiram em 90 dias', () => {
    assert.equal(notificationExpiresAt(now).toDate().toISOString(), '2027-02-12T12:00:00.000Z');
  });

  it('registros de moderação expiram em 5 anos', () => {
    assert.equal(moderationRecordExpiresAt(now).toDate().toISOString(), '2031-11-14T12:00:00.000Z');
  });
});
