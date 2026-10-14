import assert from 'node:assert/strict';
import test from 'node:test';

import {
  migrateParqueDoTrabalhador,
  parqueDoTrabalhadorId,
  PlaceMigrationConflictError,
  type PlaceMigrationGateway,
} from '../src/places/migrate_parque_do_trabalhador.js';
import { parqueDoTrabalhadorSeed, type PlaceSeed } from '../src/places/place_contract.js';

function fakeGateway(existing: PlaceSeed | undefined): PlaceMigrationGateway & {
  readonly creates: Array<{ id: string; place: PlaceSeed }>;
  readonly verifications: Array<{ id: string; place: PlaceSeed }>;
} {
  const creates: Array<{ id: string; place: PlaceSeed }> = [];
  const verifications: Array<{ id: string; place: PlaceSeed }> = [];
  return {
    creates,
    verifications,
    getPlace: async () => existing,
    createPlace: async (id, place) => {
      creates.push({ id, place });
    },
    verifyPlace: async (id, place) => {
      verifications.push({ id, place });
    },
  };
}

test('dry-run não cria Local Esportivo ausente', async () => {
  const gateway = fakeGateway(undefined);

  const result = await migrateParqueDoTrabalhador(gateway, { dryRun: true });

  assert.deepEqual(result, { outcome: 'would-create', changed: false });
  assert.equal(gateway.creates.length, 0);
  assert.equal(gateway.verifications.length, 0);
});

test('migração cria e verifica exatamente o ID legado aprovado', async () => {
  const gateway = fakeGateway(undefined);

  const result = await migrateParqueDoTrabalhador(gateway, { dryRun: false });

  assert.deepEqual(result, { outcome: 'created', changed: true });
  assert.deepEqual(gateway.creates, [{ id: parqueDoTrabalhadorId, place: parqueDoTrabalhadorSeed }]);
  assert.deepEqual(gateway.verifications, [{ id: parqueDoTrabalhadorId, place: parqueDoTrabalhadorSeed }]);
});

test('seed usa a imagem real publicada no Hosting do Admin', () => {
  assert.equal(
    parqueDoTrabalhadorSeed.imageUrl,
    'https://compy-tcc-admin.web.app/places/parque_do_trabalhador.jpg',
  );
});

test('documento equivalente é no-op e ainda é verificado', async () => {
  const gateway = fakeGateway({
    ...parqueDoTrabalhadorSeed,
    address: { ...parqueDoTrabalhadorSeed.address },
    sports: [...parqueDoTrabalhadorSeed.sports],
    coordinates: { ...parqueDoTrabalhadorSeed.coordinates },
  });

  const result = await migrateParqueDoTrabalhador(gateway, { dryRun: false });

  assert.deepEqual(result, { outcome: 'already-equivalent', changed: false });
  assert.equal(gateway.creates.length, 0);
  assert.equal(gateway.verifications.length, 1);
});

test('documento divergente aborta sem sobrescrever', async () => {
  const gateway = fakeGateway({ ...parqueDoTrabalhadorSeed, name: 'Outro local' });

  await assert.rejects(
    migrateParqueDoTrabalhador(gateway, { dryRun: false }),
    (error: unknown) => {
      assert.ok(error instanceof PlaceMigrationConflictError);
      assert.ok(error.differences.includes('name'));
      return true;
    },
  );
  assert.equal(gateway.creates.length, 0);
  assert.equal(gateway.verifications.length, 0);
});
