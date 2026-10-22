import assert from 'node:assert/strict';
import test from 'node:test';

import { BootstrapValidationError } from '../src/bootstrap_admin.js';
import { parseBootstrapArguments } from '../src/cli/bootstrap-admin.js';

test('CLI aceita um UID e dry-run', () => {
  assert.deepEqual(parseBootstrapArguments(['--uid', 'abc', '--dry-run']), {
    uid: 'abc',
    dryRun: true,
  });
});

for (const args of [
  [],
  ['--uid'],
  ['--uid', 'a', '--uid', 'b'],
  ['--email', 'admin@compy.test'],
]) {
  test(`CLI rejeita argumentos inválidos: ${args.join(' ') || '(vazio)'}`, () => {
    assert.throws(() => parseBootstrapArguments(args), BootstrapValidationError);
  });
}
