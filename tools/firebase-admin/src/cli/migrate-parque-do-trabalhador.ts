import {
  createFirestorePlaceMigrationGateway,
  migrateParqueDoTrabalhador,
  PlaceMigrationConflictError,
} from '../places/migrate_parque_do_trabalhador.js';
import { createTrustedAdminSdk, TrustedCredentialError } from '../trusted_admin_sdk.js';
import { BootstrapValidationError } from '../bootstrap_admin.js';

export function parseMigrationArguments(args: readonly string[]): { readonly dryRun: boolean } {
  if (args.length === 0) return { dryRun: false };
  if (args.length === 1 && args[0] === '--dry-run') return { dryRun: true };
  throw new BootstrapValidationError('Use somente --dry-run opcional para a migração.');
}

export async function runPlaceMigrationCli(
  args: readonly string[],
  writeLine: (message: string) => void = console.log,
): Promise<void> {
  const { dryRun } = parseMigrationArguments(args);
  const sdk = await createTrustedAdminSdk();
  const result = await migrateParqueDoTrabalhador(
    createFirestorePlaceMigrationGateway(sdk.firestore),
    { dryRun },
  );

  if (result.outcome === 'would-create') {
    writeLine('Dry-run concluído: o Local Esportivo seria criado.');
  } else if (result.outcome === 'created') {
    writeLine('Migração concluída: o Local Esportivo foi criado e verificado.');
  } else {
    writeLine('Migração concluída: o Local Esportivo já era equivalente e foi verificado.');
  }
}

if (process.argv[1]?.endsWith('migrate-parque-do-trabalhador.js')) {
  runPlaceMigrationCli(process.argv.slice(2)).catch((error: unknown) => {
    if (
      error instanceof TrustedCredentialError
      || error instanceof BootstrapValidationError
      || error instanceof PlaceMigrationConflictError
    ) {
      console.error(error.message);
    } else {
      console.error('Falha segura ao executar a migração do Local Esportivo.');
    }
    process.exitCode = 1;
  });
}
