# Testes das regras do Firestore e do Storage

Exercita `firestore.rules` e `storage.rules` contra os emuladores. Não toca o
projeto real (`compy-tcc`) — os emuladores rodam sob o projeto fictício
`demo-compy`.

Isto **não** faz parte do app Flutter: é a única forma de testar regras de
segurança do Firebase, que não têm equivalente em Dart.

## Rodar

```bash
npm install --prefix tools/firestore-rules-tests   # uma vez
npm test --prefix tools/firestore-rules-tests      # 190 casos
```

## Pré-requisitos

- **JDK 21 LTS ou superior compatível com o emulador.** O `firebase-tools`
  recusa versões anteriores. Aponte `JAVA_HOME` para um JDK compatível apenas
  na sessão que executará a suíte; não é necessário nem desejável versionar
  caminhos locais.

- O `firebase-tools` é dependência de desenvolvimento deste pacote; não é
  necessária instalação global.

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

**`users` e `usernames`**, replicando o batch do login com Google, e a forma
do `avatarUrl`: texto de até 2048 caracteres começando por `http(s)://` (o
`http` é o emulador do Storage).

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

**`events`, encerramento** (tarefa 14). Só o Organizador encerra, uma vez só,
depois do início e até 1h após o fim previsto, gravando o horário do servidor e
`endedAutomatically = false`. O `true` é exclusivo da Function
`autoEndOverdueEvents`, e o `ratedBy`, da callable da avaliação; nenhum evento
nasce com esses campos. Depois do encerramento, ninguém mais entra no evento e
o Organizador não o edita.

**`ratings` e `ratingSummaries`** (tarefa 14). `ratings` é fechada ao
cliente: nem o autor lê a própria avaliação (D13), e só a callable
`submitEventRatings` grava. `ratingSummaries` é só leitura para quem está
logado.

**`users/{uid}/notifications`** (tarefa 14). Só o dono lê. O cliente não cria
notificação (quem cria é o gatilho `onEventEnded`), só marca como lida, uma
vez e com o horário do servidor, e apaga as próprias na exclusão de conta.

**Storage** (`storage.test.js`): fotos de perfil em
`users/{uid}/avatar_<millis>.jpg`. Só o dono envia, só JPEG abaixo de 1 MB,
só com esse padrão de nome, e nunca por cima de um arquivo existente — no
Storage sobrescrever conta como `create`, então a regra exige
`resource == null`. Qualquer autenticado lê; só o dono lista e apaga (é o que
a exclusão de conta usa).

## Migração de `participantIds`

Eventos gravados antes da tarefa 12 não têm o campo e **não aparecem** em
"Participando" para ninguém (a consulta roda no servidor; derivar no cliente
não ajuda). Como ainda não há usuários reais, o caminho barato é apagar os
eventos de teste no console antes de publicar.

## Antes de publicar em produção

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Publicar as regras **quebra o envio de mensagem** em qualquer versão do app
anterior à correção do `senderId` (issue #1): a regra exige
`senderId == request.auth.uid`, e o app antigo gravava a constante do mock.
