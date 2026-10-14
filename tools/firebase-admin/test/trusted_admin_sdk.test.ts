import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createTrustedAdminSdk,
  TrustedCredentialError,
  type TrustedAdminSdk,
} from '../src/trusted_admin_sdk.js';

test('inicialização confiável devolve um SDK fornecido externamente', async () => {
  const fake = {} as TrustedAdminSdk;

  const result = await createTrustedAdminSdk(async () => fake);

  assert.equal(result, fake);
});

test('credencial ausente falha com mensagem segura', async () => {
  await assert.rejects(
    createTrustedAdminSdk(async () => {
      throw new Error('private-key=never-print-this');
    }),
    (error: unknown) => {
      assert.ok(error instanceof TrustedCredentialError);
      assert.doesNotMatch(error.message, /private-key/);
      return true;
    },
  );
});
