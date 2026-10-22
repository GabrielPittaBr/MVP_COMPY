# 13: Médias reais no perfil, no Local Esportivo e no evento encerrado

Status: resolved

Blocked by: 01 — Desenhar as telas do ciclo de vida no Claude Design; 09 — Avaliar o evento e o Local Esportivo

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Onde ficam as médias), §5.3, §7 (ratingSummaries), §8.8 e §8.10 (Médias).

**What to build:** As notas viram médias visíveis. Nenhum comentário aparece em lugar nenhum (D13).

- **Perfil:** mostra a média real do Usuário em tempo real, com vírgula decimal ("4,8"), estrelas, barras por nota e o plural certo ("1 avaliação" / "12 avaliações"). O estado vazio em primeira pessoa fica só no próprio perfil.
- **Ficha do Local Esportivo no mapa:** ganha, logo abaixo das modalidades, "★★★★☆ 4,3 (23 avaliações)" ou, em cinza, "Sem avaliações ainda".
- **Detalhe do evento encerrado:** mostra "Nota do evento".

As médias vêm de `ratingSummaries` (média = soma / contagem), e só quem está logado lê. Os contratos de `places` e de `users` não mudam. A média do perfil só ganha dados reais depois do ticket 10, que grava as notas de Usuário; até lá, o mock cobre.

## Acceptance criteria

- [x] O resumo de avaliação vai para a feature de avaliações, com construção a partir do agregado (contagem, soma e contagem por estrela), e essa construção é testada.
- [x] O repositório ganha o stream do resumo por alvo. O mock calcula os agregados e traz o 4,8 / 12 do perfil mock.
- [x] O modelo do perfil deixa de ter a nota, e o perfil lê o resumo do próprio uid. O mock, o repositório e os três testes que usavam o campo são ajustados.
- [x] O breakdown usa vírgula decimal, as estrelas do widget compartilhado em modo de exibição e o plural certo. O teste dele muda junto.
- [x] A ficha do local ganha a linha de nota, lendo o resumo do local, com o `_RatingRow` antigo como referência visual.
- [x] O detalhe entrega a linha "Encerrado → Nota do evento ★ 4,6 · 8 avaliações" da tabela de CTA, quando houver avaliações.
- [x] Regras de `ratingSummaries`: leitura logado → permite; leitura deslogado → nega; escrita → nega.
- [x] Testes de widget:
  - "4,8" no breakdown;
  - linha de nota na ficha do local, com e sem avaliações;
  - nota no detalhe encerrado.

## Verification

- [x] `flutter test` verde.
- [x] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [x] `npm test --prefix tools/firestore-rules-tests` verde, com o JDK 25 no `JAVA_HOME`. Se der erro de loopback, rode fora do sandbox.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Notas:

- O `RatingSummary` foi para `lib/features/ratings/domain/entities/`, com o `RatingSummary.fromAggregate`, o `RatingSummary.empty`, o enum `RatingTargetType` e o tipo `RatingTarget` (registro `(type, id)`, usado como chave do `ratingSummaryProvider.family`).
- Os providers remotos de avaliações e de notificações passaram a usar `firebaseEnabled` (flag ligada e Firebase inicializado), como descreve o AGENTS.md. Sem Firebase (no fallback do `main` e nos testes de widget), essas features caem no mock em vez de quebrar. Os providers antigos das outras features continuam como estavam.
- O mock do perfil passou a vir do `InMemoryRatingsStore`: 10 notas 5 e 2 notas 4 dão 4,83 ("4,8") com 12 avaliações. A distribuição antiga, de frações soltas, não fechava com 12 notas.
- O `RatingBreakdown` ganhou `isOwnProfile`. Só o próprio perfil usa o estado vazio em primeira pessoa; ele é o único uso hoje.
- As regras de `ratingSummaries` já tinham os três casos no `ratings.test.js` do ticket 09.
- As estrelas de exibição arredondam a média para a estrela inteira mais próxima ("4,3" mostra 4 estrelas, e "4,6" mostra 5).

Commit sugerido: `feat: medias reais de avaliacao no perfil, no local e no evento`
