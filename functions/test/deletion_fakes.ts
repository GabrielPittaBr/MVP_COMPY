import assert from 'node:assert/strict';

import { HttpsError } from 'firebase-functions/v2/https';

import type { AdministrativeCallableRequest } from '../src/admin_auth_read.js';
import {
  DeletionOperationConflictError,
  type DeletionFailureCode,
  type DeletionOperation,
  type DeletionOperationInput,
  type DeletionOperationsGateway,
} from '../src/admin_deletion.js';

export const operationId = 'b7e1c2d3-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
export const completedAt = new Date('2026-10-23T12:00:00.000Z');
export const reason = 'Conteúdo falso denunciado por vários usuários.';

export const adminRequest = (data: unknown): AdministrativeCallableRequest => ({
  data,
  auth: { uid: 'admin-uid', token: { admin: true } },
});

/** `adminOperations` de mentira, com o mesmo protocolo do gateway real. */
export class FakeDeletionOperations implements DeletionOperationsGateway {
  readonly operations = new Map<string, DeletionOperation>();

  async claim(input: DeletionOperationInput) {
    const existing = this.operations.get(input.operationId);
    if (existing === undefined) {
      const operation: DeletionOperation = { ...input, status: 'pending' };
      this.operations.set(input.operationId, operation);
      return { created: true, operation };
    }
    if (
      existing.adminUid !== input.adminUid
      || existing.action !== input.action
      || existing.targetId !== input.targetId
      || existing.reason !== input.reason
    ) {
      throw new DeletionOperationConflictError();
    }
    return { created: false, operation: existing };
  }

  async succeed(id: string): Promise<DeletionOperation> {
    return this.finish(id, { status: 'succeeded' });
  }

  async fail(id: string, failureCode: DeletionFailureCode): Promise<DeletionOperation> {
    return this.finish(id, { status: 'failed', failureCode });
  }

  seed(operation: DeletionOperation): void {
    this.operations.set(operation.operationId, operation);
  }

  private finish(id: string, fields: Partial<DeletionOperation>): DeletionOperation {
    const existing = this.operations.get(id);
    assert.ok(existing);
    const operation = existing.status === 'pending' ? { ...existing, ...fields, completedAt } : existing;
    this.operations.set(id, operation);
    return operation;
  }
}

export async function assertHttpsError(
  operation: Promise<unknown>,
  code: HttpsError['code'],
  details?: unknown,
): Promise<void> {
  await assert.rejects(operation, (error: unknown) => {
    assert.ok(error instanceof HttpsError);
    assert.equal(error.code, code);
    if (details !== undefined) assert.deepEqual(error.details, details);
    return true;
  });
}
