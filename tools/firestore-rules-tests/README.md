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

## O que está coberto

`conversations` e a subcoleção `messages`, nos dois papéis que importam:
membro e não-membro. Leitura, criação, atualização do rodapé, imutabilidade
de `members` e `memberSummaries`, assinatura da mensagem pelo próprio uid, e
as negações de edição e remoção.

Um caso merece destaque porque restringe o código do app: **`memberSummaries`
é imutável depois da criação**. Nome e avatar desnormalizados na conversa
precisam ser gravados no momento em que ela nasce — não há como corrigi-los
depois sem afrouxar a regra.

## Antes de publicar em produção

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Publicar as regras **quebra o envio de mensagem** em qualquer versão do app
anterior à correção do `senderId` (issue #1): a regra exige
`senderId == request.auth.uid`, e o app antigo gravava a constante do mock.
