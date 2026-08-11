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
      createdAt: serverTimestamp(),
    },
    { merge: true },
  );
  // RN-06: o e-mail vive fora do documento público.
  batch.set(doc(db, 'users', uid, 'private', 'contact'), { email }, { merge: true });
  // Merge espelha a tarefa 5: no re-cadastro o documento já existe, e `set`
  // sem merge sobrescreveria o documento inteiro.
  batch.set(doc(db, 'usernames', username), { uid }, { merge: true });
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

describe('indice de usernames — re-cadastro (tarefa 5)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'usernames', USERNAME), { uid: UID });
    });
  });

  it('o dono regrava o proprio indice', async () => {
    await assertSucceeds(
      setDoc(doc(as(UID), 'usernames', USERNAME), { uid: UID }, { merge: true }),
    );
  });

  it('ninguem toma o username de outro', async () => {
    await assertFails(
      setDoc(
        doc(as('uid_outro'), 'usernames', USERNAME),
        { uid: 'uid_outro' },
        { merge: true },
      ),
    );
  });

  it('o dono nao repassa o proprio indice para outro uid', async () => {
    await assertFails(
      setDoc(
        doc(as(UID), 'usernames', USERNAME),
        { uid: 'uid_outro' },
        { merge: true },
      ),
    );
  });
});

describe('esportes favoritos (tarefa 13)', () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', UID), {
        id: UID,
        name: 'Gabriel Pitta',
        handle: `@${USERNAME}`,
        avatarUrl: 'https://ui-avatars.com/api/?name=Gabriel',
        createdAt: new Date(),
      });
    });
  });

  /** Espelha `ProfileRemoteDataSource.updateFavoriteSports`. */
  const gravarEsportes = (db, uid, favoriteSports) =>
    setDoc(doc(db, 'users', uid), { favoriteSports }, { merge: true });

  it('o dono grava a propria escolha', async () => {
    await assertSucceeds(gravarEsportes(as(UID), UID, ['futebol', 'volei']));
  });

  it('lista vazia e escolha valida — e o que o "pular" grava', async () => {
    await assertSucceeds(gravarEsportes(as(UID), UID, []));
  });

  it('o enum inteiro cabe no limite', async () => {
    await assertSucceeds(
      gravarEsportes(as(UID), UID, [
        'futebol', 'basquete', 'volei', 'tenisDeMesa',
        'futsal', 'corrida', 'ciclismo', 'caminhada',
      ]),
    );
  });

  it('mais de 8 esportes e recusado', async () => {
    await assertFails(
      gravarEsportes(as(UID), UID, [
        'futebol', 'basquete', 'volei', 'tenisDeMesa',
        'futsal', 'corrida', 'ciclismo', 'caminhada', 'futebol',
      ]),
    );
  });

  it('favoriteSports precisa ser lista', async () => {
    await assertFails(gravarEsportes(as(UID), UID, 'futebol'));
  });

  it('ninguem escolhe os esportes de outro', async () => {
    await assertFails(gravarEsportes(as('uid_outro'), UID, ['futebol']));
  });

  it('deslogado nao grava esporte nenhum', async () => {
    await assertFails(gravarEsportes(anonimo(), UID, ['futebol']));
  });

  it('campo desconhecido continua barrado junto com os esportes', async () => {
    await assertFails(
      setDoc(
        doc(as(UID), 'users', UID),
        { favoriteSports: ['futebol'], ratingAverage: 5 },
        { merge: true },
      ),
    );
  });
});

describe('contato privado — RN-06 (tarefa 13)', () => {
  const contato = (db, uid) => doc(db, 'users', uid, 'private', 'contact');

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', UID), {
        id: UID,
        name: 'Gabriel Pitta',
        handle: `@${USERNAME}`,
        avatarUrl: 'https://ui-avatars.com/api/?name=Gabriel',
        createdAt: new Date(),
      });
      await setDoc(contato(db, UID), { email: 'g@example.com' });
    });
  });

  it('o dono le o proprio e-mail', async () => {
    await assertSucceeds(getDoc(contato(as(UID), UID)));
  });

  it('o dono grava o proprio e-mail', async () => {
    await assertSucceeds(
      setDoc(contato(as(UID), UID), { email: 'novo@example.com' }, { merge: true }),
    );
  });

  // O ponto da tarefa: antes disso qualquer autenticado lia o e-mail de todo
  // mundo, porque ele morava no documento publico.
  it('outro autenticado NAO le o e-mail alheio', async () => {
    await assertFails(getDoc(contato(as('uid_outro'), UID)));
  });

  it('deslogado NAO le e-mail nenhum', async () => {
    await assertFails(getDoc(contato(anonimo(), UID)));
  });

  it('ninguem escreve no contato alheio', async () => {
    await assertFails(
      setDoc(contato(as('uid_outro'), UID), { email: 'x@example.com' }),
    );
  });

  it('o perfil publico continua legivel — so o contato e que nao', async () => {
    await assertSucceeds(getDoc(doc(as('uid_outro'), 'users', UID)));
  });

  it('gravar e-mail de volta no documento publico e recusado', async () => {
    await assertFails(
      setDoc(
        doc(as(UID), 'users', UID),
        { email: 'g@example.com' },
        { merge: true },
      ),
    );
  });
});

function assertHandle(snap) {
  if (!snap.exists() || !snap.data().handle) {
    throw new Error('perfil sem handle — _userHasProfile devolveria false');
  }
}
