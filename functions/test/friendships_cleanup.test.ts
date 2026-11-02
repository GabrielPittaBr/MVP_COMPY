import assert from 'node:assert/strict';
import { it } from 'node:test';
import { createFriendshipsCleanupHandler, type FriendshipsCleanupGateway } from '../src/friendships_cleanup.js';

function gateway(count: number) {
  const records = new Set(Array.from({length: count}, (_, i) => `pair-${i}`));
  const batches: number[] = [];
  const api: FriendshipsCleanupGateway = {
    profileExists: async () => false,
    list: async (uid, limit) => {
      assert.equal(uid, 'removed-user');
      assert.equal(limit, 200);
      return [...records].slice(0, limit);
    },
    remove: async (ids) => { batches.push(ids.length); ids.forEach((id) => records.delete(id)); },
  };
  return {api, records, batches};
}

it('limpa solicitações e amizades em lotes; repetir não modifica outros dados', async () => {
  const {api, records, batches} = gateway(403);
  const clean = createFriendshipsCleanupHandler(api);
  assert.equal(await clean('removed-user'), 403);
  assert.equal(records.size, 0);
  assert.deepEqual(batches, [200, 200, 3]);
  assert.equal(await clean('removed-user'), 0);
});
it('preserva o UID cujo perfil foi recriado antes do gatilho', async () => {
  const {api, records} = gateway(2);
  api.profileExists = async () => true;
  assert.equal(await createFriendshipsCleanupHandler(api)('removed-user'), 0);
  assert.equal(records.size, 2);
});
it('propaga falha para retry; nova execução completa o que falta', async () => {
  const {api, records} = gateway(201);
  const remove = api.remove;
  let calls = 0;
  api.remove = async (ids) => { if (++calls === 2) throw new Error('unavailable'); await remove(ids); };
  const clean = createFriendshipsCleanupHandler(api);
  await assert.rejects(clean('removed-user'), /unavailable/);
  assert.equal(records.size, 1);
  assert.equal(await clean('removed-user'), 1);
});
