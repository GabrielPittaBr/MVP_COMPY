/**
 * Regras de `users` e `usernames`, replicando exatamente o que
 * `AuthRemoteDataSource` faz no login com Google.
 *
 * Estas regras foram publicadas junto com as de conversations/messages e
 * nunca tinham sido exercitadas.
 */
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  writeBatch,
} from 'firebase/firestore';

const UID = 'uid_gabriel';
const USERNAME = 'gabriel';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-compy',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anonimo = () => testEnv.unauthenticatedContext().firestore();

/** Espelha `_writeUserProfile`: batch de users/{uid} (merge) + usernames/{name}. */
function writeUserProfile(db, { uid, username, name = 'Gabriel Pitta', email = 'g@example.com' }) {
  const batch = writeBatch(db);
  batch.set(
    doc(db, 'users', uid),
    {
      id: uid,
      name,
      handle: `@${username}`,
      avatarUrl: 'https://ui-avatars.com/api/?name=Gabriel',
      email,
      createdAt: serverTimestamp(),
    },
    { merge: true },
  );
  batch.set(doc(db, 'usernames', username), { uid });
  return batch.commit();
}

describe('login com Google — primeiro acesso', () => {
  it('_userHasProfile lê users/{uid} que ainda não existe', async () => {
    await assertSucceeds(getDoc(doc(as(UID), 'users', UID)));
  });

  it('isUsernameAvailable lê usernames/{name} — inclusive deslogado', async () => {
    await assertSucceeds(getDoc(doc(anonimo(), 'usernames', USERNAME)));
  });

  it('setUsername grava o perfil e o indice de unicidade', async () => {
    await assertSucceeds(
      writeUserProfile(as(UID), { uid: UID, username: USERNAME }),
    );
  });
});

describe('login com Google — usuario que ja tem perfil', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', UID), {
        id: UID,
        name: 'Gabriel Pitta',
        handle: `@${USERNAME}`,
        avatarUrl: 'https://ui-avatars.com/api/?name=Gabriel',
        email: 'g@example.com',
        createdAt: new Date(),
      });
      await setDoc(doc(db, 'usernames', USERNAME), { uid: UID });
    });
  });

  it('_userHasProfile lê o proprio perfil', async () => {
    const snap = await assertSucceeds(getDoc(doc(as(UID), 'users', UID)));
    assertHandle(snap);
  });

  it('regravar o proprio perfil no re-acesso continua permitido', async () => {
    await assertSucceeds(
      writeUserProfile(as(UID), { uid: UID, username: USERNAME }),
    );
  });

  it('perfil alheio e legivel (perfis sao publicos)', async () => {
    await assertSucceeds(getDoc(doc(as('uid_outro'), 'users', UID)));
  });

  it('ninguem escreve no perfil alheio', async () => {
    await assertFails(
      writeUserProfile(as('uid_outro'), { uid: UID, username: USERNAME }),
    );
  });
});

function assertHandle(snap) {
  if (!snap.exists() || !snap.data().handle) {
    throw new Error('perfil sem handle — _userHasProfile devolveria false');
  }
}
