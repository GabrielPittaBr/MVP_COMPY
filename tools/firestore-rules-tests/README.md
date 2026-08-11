# Testes das regras do Firestore

Exercita `firestore.rules` contra o emulador do Firestore. Não toca o projeto
real (`compy-tcc`) — o emulador roda sob o projeto fictício `demo-compy`.

Isto **não** faz parte do app Flutter: é a única forma de testar regras de
segurança do Firestore, que não têm equivalente em Dart.

## Rodar

```bash
npm install --prefix tools/firestore-rules-tests   # uma vez
npm test --prefix tools/firestore-rules-tests
```

## Pré-requisitos

- **JDK 21 ou superior.** O `firebase-tools` recusa versões anteriores. Nesta
  máquina o Java do PATH é o 1.8 e não serve; aponte para um JDK moderno antes
  de rodar:

  ```bash
  export JAVA_HOME="/c/Users/gabri/.jdks/temurin-25.0.3"
  export PATH="$JAVA_HOME/bin:$PATH"
  ```

- `firebase-tools` no PATH (instalação global — ver `CLAUDE.md`).

O script roda `node --test` sem lista de arquivos: todo `*.test.js` desta pasta
entra automaticamente. O `--test-concurrency=1` não é enfeite — por padrão o
Node roda um processo por arquivo em paralelo, e os arquivos compartilham o
mesmo emulador: o `clearFirestore()` de um apagaria os dados semeados dos
outros no meio do teste.

## O que está coberto

**`conversations`** e a subcoleção `messages`, nos dois papéis que importam:
membro e não-membro. Leitura, criação, atualização do rodapé, imutabilidade
de `members` e `memberSummaries`, assinatura da mensagem pelo próprio uid, e
as negações de edição e remoção.

Um caso merece destaque porque restringe o código do app: **`memberSummaries`
é imutável depois da criação**. Nome e avatar desnormalizados na conversa
precisam ser gravados no momento em que ela nasce — não há como corrigi-los
depois sem afrouxar a regra.

**`users` e `usernames`**, replicando o batch do login com Google.

**`events`** (tarefa 12), com foco no `participantIds` — o array de uids que a
seção "Participando" consulta. A regra do join exige que ele cresça **junto**
de `participants` e do decremento de vaga, sempre com o próprio uid: entrar só
no `participantIds` apareceria em "Participando" sem ocupar vaga nem constar
da lista de participantes.

Dois casos restringem o código do app:

- **`participantIds` é obrigatório na criação e só pode conter o próprio uid.**
  Quem gravar um `Event` sem esse campo leva `PERMISSION_DENIED`.
- **Documentos anteriores à tarefa 12 continuam recebendo join**, porque a
  regra lê o valor antigo com `resource.data.get('participantIds', [])`. O
  campo nasce no primeiro join — mas só com quem entrou dali em diante, então
  os participantes antigos desses documentos não aparecem na consulta de
  "Participando". Ver a nota de migração abaixo.

## Migração de `participantIds`

Eventos gravados antes da tarefa 12 não têm o campo e **não aparecem** em
"Participando" para ninguém (a consulta roda no servidor; derivar no cliente
não ajuda). Como ainda não há usuários reais, o caminho barato é apagar os
eventos de teste no console antes de publicar.

## Antes de publicar em produção

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Publicar as regras **quebra o envio de mensagem** em qualquer versão do app
anterior à correção do `senderId` (issue #1): a regra exige
`senderId == request.auth.uid`, e o app antigo gravava a constante do mock.
