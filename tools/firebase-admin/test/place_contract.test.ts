import assert from 'node:assert/strict';
import test from 'node:test';

import {
  normalizePtBr,
  parqueDoTrabalhadorSeed,
  PlaceValidationError,
  type PlaceSeed,
  supportedSports,
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

test('contrato conhece as 16 modalidades do enum Sport (issue 30)', () => {
  assert.deepEqual(supportedSports, [
    'futebol', 'futsal', 'basquete', 'volei',
    'handebol', 'tenis', 'tenisDeMesa', 'padel',
    'futebolDeAreia', 'voleiDePraia', 'futevolei', 'beachTennis',
    'corrida', 'ciclismo', 'caminhada', 'skate',
  ]);
});

test('contrato aceita local com as modalidades novas de areia', () => {
  const arena: PlaceSeed = {
    ...parqueDoTrabalhadorSeed,
    sports: ['beachTennis', 'futevolei', 'voleiDePraia', 'futebolDeAreia'],
    primarySport: 'beachTennis',
  };
  assert.doesNotThrow(() => validatePlaceSeed(arena));
});

test('contrato aceita local com todas as modalidades', () => {
  const todas: PlaceSeed = {
    ...parqueDoTrabalhadorSeed,
    sports: [...supportedSports],
    primarySport: 'skate',
  };
  assert.doesNotThrow(() => validatePlaceSeed(todas));
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

// Natação ficou fora da issue 30. O tipo `SupportedSport` já barra o nome no
// TypeScript; o cast simula o dado que chega de fora dele (JSON, Firestore).
for (const [name, sports] of [
  ['modalidade desconhecida', ['futebol', 'natacao']],
  ['mais modalidades do que existem', [...supportedSports, 'natacao']],
] as const) {
  test(`contrato recusa ${name}`, () => {
    const candidate = { ...parqueDoTrabalhadorSeed, sports } as unknown as PlaceSeed;
    assert.throws(() => validatePlaceSeed(candidate), PlaceValidationError);
  });
}
