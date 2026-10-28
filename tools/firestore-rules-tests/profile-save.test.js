import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { it } from 'node:test';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { initializeApp, deleteApp } from 'firebase/app';
import {
  getAuth, connectAuthEmulator, createUserWithEmailAndPassword, updateProfile,
  signInAnonymously,
} from 'firebase/auth';
import {
  getFirestore, connectFirestoreEmulator, doc, setDoc, getDocFromServer,
  serverTimestamp, terminate,
} from 'firebase/firestore';

// Nunca usa credenciais, documentos ou endpoints de produção.
it('reproduz a regra publicada e valida nome/bio com Auth e Firestore locais', async () => {
  const projectId = 'demo-compy';
  const loadRules = (path) => initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1', port: 8080,
      rules: readFileSync(new URL(path, import.meta.url), 'utf8'),
    },
  });
  const oldEnv = await loadRules('./fixtures/users-before-bio.rules');
  const apps = [];
  const databases = [];
  let currentEnv;
  const client = (name) => {
    const app = initializeApp({ projectId, apiKey: 'demo-key' }, name);
    apps.push(app);
    const auth = getAuth(app);
    connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
    const db = getFirestore(app);
    connectFirestoreEmulator(db, '127.0.0.1', 8080);
    databases.push(db);
    return { auth, db };
  };
  try {
    await oldEnv.clearFirestore();
    const owner = client('profile-owner');
    const { user } = await createUserWithEmailAndPassword(
      owner.auth, `profile-${Date.now()}@example.test`, 'test-password-only',
    );
    await updateProfile(user, { displayName: 'João' });
    const target = doc(owner.db, 'users', user.uid);
    await setDoc(target, {
      id: user.uid, name: 'João', nameLower: 'joao', handle: '@joao',
      avatarUrl: 'https://example.test/avatar.jpg', favoriteSports: ['volei'],
      createdAt: serverTimestamp(),
    });
    // O mesmo payload usado pelo datasource, inclusive quando só o nome muda.
    for (const bio of ['Jogo vôlei', '']) {
      await assert.rejects(
        setDoc(target, { name: 'João Silva', nameLower: 'joao silva', bio }, { merge: true }),
        (error) => {
          assert.equal(error.name, 'FirebaseError');
          assert.equal(error.code, 'permission-denied');
          console.log(`Regra publicada: FirebaseError code=${error.code}; bio ${bio ? 'preenchida' : 'vazia'}`);
          return true;
        },
      );
    }
    assert.equal((await getDocFromServer(target)).data().bio, undefined);
    assert.equal(user.displayName, 'João');

    currentEnv = await loadRules('../../firestore.rules');
    const observer = client('profile-observer');
    await signInAnonymously(observer.auth);
    for (const [name, nameLower, bio] of [
      ['João', 'joao', 'Somente bio'],
      ['João Silva', 'joao silva', 'Somente bio'],
      ['João Souza', 'joao souza', 'Nome e bio'],
      ['João Souza', 'joao souza', ''],
      ['a'.repeat(60), 'a'.repeat(60), 'b'.repeat(160)],
    ]) {
      await setDoc(target, { name, nameLower, bio }, { merge: true });
      if (user.displayName !== name) await updateProfile(user, { displayName: name });
      await user.reload();
      assert.equal(user.displayName, name);
      const data = (await getDocFromServer(doc(observer.db, 'users', user.uid))).data();
      assert.equal(data.name, name);
      assert.equal(data.nameLower, nameLower);
      assert.equal(data.bio, bio);
      assert.equal(data.handle, '@joao');
      assert.equal(data.avatarUrl, 'https://example.test/avatar.jpg');
      assert.deepEqual(data.favoriteSports, ['volei']);
    }
    await assert.rejects(setDoc(doc(observer.db, 'users', user.uid), {
      bio: 'Tentativa de terceiro',
    }, { merge: true }), { code: 'permission-denied' });
  } finally {
    await Promise.all(databases.map(terminate));
    await Promise.all(apps.map(deleteApp));
    await currentEnv?.cleanup();
    await oldEnv.cleanup();
  }
});
