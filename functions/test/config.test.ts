import assert from 'node:assert/strict';
import test from 'node:test';
import { getApps } from 'firebase-admin/app';

import { administrativeFunctionsRegion } from '../src/config.js';
import {
  autoEndOverdueEvents,
  getAdminUserAuthDetails,
  getAdminUsersAuthStatus,
  setUserSuspension,
  submitEventRatings,
} from '../src/index.js';

test('Functions administrativas usam a região aprovada', () => {
  assert.equal(administrativeFunctionsRegion, 'southamerica-east1');
});

test('entrypoint inicializa o Firebase Admin antes de exportar as Callables', () => {
  assert.ok(getApps().some((app) => app.name === '[DEFAULT]'));
});

test('as três Callables exportam a região aprovada no contrato de deploy', () => {
  for (const callable of [getAdminUserAuthDetails, getAdminUsersAuthStatus, setUserSuspension]) {
    assert.deepEqual(callable.__endpoint.region, ['southamerica-east1']);
  }
});

test('a callable da avaliação usa a região aprovada', () => {
  assert.deepEqual(submitEventRatings.__endpoint.region, ['southamerica-east1']);
});

test('o encerramento automático roda a cada 10 min, na região e no fuso aprovados', () => {
  const endpoint = autoEndOverdueEvents.__endpoint;
  assert.deepEqual(endpoint.region, ['southamerica-east1']);
  assert.equal(endpoint.scheduleTrigger?.schedule, 'every 10 minutes');
  assert.equal(endpoint.scheduleTrigger?.timeZone, 'America/Sao_Paulo');
});
