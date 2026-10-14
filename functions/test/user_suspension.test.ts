import assert from 'node:assert/strict';
import test from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import {
  createSetUserSuspensionHandler,
  SuspensionOperationConflictError,
  type SuspensionAuthGateway,
  type SuspensionAuthUser,
  type SuspensionOperation,
  type SuspensionOperationInput,
  type SuspensionOperationsGateway,
} from '../src/user_suspension.js';
import type { AdministrativeCallableRequest } from '../src/admin_auth_read.js';

const operationId = 'a04988af-ccba-4c4e-a0d2-df5c56be31d6';
const completedAt = new Date('2026-09-25T12:00:00.000Z');

const adminRequest = (data: unknown): AdministrativeCallableRequest => ({
  data,
  auth: { uid: 'admin-uid', token: { admin: true } },
});

const validInput = (overrides: Record<string, unknown> = {}) => ({
  uid: 'target-uid',
  action: 'suspend',
  reason: 'Violação comprovada das regras da comunidade.',
  operationId,
  ...overrides,
});

function createAuthGateway(overrides: Partial<SuspensionAuthGateway> = {}): SuspensionAuthGateway & {
  readonly updated: Array<{ uid: string; disabled: boolean }>;
  readonly revocations: string[];
} {
  const updated: Array<{ uid: string; disabled: boolean }> = [];
  const revocations: string[] = [];
  let user: SuspensionAuthUser = { uid: 'target-uid', disabled: false };
  return {
    updated,
    revocations,
    getUser: async () => user,
    updateDisabled: async (uid, disabled) => {
      updated.push({ uid, disabled });
      user = { ...user, disabled };
    },
    revokeRefreshTokens: async (uid) => {
      revocations.push(uid);
    },
    ...overrides,
  };
}

class FakeOperationsGateway implements SuspensionOperationsGateway {
  finalOperations = new Map<string, SuspensionOperation>();

  async claim(input: SuspensionOperationInput) {
    const existing = this.finalOperations.get(input.operationId);
    if (existing === undefined) {
      const operation: SuspensionOperation = { ...input, status: 'pending' };
      this.finalOperations.set(input.operationId, operation);
      return { created: true, operation };
    }
    if (
      existing.adminUid !== input.adminUid
      || existing.targetUid !== input.targetUid
      || existing.action !== input.action
      || existing.reason !== input.reason
    ) {
      throw new SuspensionOperationConflictError();
    }
    return { created: false, operation: existing };
  }

  async succeed(operationIdValue: string, finalDisabled: boolean): Promise<SuspensionOperation> {
    const existing = this.finalOperations.get(operationIdValue);
    assert.ok(existing);
    const operation = existing.status === 'pending'
        ? { ...existing, status: 'succeeded' as const, finalDisabled, completedAt }
        : existing;
    this.finalOperations.set(operationIdValue, operation);
    return operation;
  }

  async fail(operationIdValue: string, failureCode: 'not-found' | 'permission-denied' | 'failed-precondition' | 'internal'): Promise<SuspensionOperation> {
    const existing = this.finalOperations.get(operationIdValue);
    assert.ok(existing);
    const operation = existing.status === 'pending'
        ? { ...existing, status: 'failed' as const, failureCode, completedAt }
        : existing;
    this.finalOperations.set(operationIdValue, operation);
    return operation;
  }

  seed(operation: SuspensionOperation): void {
    this.finalOperations.set(operation.operationId, operation);
  }
}

async function assertHttpsError(operation: Promise<unknown>, code: HttpsError['code']): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.ok(error instanceof HttpsError);
    assert.equal(error.code, code);
    return true;
  });
}

test('suspensão cria operação, desabilita Auth, revoga token e retorna contrato mínimo', async () => {
  const auth = createAuthGateway();
  const operations = new FakeOperationsGateway();
  const handler = createSetUserSuspensionHandler(auth, operations);

  const result = await handler(adminRequest(validInput({ reason: '  Violação   comprovada das regras da comunidade. ' })));

  assert.deepEqual(result, {
    uid: 'target-uid',
    disabled: true,
    action: 'suspend',
    completedAt: completedAt.toISOString(),
  });
  assert.deepEqual(auth.updated, [{ uid: 'target-uid', disabled: true }]);
  assert.deepEqual(auth.revocations, ['target-uid']);
  assert.equal(operations.finalOperations.get(operationId)?.reason, 'Violação comprovada das regras da comunidade.');
});

test('reativação habilita Auth sem revogar tokens antigos', async () => {
  const auth = createAuthGateway({ getUser: async () => ({ uid: 'target-uid', disabled: true }) });
  const operations = new FakeOperationsGateway();
  const handler = createSetUserSuspensionHandler(auth, operations);

  const result = await handler(adminRequest(validInput({ action: 'reactivate' })));

  assert.equal(result.disabled, false);
  assert.deepEqual(auth.updated, [{ uid: 'target-uid', disabled: false }]);
  assert.deepEqual(auth.revocations, []);
});

