import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  avatarMillis,
  createAvatarCleanupHandler,
  staleAvatarPaths,
  storagePathFromUrl,
  type AvatarStorageGateway,
} from '../src/avatar_cleanup.js';

const uid = 'ana';
const url = (millis: number) =>
  `https://firebasestorage.googleapis.com/v0/b/compy-tcc.firebasestorage.app/o/users%2F${uid}%2Favatar_${millis}.jpg?alt=media&token=abc`;
const path = (millis: number) => `users/${uid}/avatar_${millis}.jpg`;

describe('caminhos das fotos', () => {
  it('lê o caminho do bucket na URL de download, inclusive do emulador', () => {
    assert.equal(storagePathFromUrl(url(10)), path(10));
    assert.equal(storagePathFromUrl(`http://localhost:9199/v0/b/demo/o/users%2F${uid}%2Favatar_5.jpg?alt=media`), path(5));
    assert.equal(storagePathFromUrl('https://lh3.googleusercontent.com/a/foto=s400-c'), null);
    assert.equal(storagePathFromUrl(undefined), null);
  });

  it('lê os milissegundos do nome do arquivo', () => {
    assert.equal(avatarMillis(path(1731600000000)), 1731600000000);
    assert.equal(avatarMillis(`users/${uid}/outro.png`), null);
  });
});

describe('staleAvatarPaths', () => {
  const files = [path(10), path(20), path(30)];

  it('apaga só as fotos anteriores à atual', () => {
    assert.deepEqual(staleAvatarPaths(uid, url(10), url(20), files, 25), [path(10)]);
  });

  it('não apaga a foto que subiu depois da atual (duas trocas seguidas)', () => {
    assert.deepEqual(staleAvatarPaths(uid, url(20), url(20), files, 40), []);
    assert.ok(!staleAvatarPaths(uid, url(10), url(20), files, 40).includes(path(30)));
  });

  it('foto do Google ou inicial: apaga as do bucket anteriores à troca', () => {
    assert.deepEqual(
      staleAvatarPaths(uid, url(30), 'https://placehold.co/100x100/png?text=A', files, 25),
      [path(10), path(20)],
    );
  });

  it('nunca toca arquivos de outra pessoa', () => {
    assert.deepEqual(staleAvatarPaths(uid, url(10), url(20), ['users/beto/avatar_1.jpg'], 25), []);
  });
});

describe('createAvatarCleanupHandler', () => {
  const gateway = (paths: string[]) => {
    const removed: string[] = [];
    const api: AvatarStorageGateway = {
      list: async () => paths,
      remove: async (stale) => { removed.push(...stale); },
    };
    return { api, removed };
  };

  it('remove as fotos antigas quando avatarUrl muda', async () => {
    const { api, removed } = gateway([path(10), path(20)]);
    const count = await createAvatarCleanupHandler(api)(uid, { avatarUrl: url(10) }, { avatarUrl: url(20) }, 25);
    assert.equal(count, 1);
    assert.deepEqual(removed, [path(10)]);
  });

  it('outras edições do perfil não listam o bucket', async () => {
    let listed = false;
    const api: AvatarStorageGateway = {
      list: async () => { listed = true; return []; },
      remove: async () => {},
    };
    await createAvatarCleanupHandler(api)(uid, { avatarUrl: url(10), bio: 'a' }, { avatarUrl: url(10), bio: 'b' }, 25);
    assert.equal(listed, false);
  });
});
