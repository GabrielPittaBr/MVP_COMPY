import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import {
  administrativeCallableOptions,
  type AdministrativeCallableRequest,
} from './admin_auth_read.js';

const maxFirebaseAuthUidLength = 128;
const operationIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const failureCodes = new Set(['not-found', 'permission-denied', 'failed-precondition', 'internal']);

export type UserSuspensionAction = 'suspend' | 'reactivate';
type OperationStatus = 'pending' | 'succeeded' | 'failed';
type StoredFailureCode = 'not-found' | 'permission-denied' | 'failed-precondition' | 'internal';

export interface SuspensionAuthUser {
  readonly uid: string;
  readonly disabled: boolean;
  readonly customClaims?: Readonly<Record<string, unknown>>;
}

export interface SuspensionAuthGateway {
  getUser(uid: string): Promise<SuspensionAuthUser>;
  updateDisabled(uid: string, disabled: boolean): Promise<void>;
  revokeRefreshTokens(uid: string): Promise<void>;
}

export interface SuspensionOperationInput {
  readonly operationId: string;
  readonly adminUid: string;
  readonly targetUid: string;
  readonly action: UserSuspensionAction;
  readonly reason: string;
}

export interface SuspensionOperation {
  readonly operationId: string;
  readonly adminUid: string;
  readonly targetUid: string;
  readonly action: UserSuspensionAction;
  readonly reason: string;
  readonly status: OperationStatus;
  readonly finalDisabled?: boolean;
  readonly failureCode?: StoredFailureCode;
  readonly completedAt?: Date;
}

export interface SuspensionOperationsGateway {
  claim(input: SuspensionOperationInput): Promise<{ readonly created: boolean; readonly operation: SuspensionOperation }>;
  succeed(operationId: string, finalDisabled: boolean): Promise<SuspensionOperation>;
  fail(operationId: string, failureCode: StoredFailureCode): Promise<SuspensionOperation>;
}

export interface UserSuspensionResult {
  readonly uid: string;
  readonly disabled: boolean;
  readonly action: UserSuspensionAction;
  readonly completedAt: string;
}

export class SuspensionOperationConflictError extends Error {
  constructor() {
    super('operationId já está associado a parâmetros diferentes.');
    this.name = 'SuspensionOperationConflictError';
  }
}

function requireAdministrator(request: AdministrativeCallableRequest): string {
  if (request.auth === undefined) {
    throw new HttpsError('unauthenticated', 'É necessário autenticar-se para acessar esta operação.');
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Esta operação exige uma conta administrativa.');
  }
  return request.auth.uid;
}

function requirePlainObject(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'O payload deve ser um objeto JSON.');
  }
  return value as Record<string, unknown>;
}

function requireExactKeys(value: Record<string, unknown>): void {
  const allowed = new Set(['uid', 'action', 'reason', 'operationId']);
  if (Object.keys(value).length !== allowed.size || Object.keys(value).some((key) => !allowed.has(key))) {
    throw new HttpsError('invalid-argument', 'O payload contém campos ausentes ou não permitidos.');
  }
}

function requireUid(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0 || value.length > maxFirebaseAuthUidLength || value.trim() !== value) {
    throw new HttpsError('invalid-argument', 'O UID informado é inválido.');
  }
  return value;
}

function requireAction(value: unknown): UserSuspensionAction {
  if (value !== 'suspend' && value !== 'reactivate') {
    throw new HttpsError('invalid-argument', 'A ação deve ser suspend ou reactivate.');
  }
  return value;
}

function requireReason(value: unknown): string {
  if (typeof value !== 'string') {
    throw new HttpsError('invalid-argument', 'O motivo informado é inválido.');
  }
  const normalized = value.trim().replace(/\s+/gu, ' ');
  if (normalized.length < 10 || normalized.length > 500) {
    throw new HttpsError('invalid-argument', 'O motivo deve ter de 10 a 500 caracteres.');
  }
  return normalized;
}

function requireOperationId(value: unknown): string {
  if (typeof value !== 'string' || !operationIdPattern.test(value)) {
    throw new HttpsError('invalid-argument', 'operationId deve ser um UUID v4 válido.');
  }
  return value.toLowerCase();
}

