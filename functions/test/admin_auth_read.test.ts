import assert from 'node:assert/strict';
import test from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import {
  administrativeCallableOptions,
  createGetAdminUserAuthDetailsHandler,
  createGetAdminUsersAuthStatusHandler,
  type AdministrativeAuthGateway,
  type AdministrativeAuthUser,
  type AdministrativeCallableRequest,
} from '../src/admin_auth_read.js';

const adminRequest = (data: unknown): AdministrativeCallableRequest => ({
  data,
  auth: {
    uid: 'admin-uid',
    token: { admin: true },
  },
});

const regularRequest = (data: unknown): AdministrativeCallableRequest => ({
  data,
  auth: {
    uid: 'regular-uid',
    token: { admin: false },
  },
});

const account: AdministrativeAuthUser = {
  uid: 'user-1',
  email: 'person@example.com',
  emailVerified: true,
  disabled: false,
  providerIds: ['password', 'google.com', 'password'],
  createdAt: '2026-01-02T03:04:05.000Z',
  lastSignInAt: '2026-02-03T04:05:06.000Z',
};

function createGateway(overrides: Partial<AdministrativeAuthGateway> = {}): AdministrativeAuthGateway {
  return {
    getUser: async (uid) => ({ ...account, uid }),
    getUserByEmail: async (email) => ({ ...account, email }),
    getUsers: async (uids) => uids.map((uid) => ({ ...account, uid, disabled: uid === 'suspended-user' })),
    ...overrides,
  };
}

async function assertHttpsError(
  operation: Promise<unknown>,
  expectedCode: HttpsError['code'],
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.ok(error instanceof HttpsError);
    assert.equal(error.code, expectedCode);
    return true;
  });
}

test('Callables administrativas habilitam App Check para produção', () => {
  assert.equal(administrativeCallableOptions.enforceAppCheck, true);
});

test('detalhe exige autenticação e claim administrativa', async () => {
  const handler = createGetAdminUserAuthDetailsHandler(createGateway());

  await assertHttpsError(handler({ data: { uid: 'user-1' } }), 'unauthenticated');
  await assertHttpsError(handler(regularRequest({ uid: 'user-1' })), 'permission-denied');
});

test('detalhe por UID retorna somente o contrato aprovado', async () => {
  const handler = createGetAdminUserAuthDetailsHandler(createGateway());

  const result = await handler(adminRequest({ uid: 'user-1' }));

  assert.deepEqual(result, {
    uid: 'user-1',
    email: 'person@example.com',
    emailVerified: true,
    providerIds: ['password', 'google.com'],
    createdAt: '2026-01-02T03:04:05.000Z',
    lastSignInAt: '2026-02-03T04:05:06.000Z',
    disabled: false,
  });
});

test('detalhe normaliza e-mail e não retorna dados extras de Auth', async () => {
  let requestedEmail: string | undefined;
  const handler = createGetAdminUserAuthDetailsHandler(
    createGateway({
      getUserByEmail: async (email) => {
        requestedEmail = email;
        return {
          ...account,
          email: undefined,
          providerIds: ['password'],
          createdAt: undefined,
          lastSignInAt: undefined,
        };
      },
    }),
  );

  const result = await handler(adminRequest({ email: '  PERSON@EXAMPLE.COM  ' }));

  assert.equal(requestedEmail, 'person@example.com');
  assert.deepEqual(result, {
    uid: 'user-1',
    email: null,
    emailVerified: true,
    providerIds: ['password'],
    createdAt: null,
    lastSignInAt: null,
    disabled: false,
  });
  assert.deepEqual(Object.keys(result).sort(), [
    'createdAt',
    'disabled',
    'email',
    'emailVerified',
    'lastSignInAt',
    'providerIds',
    'uid',
  ]);
});

test('detalhe rejeita identificadores ambíguos, payload adicional e valores inválidos', async () => {
  const handler = createGetAdminUserAuthDetailsHandler(createGateway());

  await assertHttpsError(handler(adminRequest({})), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ uid: 'user-1', email: 'person@example.com' })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ uid: 'user-1', extra: true })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ uid: ' user-1 ' })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ email: 'not-an-email' })), 'invalid-argument');
});

test('detalhe traduz conta ausente e falhas internas sem vazar mensagem do SDK', async () => {
  const notFoundHandler = createGetAdminUserAuthDetailsHandler(
    createGateway({
      getUser: async () => Promise.reject({ code: 'auth/user-not-found', message: 'SDK detail' }),
    }),
  );
  const internalHandler = createGetAdminUserAuthDetailsHandler(
    createGateway({
      getUser: async () => Promise.reject(new Error('credential token and SDK stack detail')),
    }),
  );

  await assertHttpsError(notFoundHandler(adminRequest({ uid: 'missing-user' })), 'not-found');
  await assertHttpsError(internalHandler(adminRequest({ uid: 'user-1' })), 'internal');
});

test('status em lote exige lista única de um a vinte UIDs', async () => {
  const handler = createGetAdminUsersAuthStatusHandler(createGateway());

  await assertHttpsError(handler({ data: { uids: ['user-1'] } }), 'unauthenticated');
  await assertHttpsError(handler(regularRequest({ uids: ['user-1'] })), 'permission-denied');
  await assertHttpsError(handler(adminRequest({ uids: [] })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ uids: Array.from({ length: 21 }, (_, index) => `user-${index}`) })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ uids: ['user-1', 'user-1'] })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ uids: [' user-1 '] })), 'invalid-argument');
  await assertHttpsError(handler(adminRequest({ uids: ['user-1'], extra: true })), 'invalid-argument');
});

test('status em lote preserva ordem, omite ausentes e minimiza dados retornados', async () => {
  const handler = createGetAdminUsersAuthStatusHandler(
    createGateway({
      getUsers: async () => [
        { ...account, uid: 'suspended-user', disabled: true },
        { ...account, uid: 'active-user', disabled: false },
      ],
    }),
  );

  const result = await handler(adminRequest({ uids: ['active-user', 'missing-user', 'suspended-user'] }));

  assert.deepEqual(result, {
    items: [
      { uid: 'active-user', disabled: false },
      { uid: 'suspended-user', disabled: true },
    ],
  });
  assert.deepEqual(Object.keys(result.items[0]).sort(), ['disabled', 'uid']);
});

test('status em lote sanitiza falhas do Admin SDK', async () => {
  const handler = createGetAdminUsersAuthStatusHandler(
    createGateway({
      getUsers: async () => Promise.reject(new Error('private provider token')),
    }),
  );

  await assertHttpsError(handler(adminRequest({ uids: ['user-1'] })), 'internal');
});
