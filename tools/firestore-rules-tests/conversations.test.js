/**
 * Regras de `conversations` e da subcoleção `messages`.
 *
 * Roda contra o emulador do Firestore, não contra o projeto real:
 *   npm --prefix tools/firestore-rules-tests test
 *
 * O que estas regras protegem: antes, `allow read, write: if signedIn()`
 * deixava qualquer usuário autenticado ler e escrever qualquer conversa
 * privada de qualquer pessoa.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const JOAO = 'uid_joao';
const DOUGLAS = 'uid_douglas';
const ESTRANHO = 'uid_estranho';
const CONVERSA = 'uid_douglas_uid_joao';

let testEnv;

/** Documento de conversa no formato que o app grava. */
const conversationDoc = (members = [JOAO, DOUGLAS]) => ({
  members,
  memberSummaries: Object.fromEntries(
    members.map((uid) => [
      uid,
      { id: uid, name: uid, handle: `@${uid}`, avatarUrl: '' },
    ]),
  ),
  lastMessage: 'Bora treinar?',
  lastMessageAt: new Date(),
  unreadCounts: Object.fromEntries(members.map((uid) => [uid, 0])),
});

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
  // Semeia por fora das regras: o estado inicial não é o que está sob teste.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'conversations', CONVERSA), conversationDoc());
    await setDoc(doc(db, 'conversations', CONVERSA, 'messages', 'm1'), {
      senderId: DOUGLAS,
      text: 'Bora treinar?',
      sentAt: new Date(),
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const anonimo = () => testEnv.unauthenticatedContext().firestore();

describe('conversations — leitura', () => {
  it('membro lê a própria conversa', async () => {
    await assertSucceeds(getDoc(doc(as(JOAO), 'conversations', CONVERSA)));
  });

  it('não-membro não lê conversa alheia', async () => {
    await assertFails(getDoc(doc(as(ESTRANHO), 'conversations', CONVERSA)));
  });

  it('deslogado não lê nada', async () => {
    await assertFails(getDoc(doc(anonimo(), 'conversations', CONVERSA)));
  });

  it('a consulta paginada da lista continua funcionando para o membro', async () => {
    // A query filtra por `members` arrayContains, então ela sobrevive ao
    // aperto da leitura — é exatamente o alerta do roadmap.
    const { query, where, orderBy, limit } = await import('firebase/firestore');
    await assertSucceeds(
      getDocs(
        query(
          collection(as(JOAO), 'conversations'),
          where('members', 'array-contains', JOAO),
          orderBy('lastMessageAt', 'desc'),
          limit(10),
        ),
      ),
    );
  });

  it('consulta sem o filtro de membro é recusada', async () => {
    await assertFails(getDocs(collection(as(ESTRANHO), 'conversations')));
  });
});

describe('conversations — criação', () => {
  it('cria conversa incluindo a si mesmo', async () => {
    await assertSucceeds(
      setDoc(
        doc(as(JOAO), 'conversations', 'uid_joao_uid_novo'),
        conversationDoc([JOAO, 'uid_novo']),
      ),
    );
  });

  it('não cria conversa entre terceiros', async () => {
    await assertFails(
      setDoc(
        doc(as(ESTRANHO), 'conversations', 'uid_douglas_uid_joao_2'),
        conversationDoc([JOAO, DOUGLAS]),
      ),
    );
  });

  it('não cria conversa com mais de dois membros', async () => {
    await assertFails(
      setDoc(
        doc(as(JOAO), 'conversations', 'grupo'),
        conversationDoc([JOAO, DOUGLAS, ESTRANHO]),
      ),
    );
  });

  it('não cria conversa consigo mesmo apenas', async () => {
    await assertFails(
      setDoc(doc(as(JOAO), 'conversations', 'so_eu'), conversationDoc([JOAO])),
    );
  });

  it('aceita o documento exatamente como o app o cria', async () => {
    // Espelha o payload de ChatRemoteDataSource.createConversation.
    await assertSucceeds(
      setDoc(doc(as(JOAO), 'conversations', 'uid_joao_uid_novo'), {
        members: [JOAO, 'uid_novo'],
        memberSummaries: {
          [JOAO]: { id: JOAO, name: 'João', handle: '@joao', avatarUrl: '' },
          uid_novo: {
            id: 'uid_novo',
            name: 'Novo',
            handle: '@novo',
            avatarUrl: '',
          },
        },
        lastMessage: '',
        lastMessageAt: serverTimestamp(),
        unreadCounts: { [JOAO]: 0, uid_novo: 0 },
      }),
    );
  });

  it('recriar conversa existente com os MESMOS membros passa — e é destrutivo', async () => {
    // Armadilha: `diff().affectedKeys()` só acusa campo cujo valor mudou.
    // Reescrever `members` e `memberSummaries` iguais não aparece no diff, o
    // `hasOnly` do update passa, e o payload de criação zera o rodapé.
    //
    // É por isso que o app lê a conversa ANTES de tentar criar, em vez de
    // criar e tratar a recusa como "já existe".
    await assertSucceeds(
      setDoc(doc(as(JOAO), 'conversations', CONVERSA), {
        ...conversationDoc(),
        lastMessage: '',
        unreadCounts: { [JOAO]: 0, [DOUGLAS]: 0 },
      }),
    );

    let depois;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      depois = await getDoc(doc(ctx.firestore(), 'conversations', CONVERSA));
    });
    assert.equal(
      depois.data().lastMessage,
      '',
      'o rodapé da conversa foi sobrescrito pela recriação',
    );
  });

  it('recriar conversa existente trocando os membros é recusado', async () => {
    await assertFails(
      setDoc(
        doc(as(JOAO), 'conversations', CONVERSA),
        conversationDoc([JOAO, ESTRANHO]),
      ),
    );
  });

  it('ler conversa inexistente falha como se fosse alheia', async () => {
    await assertFails(getDoc(doc(as(JOAO), 'conversations', 'nao_existe')));
  });
});

