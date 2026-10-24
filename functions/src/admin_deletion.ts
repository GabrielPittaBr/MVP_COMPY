import { FieldValue, getFirestore, Timestamp, type DocumentReference, type Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import type { AdministrativeCallableRequest } from './admin_auth_read.js';

/**
 * Protocolo comum às exclusões do Painel Administrativo (`deleteEvent` e
 * `deleteUserAccount`). Como na suspensão, cada exclusão vira um registro em
 * `adminOperations/{operationId}` — quem excluiu, o quê e por quê — que
 * nenhum cliente lê. O registro também torna a repetição segura: o painel
 * reenvia o mesmo `operationId` quando não sabe se a chamada anterior chegou
 * ao fim, e cada passo da exclusão tolera o que já foi apagado.
 */

const maxTargetIdLength = 128;
const operationIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
/** Limite de escritas de um `WriteBatch`. */
const batchLimit = 500;

export type DeletionAction = 'deleteEvent' | 'deleteUserAccount';
export type DeletionFailureCode = 'not-found' | 'permission-denied' | 'internal';
type DeletionStatus = 'pending' | 'succeeded' | 'failed';

const failureCodes = new Set<string>(['not-found', 'permission-denied', 'internal']);

export interface DeletionOperationInput {
  readonly operationId: string;
  readonly adminUid: string;
  readonly action: DeletionAction;
  readonly targetId: string;
  readonly reason: string;
}

export interface DeletionOperation extends DeletionOperationInput {
  readonly status: DeletionStatus;
  readonly failureCode?: DeletionFailureCode;
  readonly completedAt?: Date;
}

export interface DeletionOperationsGateway {
  claim(input: DeletionOperationInput): Promise<{ readonly created: boolean; readonly operation: DeletionOperation }>;
  succeed(operationId: string): Promise<DeletionOperation>;
  fail(operationId: string, failureCode: DeletionFailureCode): Promise<DeletionOperation>;
}

export interface DeletionResult {
  readonly targetId: string;
  readonly completedAt: string;
}

export class DeletionOperationConflictError extends Error {
  constructor() {
    super('operationId já está associado a parâmetros diferentes.');
    this.name = 'DeletionOperationConflictError';
  }
}

/** Recusa definitiva: a operação vira `failed` e a repetição devolve a mesma falha. */
class DeletionRefusal extends Error {
  constructor(readonly code: 'not-found' | 'permission-denied') {
    super(`Exclusão recusada: ${code}.`);
    this.name = 'DeletionRefusal';
  }
}

export function refuseDeletion(code: 'not-found' | 'permission-denied'): never {
  throw new DeletionRefusal(code);
}

export function requireAdministrator(request: AdministrativeCallableRequest): string {
  if (request.auth === undefined) {
    throw new HttpsError('unauthenticated', 'É necessário autenticar-se para acessar esta operação.');
  }
  if (request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Esta operação exige uma conta administrativa.');
  }
  return request.auth.uid;
}

function requireTargetId(value: unknown): string {
  // O id vira caminho de documento: barra, `.`, `..` e `__x__` não são ids válidos.
  if (
    typeof value !== 'string'
    || value.length === 0
    || value.length > maxTargetIdLength
    || value.trim() !== value
    || value.includes('/')
    || value === '.'
    || value === '..'
    || /^__.*__$/u.test(value)
  ) {
    throw new HttpsError('invalid-argument', 'O identificador informado é inválido.');
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

/** Payload exato `{<targetKey>, reason, operationId}`, sem campos extras. */
export function parseDeletionInput(
  adminUid: string,
  data: unknown,
  action: DeletionAction,
  targetKey: 'eventId' | 'uid',
): DeletionOperationInput {
  if (data === null || typeof data !== 'object' || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'O payload deve ser um objeto JSON.');
  }
  const value = data as Record<string, unknown>;
  const allowed = new Set([targetKey, 'reason', 'operationId']);
  if (Object.keys(value).length !== allowed.size || Object.keys(value).some((key) => !allowed.has(key))) {
    throw new HttpsError('invalid-argument', 'O payload contém campos ausentes ou não permitidos.');
  }
  return {
    operationId: requireOperationId(value.operationId),
    adminUid,
    action,
    targetId: requireTargetId(value[targetKey]),
    reason: requireReason(value.reason),
  };
}

function toResult(operation: DeletionOperation): DeletionResult {
  if (operation.status !== 'succeeded' || operation.completedAt === undefined) {
    throw new Error('Operação concluída sem resultado persistido.');
  }
  return { targetId: operation.targetId, completedAt: operation.completedAt.toISOString() };
}

function throwStoredFailure(operation: DeletionOperation): never {
  const details = { operationStatus: 'failed' };
  switch (operation.failureCode ?? 'internal') {
    case 'not-found':
      throw new HttpsError('not-found', 'O item a excluir não foi encontrado.', details);
    case 'permission-denied':
      throw new HttpsError('permission-denied', 'O item não pode ser excluído pelo painel.', details);
    default:
      throw new HttpsError('internal', 'Não foi possível concluir a exclusão.', details);
  }
}

function pendingError(): HttpsError {
  // Parte da exclusão pode ter acontecido. Cada passo é idempotente, então
  // a operação fica pending e a repetição com o mesmo operationId termina.
  return new HttpsError('internal', 'Não foi possível concluir a exclusão.', { operationStatus: 'pending' });
}

/**
 * Registra a operação, executa a exclusão e grava o desfecho. [execute]
 * recebe `isNew` para distinguir "não existe" (recusa) de "a tentativa
 * anterior já apagou" (repetição de uma operação pending).
 */
export async function runDeletionOperation(
  operations: DeletionOperationsGateway,
  input: DeletionOperationInput,
  execute: (context: { readonly isNew: boolean }) => Promise<void>,
): Promise<DeletionResult> {
  let claimed;
  try {
    claimed = await operations.claim(input);
  } catch (error) {
    if (error instanceof DeletionOperationConflictError) {
      throw new HttpsError('already-exists', 'operationId já está associado a outra operação.');
    }
    throw new HttpsError(
      'internal',
      'Não foi possível registrar a operação administrativa.',
      { operationStatus: 'pending' },
    );
  }

  const { operation } = claimed;
  if (operation.status === 'succeeded') return toResult(operation);
  if (operation.status === 'failed') return throwStoredFailure(operation);

  try {
    await execute({ isNew: claimed.created });
  } catch (error) {
    if (!(error instanceof DeletionRefusal)) throw pendingError();
    try {
      return throwStoredFailure(await operations.fail(operation.operationId, error.code));
    } catch (failure) {
      if (failure instanceof HttpsError) throw failure;
      throw pendingError();
    }
  }

  try {
    return toResult(await operations.succeed(operation.operationId));
  } catch {
    throw pendingError();
  }
}

/** Apaga os documentos em lotes; apagar um documento que não existe não falha. */
export async function deleteDocuments(firestore: Firestore, references: readonly DocumentReference[]): Promise<void> {
  for (let start = 0; start < references.length; start += batchLimit) {
    const batch = firestore.batch();
    for (const reference of references.slice(start, start + batchLimit)) batch.delete(reference);
    await batch.commit();
  }
}

function parseStoredOperation(operationId: string, data: FirebaseFirestore.DocumentData): DeletionOperation {
  const { status } = data;
  if (
    typeof data.adminUid !== 'string'
    || (data.action !== 'deleteEvent' && data.action !== 'deleteUserAccount')
    || typeof data.targetId !== 'string'
    || typeof data.reason !== 'string'
    || (status !== 'pending' && status !== 'succeeded' && status !== 'failed')
  ) {
    throw new Error('Registro administrativo persistido possui formato inválido.');
  }
  return {
    operationId,
    adminUid: data.adminUid,
    action: data.action,
    targetId: data.targetId,
    reason: data.reason,
    status,
    ...(typeof data.failureCode === 'string' && failureCodes.has(data.failureCode)
      ? { failureCode: data.failureCode as DeletionFailureCode }
      : {}),
    ...(data.completedAt instanceof Timestamp ? { completedAt: data.completedAt.toDate() } : {}),
  };
}

export function createFirestoreDeletionOperationsGateway(): DeletionOperationsGateway {
  const firestore = getFirestore();
  const collection = firestore.collection('adminOperations');

  /** Fecha a operação pending com [fields]; uma operação já fechada não muda. */
  const finish = async (operationId: string, fields: Record<string, unknown>) => {
    const reference = collection.doc(operationId);
    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) throw new Error('Registro administrativo não encontrado.');
      if (parseStoredOperation(operationId, snapshot.data() ?? {}).status !== 'pending') return;
      transaction.update(reference, { ...fields, completedAt: FieldValue.serverTimestamp() });
    });
    return parseStoredOperation(operationId, (await reference.get()).data() ?? {});
  };

  return {
    claim: async (input) => firestore.runTransaction(async (transaction) => {
      const reference = collection.doc(input.operationId);
      const snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        transaction.create(reference, {
          adminUid: input.adminUid,
          action: input.action,
          targetId: input.targetId,
          reason: input.reason,
          status: 'pending',
          createdAt: FieldValue.serverTimestamp(),
        });
        return { created: true, operation: { ...input, status: 'pending' as const } };
      }

      const operation = parseStoredOperation(input.operationId, snapshot.data() ?? {});
      if (
        operation.adminUid !== input.adminUid
        || operation.action !== input.action
        || operation.targetId !== input.targetId
        || operation.reason !== input.reason
      ) {
        throw new DeletionOperationConflictError();
      }
      return { created: false, operation };
    }),
    succeed: async (operationId) => finish(operationId, { status: 'succeeded' }),
    fail: async (operationId, failureCode) => finish(operationId, { status: 'failed', failureCode }),
  };
}
