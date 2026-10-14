import type { BootstrapAuthGateway, BootstrapUserRecord } from './trusted_admin_sdk.js';

const maxUidLength = 128;

export type BootstrapOutcome = 'would-grant' | 'granted' | 'already-admin';

export interface BootstrapAdministratorInput {
  readonly uid: string;
  readonly dryRun: boolean;
}

export interface BootstrapAdministratorResult {
  readonly outcome: BootstrapOutcome;
  readonly changed: boolean;
}

export class BootstrapValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BootstrapValidationError';
  }
}

/**
 * Concede a única claim administrativa aprovada. A lógica é independente do
 * CLI para poder ser testada com um gateway fake e sem qualquer credencial.
 */
export async function bootstrapAdministrator(
  gateway: BootstrapAuthGateway,
  input: BootstrapAdministratorInput,
): Promise<BootstrapAdministratorResult> {
  const uid = validateUid(input.uid);
  const user = await gateway.getUser(uid);
  validateEligibleAccount(user);

  if (user.customClaims?.admin === true) {
    return { outcome: 'already-admin', changed: false };
  }

  if (input.dryRun) {
    return { outcome: 'would-grant', changed: false };
  }

  await gateway.setCustomUserClaims(uid, {
    ...user.customClaims,
    admin: true,
  });
  return { outcome: 'granted', changed: true };
}

function validateUid(value: string): string {
  const uid = value.trim();
  if (uid.length === 0 || uid.length > maxUidLength) {
    throw new BootstrapValidationError('UID inválido para bootstrap administrativo.');
  }
  return uid;
}

function validateEligibleAccount(user: BootstrapUserRecord): void {
  if (user.disabled) {
    throw new BootstrapValidationError('A conta informada está desabilitada.');
  }
  if (user.email === undefined || user.email.trim().length === 0) {
    throw new BootstrapValidationError('A conta informada não possui e-mail.');
  }
  if (!user.emailVerified) {
    throw new BootstrapValidationError('O e-mail da conta precisa estar verificado.');
  }
  if (!user.providerData.some((provider) => provider.providerId === 'password')) {
    throw new BootstrapValidationError(
      'A conta informada precisa usar o provedor e-mail/senha.',
    );
  }
}