describe('conversations — atualização', () => {
  it('membro atualiza o rodapé da conversa', async () => {
    // É o que o envio de mensagem escreve em lote.
    await assertSucceeds(
      updateDoc(doc(as(JOAO), 'conversations', CONVERSA), {
        lastMessage: 'novo',
        lastMessageAt: serverTimestamp(),
      }),
    );
  });

  it('membro atualiza o contador de não-lidas', async () => {
    await assertSucceeds(
      updateDoc(doc(as(JOAO), 'conversations', CONVERSA), {
        unreadCounts: { [JOAO]: 0, [DOUGLAS]: 3 },
      }),
    );
  });

  it('membro não troca os participantes depois de criada', async () => {
    await assertFails(
      updateDoc(doc(as(JOAO), 'conversations', CONVERSA), {
        members: [JOAO, ESTRANHO],
      }),
    );
  });

  it('membro não reescreve os dados públicos dos participantes', async () => {
    await assertFails(
      updateDoc(doc(as(JOAO), 'conversations', CONVERSA), {
        memberSummaries: {},
      }),
    );
  });

  it('não-membro não atualiza conversa alheia', async () => {
    await assertFails(
      updateDoc(doc(as(ESTRANHO), 'conversations', CONVERSA), {
        lastMessage: 'invadi',
      }),
    );
  });

  it('ninguém apaga conversa', async () => {
    await assertFails(deleteDoc(doc(as(JOAO), 'conversations', CONVERSA)));
  });
});

describe('messages', () => {
  const mensagens = (db) => collection(db, 'conversations', CONVERSA, 'messages');

  it('membro lê as mensagens da conversa', async () => {
    await assertSucceeds(getDocs(mensagens(as(JOAO))));
  });

  it('não-membro não lê as mensagens', async () => {
    await assertFails(getDocs(mensagens(as(ESTRANHO))));
  });

  it('membro envia mensagem assinada com o próprio uid', async () => {
    await assertSucceeds(
      addDoc(mensagens(as(JOAO)), {
        senderId: JOAO,
        text: 'Bora!',
        sentAt: serverTimestamp(),
      }),
    );
  });

  it('membro não envia mensagem assinada por outro', async () => {
    // É exatamente o que o app fazia antes: senderId era a constante do mock.
    await assertFails(
      addDoc(mensagens(as(JOAO)), {
        senderId: DOUGLAS,
        text: 'me passando por ele',
        sentAt: serverTimestamp(),
      }),
    );
  });

  it('não-membro não envia mensagem na conversa alheia', async () => {
    await assertFails(
      addDoc(mensagens(as(ESTRANHO)), {
        senderId: ESTRANHO,
        text: 'invadi',
        sentAt: serverTimestamp(),
      }),
    );
  });

  it('mensagem enviada não se edita', async () => {
    await assertFails(
      updateDoc(doc(as(DOUGLAS), 'conversations', CONVERSA, 'messages', 'm1'), {
        text: 'editada',
      }),
    );
  });

  it('mensagem enviada não se apaga', async () => {
    await assertFails(
      deleteDoc(doc(as(DOUGLAS), 'conversations', CONVERSA, 'messages', 'm1')),
    );
  });
});
