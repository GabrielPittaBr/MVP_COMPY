import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bootstrapAdministrator,
  BootstrapValidationError,
} from '../src/bootstrap_admin.js';
import type {
  BootstrapAuthGateway,
  BootstrapUserRecord,
} from '../src/trusted_admin_sdk.js';

const validUser = (overrides: Partial<BootstrapUserRecord> = {}): BootstrapUserRecord => ({
  uid: 'uid-verified-password-user',
  email: 'admin@compy.test',
  emailVerified: true,
  disabled: false,
  providerData: [{ providerId: 'password' }],
  customClaims: { existingClaim: 'preserved' },
  ...overrides,
});

function fakeGateway(user: BootstrapUserRecord): BootstrapAuthGateway & {
  readonly writes: Array<{ uid: string; claims: Record<string, unknown> }>;
} {
  const writes: Array<{ uid: string; claims: Record<string, unknown> }> = [];
  return {
    writes,
    getUser: async () => user,
    setCustomUserClaims: async (uid, claims) => {
      writes.push({ uid, claims });
    },
  };
}

test('dry-run válido não grava a claim', async () => {
  const gateway = fakeGateway(validUser());

  const result = await bootstrapAdministrator(gateway, {
    uid: 'uid-verified-password-user',
    dryRun: true,
  });

  assert.deepEqual(result, { outcome: 'would-grant', changed: false });
  assert.equal(gateway.writes.length, 0);
});

test('bootstrap preserva claims existentes e concede somente admin', async () => {
  const gateway = fakeGateway(validUser());

  const result = await bootstrapAdministrator(gateway, {
    uid: 'uid-verified-password-user',
    dryRun: false,
  });

  assert.deepEqual(result, { outcome: 'granted', changed: true });
  assert.deepEqual(gateway.writes, [
    {
      uid: 'uid-verified-password-user',
      claims: { existingClaim: 'preserved', admin: true },
    },
  ]);
});

test('claim administrativa existente é no-op idempotente', async () => {
  const gateway = fakeGateway(validUser({ customClaims: { admin: true, keep: 1 } }));

  const result = await bootstrapAdministrator(gateway, {
    uid: 'uid-verified-password-user',
    dryRun: false,
  });

  assert.deepEqual(result, { outcome: 'already-admin', changed: false });
  assert.equal(gateway.writes.length, 0);
});

for (const [name, user] of [
  ['conta desabilitada', validUser({ disabled: true })],
  ['conta sem e-mail', validUser({ email: undefined })],
  ['e-mail não verificado', validUser({ emailVerified: false })],
  ['provedor incompatível', validUser({ providerData: [{ providerId: 'google.com' }] })],
] as const) {
  test(`bootstrap recusa ${name}`, async () => {
    await assert.rejects(
      bootstrapAdministrator(fakeGateway(user), {
        uid: 'uid-verified-password-user',
        dryRun: false,
      }),
      BootstrapValidationError,
    );
  });
}

test('bootstrap recusa UID ausente sem chamar o gateway', async () => {
  const gateway = fakeGateway(validUser());

  await assert.rejects(
    bootstrapAdministrator(gateway, { uid: '   ', dryRun: false }),
    BootstrapValidationError,
  );
  assert.equal(gateway.writes.length, 0);
});
