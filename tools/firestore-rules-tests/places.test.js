/**
 * Contrato transitório de `places`: o catálogo ainda não é escritor do
 * mobile, mas Rules, índice e migração precisam estar corretos antes disso.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  GeoPoint,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  startAt,
  endAt,
  updateDoc,
  where,
} from 'firebase/firestore';

const ADMIN = 'uid_admin';
const USER = 'uid_user';
const PLACE_ACTIVE = 'place_active';
const PLACE_INACTIVE = 'place_inactive';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-compy',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

const asUser = (uid = USER) => testEnv.authenticatedContext(uid).firestore();
const asAdmin = () => testEnv.authenticatedContext(ADMIN, { admin: true }).firestore();
const anonymous = () => testEnv.unauthenticatedContext().firestore();

function validPlace({ status = 'inactive' } = {}) {
  return {
    name: 'Parque do Trabalhador',
    nameLower: 'parque do trabalhador',
    description: 'Parque público de Taquara com campo, quadras e espaço para caminhada.',
    address: {
      street: 'Rua Ernesto Alves',
      neighborhood: 'Recreio',
      city: 'Taquara',
      cityLower: 'taquara',
      state: 'RS',
      postalCode: '95600354',
    },
    sports: ['futebol', 'basquete', 'corrida'],
    primarySport: 'futebol',
    coordinates: new GeoPoint(-29.656276729317323, -50.787726691670045),
    imageUrl: 'https://images.unsplash.com/photo-1551958219-acbc608c6377?w=600',
    status,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

async function seed(id, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'places', id), data);
  });
}

describe('places — leitura por papel', () => {
  beforeEach(async () => {
    await seed(PLACE_ACTIVE, { ...validPlace({ status: 'active' }), createdAt: new Date(), updatedAt: new Date() });
    await seed(PLACE_INACTIVE, { ...validPlace({ status: 'inactive' }), createdAt: new Date(), updatedAt: new Date() });
  });

  it('usuário autenticado lista somente ativos com o filtro obrigatório', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(asUser(), 'places'),
          where('status', '==', 'active'),
          orderBy('nameLower'),
          limit(20),
        ),
      ),
    );
  });

  it('usuário autenticado não lista sem filtro de status nem inativos', async () => {
    await assertFails(getDocs(query(collection(asUser(), 'places'), orderBy('nameLower'))));
    await assertFails(
      getDocs(
        query(
          collection(asUser(), 'places'),
          where('status', '==', 'inactive'),
          orderBy('nameLower'),
        ),
      ),
    );
  });

  it('usuário resolve um local inativo somente por ID para histórico', async () => {
    await assertSucceeds(getDoc(doc(asUser(), 'places', PLACE_INACTIVE)));
  });

  it('Administrador lista ativos e inativos', async () => {
    await assertSucceeds(getDocs(query(collection(asAdmin(), 'places'), orderBy('nameLower'))));
  });

  const adminPrefixQueryCases = [
    ['somente prefixo', []],
    ['status', [where('status', '==', 'active')]],
    ['modalidade', [where('sports', 'array-contains', 'futebol')]],
    ['cidade', [where('address.cityLower', '==', 'taquara')]],
    [
      'modalidade e status',
      [where('sports', 'array-contains', 'futebol'), where('status', '==', 'active')],
    ],
    [
      'status e cidade',
      [where('status', '==', 'inactive'), where('address.cityLower', '==', 'taquara')],
    ],
    [
      'modalidade e cidade',
      [where('sports', 'array-contains', 'futebol'), where('address.cityLower', '==', 'taquara')],
    ],
    [
      'modalidade, status e cidade',
      [
        where('sports', 'array-contains', 'futebol'),
        where('status', '==', 'active'),
        where('address.cityLower', '==', 'taquara'),
      ],
    ],
  ];

  for (const [description, filters] of adminPrefixQueryCases) {
    it(`Administrador executa query por prefixo combinada com ${description}`, async () => {
      const placesQuery = query(
        collection(asAdmin(), 'places'),
        ...filters,
        orderBy('nameLower'),
        startAt('parque'),
        endAt('parque\uf8ff'),
        limit(20),
      );
      await assertSucceeds(getDocs(placesQuery));
    });
  }

  it('deslogado não lê Local Esportivo', async () => {
    await assertFails(getDoc(doc(anonymous(), 'places', PLACE_ACTIVE)));
  });
});

describe('places — escrita administrativa e schema', () => {
  it('SDK cliente recusa latitude inválida antes da escrita chegar às Rules', () => {
    assert.throws(
      () => new GeoPoint(-91, 0),
      /Latitude must be a number between -90 and 90/,
    );
  });

  it('Administrador cria documento completo inicialmente inativo', async () => {
    await assertSucceeds(setDoc(doc(asAdmin(), 'places', 'novo'), validPlace()));
  });

  it('Administrador não cria Local Esportivo ativo', async () => {
    await assertFails(setDoc(doc(asAdmin(), 'places', 'novo'), validPlace({ status: 'active' })));
  });

  it('usuário comum não cria mesmo documento válido', async () => {
    await assertFails(setDoc(doc(asUser(), 'places', 'novo'), validPlace()));
  });

  for (const [name, mutation] of [
    ['campo fora da whitelist', { rating: 5 }],
    ['modalidade duplicada', { sports: ['futebol', 'futebol'] }],
    ['modalidade principal incompatível', { primarySport: 'volei' }],
    ['CEP com máscara', { address: { ...validPlace().address, postalCode: '95600-354' } }],
    ['imagem sem HTTPS', { imageUrl: 'http://example.test/place.png' }],
    // GeoPoint inválido não pode ser construído pelo SDK cliente. O Rules
    // Emulator recebe uma escrita possível com tipo incorreto; a faixa de
    // latitude/longitude permanece validada nas Rules para GeoPoints válidos.
    ['coordenadas não são GeoPoint', { coordinates: { latitude: -91, longitude: 0 } }],
    ['timestamp do cliente', { createdAt: new Date(), updatedAt: new Date() }],
  ]) {
    it(`Administrador não cria ${name}`, async () => {
      await assertFails(
        setDoc(doc(asAdmin(), 'places', `invalid-${name}`), {
          ...validPlace(),
          ...mutation,
        }),
      );
    });
  }

  it('update administrativo preserva createdAt e renova updatedAt no servidor', async () => {
    await seed('editavel', {
      ...validPlace(),
      createdAt: new Date('2026-01-01T00:00:00Z'),
      updatedAt: new Date('2026-01-01T00:00:00Z'),
    });

    await assertSucceeds(
      updateDoc(doc(asAdmin(), 'places', 'editavel'), {
        description: 'Parque público de Taquara com campo, quadras, pista e áreas abertas para esportes.',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('update administrativo não altera createdAt', async () => {
    await seed('editavel', {
      ...validPlace(),
      createdAt: new Date('2026-01-01T00:00:00Z'),
      updatedAt: new Date('2026-01-01T00:00:00Z'),
    });

    await assertFails(
      updateDoc(doc(asAdmin(), 'places', 'editavel'), {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('delete é negado inclusive para Administrador', async () => {
    await seed('editavel', {
      ...validPlace(),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await assertFails(deleteDoc(doc(asAdmin(), 'places', 'editavel')));
  });

  it('consulta mobile por modalidade usa status ativo e array-contains', async () => {
    await seed(PLACE_ACTIVE, { ...validPlace({ status: 'active' }), createdAt: new Date(), updatedAt: new Date() });
    await assertSucceeds(
      getDocs(
        query(
          collection(asUser(), 'places'),
          where('status', '==', 'active'),
          where('sports', 'array-contains', 'futebol'),
          orderBy('nameLower'),
          limit(20),
        ),
      ),
    );
  });
});