test('rejeita autenticação, payload, autoação e operação em administrador', async () => {
  const operations = new FakeOperationsGateway();
  const handler = createSetUserSuspensionHandler(
    createAuthGateway({ getUser: async () => ({ uid: 'target-uid', disabled: false, customClaims: { admin: true } }) }),
    operations,
  );

  await assertHttpsError(handler({ data: validInput() }), 'unauthenticated');
  await assertHttpsError(handler(adminRequest(validInput({ extra: true }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(validInput({ operationId: 'not-a-uuid' }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(validInput({ reason: 'curto' }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(validInput({ uid: 'admin-uid' }))), 'failed-precondition');
  await assertHttpsError(handler(adminRequest(validInput())), 'permission-denied');
});

test('operação repetida sucedida devolve resultado persistido sem tocar Auth', async () => {
  const auth = createAuthGateway();
  const operations = new FakeOperationsGateway();
  const handler = createSetUserSuspensionHandler(auth, operations);

  await handler(adminRequest(validInput()));
  await handler(adminRequest(validInput()));

  assert.deepEqual(auth.updated, [{ uid: 'target-uid', disabled: true }]);
  assert.deepEqual(auth.revocations, ['target-uid']);
});

test('operationId com parâmetros diferentes é rejeitado', async () => {
  const handler = createSetUserSuspensionHandler(createAuthGateway(), new FakeOperationsGateway());

  await handler(adminRequest(validInput()));
  await assertHttpsError(handler(adminRequest(validInput({ reason: 'Outro motivo administrativo válido.' }))), 'already-exists');
});

test('estado já desejado falha e repetição devolve a mesma falha', async () => {
  const auth = createAuthGateway({ getUser: async () => ({ uid: 'target-uid', disabled: true }) });
  const operations = new FakeOperationsGateway();
  const handler = createSetUserSuspensionHandler(auth, operations);

  await assertHttpsError(handler(adminRequest(validInput())), 'failed-precondition');
  await assertHttpsError(handler(adminRequest(validInput())), 'failed-precondition');
  assert.deepEqual(auth.updated, []);
});

test('pending já suspensa reaplica revogação e reconcilia sucesso', async () => {
  const auth = createAuthGateway({ getUser: async () => ({ uid: 'target-uid', disabled: true }) });
  const operations = new FakeOperationsGateway();
  operations.seed({
    operationId,
    adminUid: 'admin-uid',
    targetUid: 'target-uid',
    action: 'suspend',
    reason: 'Violação comprovada das regras da comunidade.',
    status: 'pending',
  });
  const handler = createSetUserSuspensionHandler(auth, operations);

  const result = await handler(adminRequest(validInput()));

  assert.equal(result.disabled, true);
  assert.deepEqual(auth.updated, []);
  assert.deepEqual(auth.revocations, ['target-uid']);
});

test('falha após alterar Auth preserva pending para reconciliação segura', async () => {
  let disabled = false;
  let failAfterDisable = true;
  const updated: Array<{ uid: string; disabled: boolean }> = [];
  const revocations: string[] = [];
  const auth: SuspensionAuthGateway = {
    getUser: async () => ({ uid: 'target-uid', disabled }),
    updateDisabled: async (uid, nextDisabled) => {
      updated.push({ uid, disabled: nextDisabled });
      disabled = nextDisabled;
      if (failAfterDisable) {
        failAfterDisable = false;
        throw new Error('interrupção depois de alterar Auth');
      }
    },
    revokeRefreshTokens: async (uid) => {
      revocations.push(uid);
    },
  };
  const operations = new FakeOperationsGateway();
  const handler = createSetUserSuspensionHandler(auth, operations);

  await assert.rejects(
    handler(adminRequest(validInput())),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, 'internal');
      assert.deepEqual(error.details, { operationStatus: 'pending' });
      return true;
    },
  );
  assert.equal(operations.finalOperations.get(operationId)?.status, 'pending');

  const result = await handler(adminRequest(validInput()));
  assert.equal(result.disabled, true);
  assert.deepEqual(updated, [{ uid: 'target-uid', disabled: true }]);
  assert.deepEqual(revocations, ['target-uid']);
});

test('conta ausente vira falha sanitizada e não vaza erro do Admin SDK', async () => {
  const auth = createAuthGateway({
    getUser: async () => Promise.reject({ code: 'auth/user-not-found', message: 'private token' }),
  });
  const operations = new FakeOperationsGateway();
  const handler = createSetUserSuspensionHandler(auth, operations);

  await assertHttpsError(handler(adminRequest(validInput())), 'not-found');
  assert.equal(operations.finalOperations.get(operationId)?.failureCode, 'not-found');
  await assert.rejects(
    handler(adminRequest(validInput())),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, 'not-found');
      assert.deepEqual(error.details, { operationStatus: 'failed' });
      assert.equal(error.message.includes('private token'), false);
      return true;
    },
  );
});
