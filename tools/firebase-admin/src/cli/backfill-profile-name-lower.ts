import {
  backfillProfileNameLower,
  createFirestoreProfileNameLowerBackfillGateway,
} from '../profiles/profile_name_lower_backfill.js';
import { BootstrapValidationError } from '../bootstrap_admin.js';
import { createTrustedAdminSdk, TrustedCredentialError } from '../trusted_admin_sdk.js';

export function parseProfileBackfillArguments(args: readonly string[]): { readonly dryRun: boolean } {
  if (args.length === 0) return { dryRun: false };
  if (args.length === 1 && args[0] === '--dry-run') return { dryRun: true };
  throw new BootstrapValidationError('Use somente --dry-run opcional para o backfill de perfis.');
}

export async function runProfileNameLowerBackfillCli(
  args: readonly string[],
  writeLine: (message: string) => void = console.log,
): Promise<void> {
  const { dryRun } = parseProfileBackfillArguments(args);
  const sdk = await createTrustedAdminSdk();
  const result = await backfillProfileNameLower(
    createFirestoreProfileNameLowerBackfillGateway(sdk.firestore),
    { dryRun },
  );

  writeLine(
    `${dryRun ? 'Dry-run' : 'Backfill'} concluído: ${result.updated} perfil(is) `
      + `${dryRun ? 'seriam atualizados' : 'atualizado(s)'}; ${result.unchanged} já normalizado(s).`,
  );
  if (result.invalidProfileIds.length > 0) {
    writeLine(`Perfis sem nome válido (corrija manualmente): ${result.invalidProfileIds.join(', ')}.`);
  }
}

if (process.argv[1]?.endsWith('backfill-profile-name-lower.js')) {
  runProfileNameLowerBackfillCli(process.argv.slice(2)).catch((error: unknown) => {
    if (error instanceof TrustedCredentialError || error instanceof BootstrapValidationError) {
      console.error(error.message);
    } else {
      console.error('Falha segura ao executar o backfill de nameLower dos perfis.');
    }
    process.exitCode = 1;
  });
}