function parseInput(adminUid: string, data: unknown): SuspensionOperationInput {
  const value = requirePlainObject(data);
  requireExactKeys(value);
  const targetUid = requireUid(value.uid);
  if (targetUid === adminUid) {
    throw new HttpsError('failed-precondition', 'Um Administrador não pode alterar a própria conta.');
  }
  return {
    operationId: requireOperationId(value.operationId),
    adminUid,
    targetUid,
    action: requireAction(value.action),
    reason: requireReason(value.reason),
  };
}

function toResult(operation: SuspensionOperation): UserSuspensionResult {
  if (operation.status !== 'succeeded' || operation.finalDisabled === undefined || operation.completedAt === undefined) {
    throw new Error('Operação concluída sem resultado persistido.');
  }
  return {
    uid: operation.targetUid,
    disabled: operation.finalDisabled,
    action: operation.action,
    completedAt: operation.completedAt.toISOString(),
  };
}

function throwStoredFailure(operation: SuspensionOperation): never {
  const code = operation.failureCode ?? 'internal';
  const details = { operationStatus: 'failed' };
  switch (code) {
    case 'not-found':
      throw new HttpsError('not-found', 'A conta de usuário não foi encontrada.', details);
    case 'permission-denied':
      throw new HttpsError('permission-denied', 'A conta alvo não pode ser alterada pelo painel.', details);
    case 'failed-precondition':
      throw new HttpsError('failed-precondition', 'A conta já está no estado solicitado.', details);
    default:
      throw new HttpsError('internal', 'Não foi possível concluir a operação administrativa.', details);
  }
}

function toSafeFailureCode(error: unknown): StoredFailureCode {
  if (error instanceof HttpsError && failureCodes.has(error.code)) return error.code as StoredFailureCode;
  if (typeof error === 'object' && error !== null && 'code' in error && error.code === 'auth/user-not-found') {
    return 'not-found';
  }
  return 'internal';
}

async function failOperation(
  operations: SuspensionOperationsGateway,
  operationId: string,
  failureCode: StoredFailureCode,
): Promise<never> {
  try {
    return throwStoredFailure(await operations.fail(operationId, failureCode));
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    // Se o Firestore falhar ao finalizar, manter pending é mais seguro do que
    // inventar um resultado. A repetição com o mesmo operationId reconcilia.
    throw new HttpsError(
      'internal',
      'Não foi possível concluir a operação administrativa.',
      { operationStatus: 'pending' },
    );
  }
}

async function reconcilePendingOperation(
  operations: SuspensionOperationsGateway,
  auth: SuspensionAuthGateway,
  operation: SuspensionOperation,
  { isNew }: { readonly isNew: boolean },
): Promise<UserSuspensionResult> {
  let target: SuspensionAuthUser;
  try {
    target = await auth.getUser(operation.targetUid);
  } catch (error) {
    return failOperation(operations, operation.operationId, toSafeFailureCode(error));
  }

  if (target.customClaims?.admin === true) {
    return failOperation(operations, operation.operationId, 'permission-denied');
  }

  const desiredDisabled = operation.action === 'suspend';
  if (isNew && target.disabled === desiredDisabled) {
    return failOperation(operations, operation.operationId, 'failed-precondition');
  }

  try {
    if (target.disabled !== desiredDisabled) {
      await auth.updateDisabled(operation.targetUid, desiredDisabled);
    }
    // Revogar novamente é seguro e cobre uma interrupção entre disable e
    // revoke. Reativar não revoga nem restaura tokens antigos.
    if (desiredDisabled) await auth.revokeRefreshTokens(operation.targetUid);

    return toResult(await operations.succeed(operation.operationId, desiredDisabled));
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    // Falha depois de tocar Auth (inclusive após disable) fica pending para a
    // próxima chamada reconciliar o estado real da conta com segurança.
    throw new HttpsError(
      'internal',
      'Não foi possível concluir a operação administrativa.',
      { operationStatus: 'pending' },
    );
  }
}

