import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createDeleteUserAccountHandler,
  type AccountDeletionGateway,
  type DeletableAuthAccount,
} from '../src/user_deletion.js';
import {
  adminRequest,
  assertHttpsError,
  completedAt,
  FakeDeletionOperations,
  operationId,
  reason,
} from './deletion_fakes.js';

const ALVO = 'target-uid';

const entrada = (overrides: Record<string, unknown> = {}) => ({
  uid: ALVO,
  reason,
  operationId,
  ...overrides,
});

/** Auth, Storage e Firestore de mentira; [passos] guarda a ordem das chamadas. */
class ContasFalsas implements AccountDeletionGateway {
  conta: DeletableAuthAccount | null = { uid: ALVO };
  perfil = true;
  readonly passos: string[] = [];
  /** Passo que falha uma vez, para simular interrupção no meio. */
  falharEm: string | null = null;

  async getAccount(): Promise<DeletableAuthAccount | null> {
    return this.conta;
  }

  async hasProfile(): Promise<boolean> {
    return this.perfil;
  }

  async disable(uid: string): Promise<void> {
    this.passo(`disable:${uid}`);
  }

  async deletePhotos(uid: string): Promise<void> {
    this.passo(`photos:${uid}`);
  }

  async deleteProfileData(uid: string): Promise<void> {
    this.passo(`profile:${uid}`);
    this.perfil = false;
  }

  async deleteAccount(uid: string): Promise<void> {
    this.passo(`account:${uid}`);
    this.conta = null;
  }

  private passo(nome: string): void {
    if (this.falharEm !== null && nome.startsWith(this.falharEm)) {
      this.falharEm = null;
      throw new Error(`falha em ${nome}`);
    }
    this.passos.push(nome);
  }
}

test('desabilita a conta, apaga fotos e dados e só então apaga a conta do Auth', async () => {
  const contas = new ContasFalsas();
  const operacoes = new FakeDeletionOperations();

  const resultado = await createDeleteUserAccountHandler(contas, operacoes)(adminRequest(entrada()));

  assert.deepEqual(resultado, { uid: ALVO, completedAt: completedAt.toISOString() });
  assert.deepEqual(contas.passos, [`disable:${ALVO}`, `photos:${ALVO}`, `profile:${ALVO}`, `account:${ALVO}`]);
  const registro = operacoes.operations.get(operationId);
  assert.equal(registro?.action, 'deleteUserAccount');
  assert.equal(registro?.targetId, ALVO);
  assert.equal(registro?.reason, reason);
  assert.equal(registro?.status, 'succeeded');
});

test('rejeita autenticação, payload, autoexclusão e exclusão de outro Administrador', async () => {
  const contas = new ContasFalsas();
  contas.conta = { uid: ALVO, customClaims: { admin: true } };
  const operacoes = new FakeDeletionOperations();
  const handler = createDeleteUserAccountHandler(contas, operacoes);

  await assertHttpsError(handler({ data: entrada() }), 'unauthenticated');
  await assertHttpsError(handler(adminRequest(entrada({ eventId: 'x' }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(entrada({ reason: 'curto' }))), 'invalid-argument');
  await assertHttpsError(handler(adminRequest(entrada({ uid: 'admin-uid' }))), 'failed-precondition');
  await assertHttpsError(handler(adminRequest(entrada())), 'permission-denied', { operationStatus: 'failed' });
  assert.equal(operacoes.operations.get(operationId)?.failureCode, 'permission-denied');
  assert.deepEqual(contas.passos, []);
});

test('perfil órfão, sem conta no Auth, é excluído sem tocar o Auth', async () => {
  const contas = new ContasFalsas();
  contas.conta = null;

  await createDeleteUserAccountHandler(contas, new FakeDeletionOperations())(adminRequest(entrada()));

  assert.deepEqual(contas.passos, [`photos:${ALVO}`, `profile:${ALVO}`]);
});

test('sem conta e sem perfil não há o que excluir', async () => {
  const contas = new ContasFalsas();
  contas.conta = null;
  contas.perfil = false;
  const handler = createDeleteUserAccountHandler(contas, new FakeDeletionOperations());

  await assertHttpsError(handler(adminRequest(entrada())), 'not-found', { operationStatus: 'failed' });
  await assertHttpsError(handler(adminRequest(entrada())), 'not-found', { operationStatus: 'failed' });
  assert.deepEqual(contas.passos, []);
});

test('falha no meio deixa a conta desabilitada e pending; a repetição termina', async () => {
  const contas = new ContasFalsas();
  contas.falharEm = 'profile';
  const operacoes = new FakeDeletionOperations();
  const handler = createDeleteUserAccountHandler(contas, operacoes);

  await assertHttpsError(handler(adminRequest(entrada())), 'internal', { operationStatus: 'pending' });
  assert.equal(operacoes.operations.get(operationId)?.status, 'pending');
  assert.deepEqual(contas.passos, [`disable:${ALVO}`, `photos:${ALVO}`]);
  assert.notEqual(contas.conta, null);

  await handler(adminRequest(entrada()));
  assert.equal(operacoes.operations.get(operationId)?.status, 'succeeded');
  assert.equal(contas.conta, null);
  assert.equal(contas.perfil, false);
});

test('pending com conta e perfil já apagados conclui em vez de acusar ausência', async () => {
  const contas = new ContasFalsas();
  contas.conta = null;
  contas.perfil = false;
  const operacoes = new FakeDeletionOperations();
  operacoes.seed({
    operationId,
    adminUid: 'admin-uid',
    action: 'deleteUserAccount',
    targetId: ALVO,
    reason,
    status: 'pending',
  });

  const resultado = await createDeleteUserAccountHandler(contas, operacoes)(adminRequest(entrada()));

  assert.equal(resultado.uid, ALVO);
  // Fotos e reserva de username são procuradas de novo: podem ter sobrado.
  assert.deepEqual(contas.passos, [`photos:${ALVO}`, `profile:${ALVO}`]);
});

test('um operationId de exclusão de evento não serve para excluir conta', async () => {
  const operacoes = new FakeDeletionOperations();
  operacoes.seed({
    operationId,
    adminUid: 'admin-uid',
    action: 'deleteEvent',
    targetId: ALVO,
    reason,
    status: 'succeeded',
    completedAt,
  });
  const contas = new ContasFalsas();

  await assertHttpsError(
    createDeleteUserAccountHandler(contas, operacoes)(adminRequest(entrada())),
    'already-exists',
  );
  assert.deepEqual(contas.passos, []);
});
