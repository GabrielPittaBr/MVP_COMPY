import {
  bootstrapAdministrator,
  BootstrapValidationError,
} from '../bootstrap_admin.js';
import {
  createBootstrapAuthGateway,
  createTrustedAdminSdk,
  TrustedCredentialError,
} from '../trusted_admin_sdk.js';

interface CliArguments {
  readonly uid: string;
  readonly dryRun: boolean;
}

export function parseBootstrapArguments(args: readonly string[]): CliArguments {
  let uid: string | undefined;
  let dryRun = false;

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--uid') {
      if (uid !== undefined || index + 1 >= args.length) {
        throw new BootstrapValidationError('Use exatamente um argumento --uid <UID>.');
      }
      uid = args[index + 1];
      index += 1;
    } else if (argument === '--dry-run') {
      dryRun = true;
    } else {
      throw new BootstrapValidationError('Use somente --uid <UID> e --dry-run opcional.');
    }
  }

  if (uid === undefined) {
    throw new BootstrapValidationError('Use exatamente um argumento --uid <UID>.');
  }

  return { uid, dryRun };
}

export async function runBootstrapCli(
  args: readonly string[],
  writeLine: (message: string) => void = console.log,
): Promise<void> {
  const input = parseBootstrapArguments(args);
  const sdk = await createTrustedAdminSdk();
  const result = await bootstrapAdministrator(createBootstrapAuthGateway(sdk.auth), input);

  switch (result.outcome) {
    case 'would-grant':
      writeLine('Dry-run concluído: a claim administrativa seria concedida.');
      return;
    case 'already-admin':
      writeLine('Bootstrap concluído: a conta já possui a claim administrativa.');
      return;
    case 'granted':
      writeLine('Bootstrap concluído: a claim administrativa foi concedida.');
  }
}

if (process.argv[1]?.endsWith('bootstrap-admin.js')) {
  runBootstrapCli(process.argv.slice(2)).catch((error: unknown) => {
    if (error instanceof TrustedCredentialError || error instanceof BootstrapValidationError) {
      console.error(error.message);
    } else {
      console.error('Falha segura ao executar o bootstrap administrativo.');
    }
    process.exitCode = 1;
  });
}
