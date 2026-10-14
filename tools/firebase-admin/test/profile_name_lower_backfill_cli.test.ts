import assert from 'node:assert/strict';
import test from 'node:test';

import { BootstrapValidationError } from '../src/bootstrap_admin.js';
import { parseProfileBackfillArguments } from '../src/cli/backfill-profile-name-lower.js';

test('CLI do backfill aceita somente dry-run opcional', () => {
  assert.deepEqual(parseProfileBackfillArguments([]), { dryRun: false });
  assert.deepEqual(parseProfileBackfillArguments(['--dry-run']), { dryRun: true });
  assert.throws(
    () => parseProfileBackfillArguments(['--uid', 'uid']),
    BootstrapValidationError,
  );
});
