import assert from 'node:assert/strict';
import test from 'node:test';

import { BootstrapValidationError } from '../src/bootstrap_admin.js';
import { parseMigrationArguments } from '../src/cli/migrate-parque-do-trabalhador.js';

test('CLI de migração aceita dry-run opcional', () => {
  assert.deepEqual(parseMigrationArguments([]), { dryRun: false });
  assert.deepEqual(parseMigrationArguments(['--dry-run']), { dryRun: true });
});

test('CLI de migração recusa argumentos fora do contrato', () => {
  assert.throws(
    () => parseMigrationArguments(['--uid', 'uid-admin']),
    BootstrapValidationError,
  );
});
