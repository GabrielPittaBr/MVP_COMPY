import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { before, beforeEach, after, it } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, doc, setDoc, getDoc, getDocs, query, where, updateDoc,
  serverTimestamp, deleteDoc, runTransaction, Timestamp } from 'firebase/firestore';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInAnonymously } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, terminate } from 'firebase/firestore';

let env;
const pair = (a, b) => [a, b].sort().join(':');
const db = (uid) => uid ? env.authenticatedContext(uid).firestore() : env.unauthenticatedContext().firestore();
const ref = (database, a = 'a', b = 'b') => doc(database, 'friendships', pair(a, b));
const request = (senderId = 'a', members = ['a', 'b']) => ({
  members, senderId, status: 'pending', requestedAt: serverTimestamp(),
});
const seed = async (data = request()) => setDoc(ref(db('a')), data);
const accept = (database) => updateDoc(ref(database), { status: 'accepted', acceptedAt: serverTimestamp() });
before(async () => {
  env = await initializeTestEnvironment({ projectId: 'demo-compy',
    firestore: { host: '127.0.0.1', port: 8080,
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    for (const uid of ['a', 'b', 'c']) await setDoc(doc(ctx.firestore(), 'users', uid), { id: uid });
  });
});
after(async () => env?.cleanup());

it('A envia, B consulta e aceita; relação simétrica e privada', async () => {
  await assertSucceeds(getDoc(ref(db('a')))); // Par ainda inexistente.
  await assertFails(getDoc(ref(db('c'))));
  await assertSucceeds(seed());
  const received = query(collection(db('b'), 'friendships'), where('members', 'array-contains', 'b'));
  assert.equal((await getDocs(received)).size, 1);
  await assertSucceeds(accept(db('b')));
  for (const uid of ['a', 'b']) assert.equal((await getDoc(ref(db(uid)))).data().status, 'accepted');
  await assertFails(getDoc(ref(db('c'))));
  await assertFails(getDoc(ref(db(null))));
  await assertFails(getDocs(collection(db('a'), 'friendships')));
  assert.equal((await getDocs(query(collection(db('c'), 'friendships'), where('members', 'array-contains', 'c')))).size, 0);
});
for (const [actor, state] of [['a', 'pending'], ['b', 'pending'], ['a', 'accepted'], ['b', 'accepted']]) {
  it(`${actor} remove relação ${state} na condição correta`, async () => {
    await seed();
    if (state === 'accepted') await accept(db('b'));
    await assertSucceeds(deleteDoc(ref(db(actor))));
    assert.equal((await getDoc(ref(db('a')))).exists(), false);
  });
}
it('nega autoamizade, id arbitrário, par invertido e par ambíguo', async () => {
  for (const [id, members] of [['a:a', ['a', 'a']], ['outro', ['a', 'b']],
    ['b:a', ['b', 'a']], ['a:b:c', ['a', 'b:c']]]) {
    await assertFails(setDoc(doc(db('a'), 'friendships', id), request('a', members)));
  }
});
it('remetente não aceita, terceiro não lê/altera/apaga, anônimo não cria', async () => {
  await seed();
  await assertFails(accept(db('a')));
  await assertFails(accept(db('c')));
  await assertFails(deleteDoc(ref(db('c'))));
  await assertFails(setDoc(ref(db(null)), request()));
  await assertFails(setDoc(ref(db('c')), request('a')));
});
it('nega falsificação de amizade pronta, campos extras, tipos e datas inválidas', async () => {
  for (const data of [
    {...request(), status: 'accepted', acceptedAt: serverTimestamp()},
    {...request(), email: 'private@example.test'},
    {...request(), members: ['a']}, {...request(), senderId: 'c'},
    {...request(), status: 3}, {...request(), requestedAt: Timestamp.fromMillis(1)},
    {...request(), acceptedAt: null},
  ]) await assertFails(seed(data));
});
it('nega troca de membros, remetente, datas e reversão de accepted', async () => {
  await seed();
  for (const payload of [
    {senderId: 'b'}, {members: ['a', 'c']}, {requestedAt: serverTimestamp()},
    {status: 'accepted'}, {status: 'accepted', acceptedAt: Timestamp.fromMillis(1)},
  ]) await assertFails(updateDoc(ref(db('b')), payload));
  await accept(db('b'));
  await assertFails(updateDoc(ref(db('b')), {status: 'pending'}));
  await assertFails(accept(db('b'))); // Timestamp de aceitação é imutável.
});
it('não permite duplicar uma solicitação ou criar segundo documento do par', async () => {
  await seed();
  await assertFails(seed());
  await assertFails(setDoc(doc(db('b'), 'friendships', 'b:a'), request('b', ['b', 'a'])));
});
it('perfil removido impede nova solicitação/aceite, mas permite limpar a relação', async () => {
  await seed();
  await env.withSecurityRulesDisabled((ctx) => deleteDoc(doc(ctx.firestore(), 'users', 'b')));
  await assertFails(accept(db('b')));
  await assertSucceeds(deleteDoc(ref(db('a'))));
  await assertFails(seed());
});
it('transações cruzadas simultâneas criam só uma solicitação', async () => {
  const send = (uid) => {
    const database = db(uid);
    return runTransaction(database, async (tx) => {
    const target = ref(database);
    const existing = await tx.get(target);
    if (!existing.exists()) tx.set(target, request(uid));
    });
  };
  await Promise.all([send('a'), send('b'), send('a')]);
  const a = await getDocs(query(collection(db('a'), 'friendships'), where('members', 'array-contains', 'a')));
  assert.equal(a.size, 1);
  assert.equal(a.docs[0].data().status, 'pending');
});
it('fluxo persistente com duas contas reais no Auth e Firestore locais', async () => {
  const apps = [];
  const databases = [];
  try {
    const clients = [];
    for (let i = 0; i < 2; i++) {
      const app = initializeApp({projectId: 'demo-compy', apiKey: 'demo-key'}, `friends-${i}-${Date.now()}`);
      apps.push(app);
      const auth = getAuth(app);
      connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
      const database = getFirestore(app);
      connectFirestoreEmulator(database, '127.0.0.1', 8080);
      databases.push(database);
      const {user} = await signInAnonymously(auth);
      await setDoc(doc(database, 'users', user.uid), {id: user.uid, name: 'Teste', nameLower: 'teste',
        handle: `@teste${i}`, createdAt: serverTimestamp()});
      clients.push({uid: user.uid, db: database});
    }
    const [a, b] = clients;
    await setDoc(ref(a.db, a.uid, b.uid), request(a.uid, [a.uid, b.uid].sort()));
    const incoming = await getDocs(query(collection(b.db, 'friendships'), where('members', 'array-contains', b.uid)));
    assert.equal(incoming.size, 1);
    await updateDoc(ref(b.db, a.uid, b.uid), {status: 'accepted', acceptedAt: serverTimestamp()});
    assert.equal((await getDoc(ref(a.db, a.uid, b.uid))).data().status, 'accepted');
    await deleteDoc(ref(a.db, a.uid, b.uid));
    assert.equal((await getDoc(ref(b.db, a.uid, b.uid))).exists(), false);
  } finally {
    await Promise.all(databases.map(terminate));
    await Promise.all(apps.map(deleteApp));
  }
});
