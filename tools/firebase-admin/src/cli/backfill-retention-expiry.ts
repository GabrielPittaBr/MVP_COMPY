import { BootstrapValidationError } from '../bootstrap_admin.js';
import {
  backfillRetentionExpiry,
  createFirestoreRetentionBackfillGateway,
} from '../retention/retention_backfill.js';
import { createTrustedAdminSdk, TrustedCredentialError } from '../trusted_admin_sdk.js';

export function parseRetentionBackfillArguments(args: readonly string[]): { readonly dryRun: boolean } {
  if (args.length === 0) return { dryRun: false };
  if (args.length === 1 && args[0] === '--dry-run') return { dryRun: true };
  throw new BootstrapValidationError('Use somente --dry-run opcional para o backfill de retenção.');
}

export async function runRetentionBackfillCli(
  args: readonly string[],
  writeLine: (message: string) => void = console.log,
): Promise<void> {
  const { dryRun } = parseRetentionBackfillArguments(args);
  const sdk = await createTrustedAdminSdk();
  const result = await backfillRetentionExpiry(createFirestoreRetentionBackfillGateway(sdk.firestore), { dryRun });
  const verb = dryRun ? 'receberiam' : 'receberam';
  writeLine(
    `${dryRun ? 'Dry-run' : 'Backfill'} concluído: ${result.notificationsUpdated} notificação(ões) e `
      + `${result.operationsUpdated} registro(s) de moderação ${verb} expiresAt; `
      + `${result.unchanged} já tinham o prazo.`,
  );
}

if (process.argv[1]?.endsWith('backfill-retention-expiry.js')) {
  runRetentionBackfillCli(process.argv.slice(2)).catch((error: unknown) => {
    if (error instanceof TrustedCredentialError || error instanceof BootstrapValidationError) {
      console.error(error.message);
    } else {
      console.error('Falha segura ao executar o backfill dos prazos de retenção.');
    }
    process.exitCode = 1;
  });
}
