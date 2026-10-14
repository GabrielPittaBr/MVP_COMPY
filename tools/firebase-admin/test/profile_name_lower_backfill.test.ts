import assert from 'node:assert/strict';
import test from 'node:test';

import {
  backfillProfileNameLower,
  normalizeProfileName,
  type ProfileBackfillCandidate,
  type ProfileNameLowerBackfillGateway,
} from '../src/profiles/profile_name_lower_backfill.js';

function fakeGateway(profiles: readonly ProfileBackfillCandidate[]): ProfileNameLowerBackfillGateway & {
  readonly updates: Array<{ id: string; nameLower: string }>;
} {
  const updates: Array<{ id: string; nameLower: string }> = [];
  return {
    updates,
    async *listProfiles() {
      yield* profiles;
    },
    updateNameLower: async (id, nameLower) => {
      updates.push({ id, nameLower });
    },
  };
}

test('normalizador de perfil remove acentos pt-BR, caixa e espaços externos', () => {
  assert.equal(normalizeProfileName('  João Çarvalho  '), 'joao carvalho');
});

test('backfill atualiza somente perfis cujo nameLower diverge', async () => {
  const gateway = fakeGateway([
    { id: 'joao', name: 'João Silva', nameLower: undefined },
    { id: 'ana', name: 'Ana Lima', nameLower: 'ana lima' },
    { id: 'maria', name: 'Maria', nameLower: 'desatualizado' },
  ]);

  const result = await backfillProfileNameLower(gateway, { dryRun: false });

  assert.deepEqual(result, { updated: 2, unchanged: 1, invalidProfileIds: [] });
  assert.deepEqual(gateway.updates, [
    { id: 'joao', nameLower: 'joao silva' },
    { id: 'maria', nameLower: 'maria' },
  ]);
});

test('backfill reporta nome inválido sem inventar dado e dry-run não escreve', async () => {
  const gateway = fakeGateway([
    { id: 'sem-nome', name: '   ', nameLower: undefined },
    { id: 'longo', name: 'x'.repeat(61), nameLower: undefined },
    { id: 'valido', name: 'Vôlei', nameLower: undefined },
  ]);

  const result = await backfillProfileNameLower(gateway, { dryRun: true });

  assert.deepEqual(result, {
    updated: 1,
    unchanged: 0,
    invalidProfileIds: ['sem-nome', 'longo'],
  });
  assert.deepEqual(gateway.updates, []);
});