export function createSetUserSuspensionHandler(
  auth: SuspensionAuthGateway,
  operations: SuspensionOperationsGateway,
) {
  return async (request: AdministrativeCallableRequest): Promise<UserSuspensionResult> => {
    const input = parseInput(requireAdministrator(request), request.data);

    let claimed;
    try {
      claimed = await operations.claim(input);
    } catch (error) {
      if (error instanceof SuspensionOperationConflictError) {
        throw new HttpsError('already-exists', 'operationId já está associado a outra operação.');
      }
      throw new HttpsError(
        'internal',
        'Não foi possível registrar a operação administrativa.',
        { operationStatus: 'pending' },
      );
    }

    if (claimed.operation.status === 'succeeded') return toResult(claimed.operation);
    if (claimed.operation.status === 'failed') return throwStoredFailure(claimed.operation);
    return reconcilePendingOperation(operations, auth, claimed.operation, { isNew: claimed.created });
  };
}

function parseStoredOperation(
  operationId: string,
  data: FirebaseFirestore.DocumentData,
): SuspensionOperation {
  const completedAt = data.completedAt instanceof Timestamp ? data.completedAt.toDate() : undefined;
  const status = data.status;
  if (
    typeof data.adminUid !== 'string'
    || typeof data.targetUid !== 'string'
    || (data.action !== 'suspend' && data.action !== 'reactivate')
    || typeof data.reason !== 'string'
    || (status !== 'pending' && status !== 'succeeded' && status !== 'failed')
  ) {
    throw new Error('Registro administrativo persistido possui formato inválido.');
  }
  return {
    operationId,
    adminUid: data.adminUid,
    targetUid: data.targetUid,
    action: data.action,
    reason: data.reason,
    status,
    ...(typeof data.finalDisabled === 'boolean' ? { finalDisabled: data.finalDisabled } : {}),
    ...(typeof data.failureCode === 'string' && failureCodes.has(data.failureCode)
      ? { failureCode: data.failureCode as StoredFailureCode }
      : {}),
    ...(completedAt === undefined ? {} : { completedAt }),
  };
}

function createFirestoreSuspensionOperationsGateway(): SuspensionOperationsGateway {
  const firestore = getFirestore();
  const collection = firestore.collection('adminOperations');

  return {
    claim: async (input) => firestore.runTransaction(async (transaction) => {
      const reference = collection.doc(input.operationId);
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        transaction.create(reference, {
          adminUid: input.adminUid,
          targetUid: input.targetUid,
          action: input.action,
          reason: input.reason,
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
        });
        return {
          created: true,
          operation: { ...input, status: 'pending' as const },
        };
      }

      const operation = parseStoredOperation(input.operationId, snapshot.data() ?? {});
      if (
        operation.adminUid !== input.adminUid
        || operation.targetUid !== input.targetUid
        || operation.action !== input.action
        || operation.reason !== input.reason
      ) {
        throw new SuspensionOperationConflictError();
      }
      return { created: false, operation };
    }),
    succeed: async (operationId, finalDisabled) => {
      const reference = collection.doc(operationId);
      await firestore.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        if (!snapshot.exists) throw new Error('Registro administrativo não encontrado.');
        const operation = parseStoredOperation(operationId, snapshot.data() ?? {});
        if (operation.status !== 'pending') return;
        transaction.update(reference, {
          status: 'succeeded',
          finalDisabled,
          completedAt: FieldValue.serverTimestamp(),
        });
      });
      const snapshot = await reference.get();
      return parseStoredOperation(operationId, snapshot.data() ?? {});
    },
    fail: async (operationId, failureCode) => {
      const reference = collection.doc(operationId);
      await firestore.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(reference);
        if (!snapshot.exists) throw new Error('Registro administrativo não encontrado.');
        const operation = parseStoredOperation(operationId, snapshot.data() ?? {});
        if (operation.status !== 'pending') return;
        transaction.update(reference, {
          status: 'failed',
          failureCode,
          completedAt: FieldValue.serverTimestamp(),
        });
      });
      const snapshot = await reference.get();
      return parseStoredOperation(operationId, snapshot.data() ?? {});
    },
  };
}

const firebaseAuthGateway: SuspensionAuthGateway = {
  getUser: async (uid) => getAuth().getUser(uid),
  updateDisabled: async (uid, disabled) => {
    await getAuth().updateUser(uid, { disabled });
  },
  revokeRefreshTokens: async (uid) => {
    await getAuth().revokeRefreshTokens(uid);
  },
};

export const setUserSuspension = onCall(administrativeCallableOptions, (request) =>
  createSetUserSuspensionHandler(firebaseAuthGateway, createFirestoreSuspensionOperationsGateway())(request),
);
