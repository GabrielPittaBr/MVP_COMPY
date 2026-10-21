# 13: Médias reais no perfil, no Local Esportivo e no evento encerrado

Status: open

Blocked by: 01 — Desenhar as telas do ciclo de vida no Claude Design; 09 — Avaliar o evento e o Local Esportivo

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §3 (Onde ficam as médias), §5.3, §7 (ratingSummaries), §8.8 e §8.10 (Médias).

**What to build:** As notas viram médias visíveis. Nenhum comentário aparece em lugar nenhum (D13).

- **Perfil:** mostra a média real do Usuário em tempo real, com vírgula decimal ("4,8"), estrelas, barras por nota e o plural certo ("1 avaliação" / "12 avaliações"). O estado vazio em primeira pessoa fica só no próprio perfil.
- **Ficha do Local Esportivo no mapa:** ganha, logo abaixo das modalidades, "★★★★☆ 4,3 (23 avaliações)" ou, em cinza, "Sem avaliações ainda".
- **Detalhe do evento encerrado:** mostra "Nota do evento".

As médias vêm de `ratingSummaries` (média = soma / contagem), e só quem está logado lê. Os contratos de `places` e de `users` não mudam. A média do perfil só ganha dados reais depois do ticket 10, que grava as notas de Usuário; até lá, o mock cobre.

## Acceptance criteria

- [ ] O resumo de avaliação vai para a feature de avaliações, com construção a partir do agregado (contagem, soma e contagem por estrela), e essa construção é testada.
- [ ] O repositório ganha o stream do resumo por alvo. O mock calcula os agregados e traz o 4,8 / 12 do perfil mock.
- [ ] O modelo do perfil deixa de ter a nota, e o perfil lê o resumo do próprio uid. O mock, o repositório e os três testes que usavam o campo são ajustados.
- [ ] O breakdown usa vírgula decimal, as estrelas do widget compartilhado em modo de exibição e o plural certo. O teste dele muda junto.
- [ ] A ficha do local ganha a linha de nota, lendo o resumo do local, com o `_RatingRow` antigo como referência visual.
- [ ] O detalhe entrega a linha "Encerrado → Nota do evento ★ 4,6 · 8 avaliações" da tabela de CTA, quando houver avaliações.
- [ ] Regras de `ratingSummaries`: leitura logado → permite; leitura deslogado → nega; escrita → nega.
- [ ] Testes de widget:
  - "4,8" no breakdown;
  - linha de nota na ficha do local, com e sem avaliações;
  - nota no detalhe encerrado.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] `npm test --prefix tools/firestore-rules-tests` verde, com o JDK 25 no `JAVA_HOME`. Se der erro de loopback, rode fora do sandbox.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: medias reais de avaliacao no perfil, no local e no evento`
