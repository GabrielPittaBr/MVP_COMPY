import assert from 'node:assert/strict';
import test from 'node:test';

import {
  normalizePtBr,
  parqueDoTrabalhadorSeed,
  PlaceValidationError,
  validatePlaceSeed,
} from '../src/places/place_contract.js';

test('normalizador pt-BR reproduz o comportamento aprovado do mobile', () => {
  assert.equal(normalizePtBr('  Vôlei Çã  '), 'volei ca');
  assert.equal(normalizePtBr('Tênis de Mesa'), 'tenis de mesa');
});

test('seed aprovado do Parque do Trabalhador é completo e válido', () => {
  assert.doesNotThrow(() => validatePlaceSeed(parqueDoTrabalhadorSeed));
  assert.equal(parqueDoTrabalhadorSeed.address.number, undefined);
  assert.equal(parqueDoTrabalhadorSeed.status, 'active');
});

for (const [name, mutation] of [
  ['normalização divergente', { nameLower: 'parque trabalhador' }],
  ['CEP mascarado', { address: { ...parqueDoTrabalhadorSeed.address, postalCode: '95600-354' } }],
  ['UF inválida', { address: { ...parqueDoTrabalhadorSeed.address, state: 'Rio Grande do Sul' } }],
  ['modalidade duplicada', { sports: ['futebol', 'futebol'] }],
  ['modalidade principal ausente', { primarySport: 'tenisDeMesa' }],
  ['imagem HTTP', { imageUrl: 'http://example.test/place.png' }],
  ['latitude inválida', { coordinates: { latitude: -91, longitude: 0 } }],
] as const) {
  test(`contrato recusa ${name}`, () => {
    const candidate = {
      ...parqueDoTrabalhadorSeed,
      ...mutation,
    };
    assert.throws(
      () => validatePlaceSeed(candidate),
      PlaceValidationError,
    );
  });
}
