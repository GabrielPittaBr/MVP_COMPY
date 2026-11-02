/**
 * Regras do Cloud Storage (`storage.rules`): fotos de perfil em
 * `users/{uid}/avatar_<millis>.jpg`, espelhando `AvatarStorage` do app.
 */
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteObject,
  getMetadata,
  listAll,
  ref,
  uploadBytes,
} from 'firebase/storage';

const UID = 'uid_gabriel';
const OUTRO = 'uid_outro';
const FOTO = `users/${UID}/avatar_1761100000000.jpg`;
const JPEG = { contentType: 'image/jpeg' };

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-compy',
    storage: {
      rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

const as = (uid) => testEnv.authenticatedContext(uid).storage();
const anonimo = () => testEnv.unauthenticatedContext().storage();

/** Bytes quaisquer: a regra olha tamanho e contentType, não o conteúdo. */
const bytes = (size = 64 * 1024) => new Uint8Array(size);

async function seedFoto(path = FOTO) {
  await testEnv.withSecurityRulesDisabled((ctx) =>
    uploadBytes(ref(ctx.storage(), path), bytes(), JPEG),
  );
}

describe('envio da foto de perfil', () => {
  it('dono envia JPEG pequeno na própria pasta', async () => {
    await assertSucceeds(uploadBytes(ref(as(UID), FOTO), bytes(), JPEG));
  });

  it('outro usuário não envia na pasta alheia', async () => {
    await assertFails(uploadBytes(ref(as(OUTRO), FOTO), bytes(), JPEG));
  });

  it('anônimo não envia', async () => {
    await assertFails(uploadBytes(ref(anonimo(), FOTO), bytes(), JPEG));
  });

  it('arquivo de 1 MB ou mais é recusado', async () => {
    await assertFails(uploadBytes(ref(as(UID), FOTO), bytes(1024 * 1024), JPEG));
  });

  it('só image/jpeg passa: PNG e texto são recusados', async () => {
    await assertFails(
      uploadBytes(ref(as(UID), FOTO), bytes(), { contentType: 'image/png' }),
    );
    await assertFails(
      uploadBytes(ref(as(UID), FOTO), bytes(), { contentType: 'text/plain' }),
    );
  });

  it('nome fora do padrão avatar_<millis>.jpg é recusado', async () => {
    await assertFails(
      uploadBytes(ref(as(UID), `users/${UID}/foto.jpg`), bytes(), JPEG),
    );
    await assertFails(
      uploadBytes(ref(as(UID), `users/${UID}/avatar_1.jpg.exe`), bytes(), JPEG),
    );
  });

  it('não sobrescreve um arquivo existente (cada troca cria um nome novo)', async () => {
    await seedFoto();
    await assertFails(uploadBytes(ref(as(UID), FOTO), bytes(), JPEG));
  });
});

describe('leitura, listagem e exclusão', () => {
  it('qualquer autenticado lê a foto', async () => {
    await seedFoto();
    await assertSucceeds(getMetadata(ref(as(OUTRO), FOTO)));
  });

  it('anônimo não lê', async () => {
    await seedFoto();
    await assertFails(getMetadata(ref(anonimo(), FOTO)));
  });

  it('dono lista e apaga a própria pasta (exclusão de conta)', async () => {
    await seedFoto();
    await assertSucceeds(listAll(ref(as(UID), `users/${UID}`)));
    await assertSucceeds(deleteObject(ref(as(UID), FOTO)));
  });

  it('outro usuário não lista nem apaga', async () => {
    await seedFoto();
    await assertFails(listAll(ref(as(OUTRO), `users/${UID}`)));
    await assertFails(deleteObject(ref(as(OUTRO), FOTO)));
  });
});
