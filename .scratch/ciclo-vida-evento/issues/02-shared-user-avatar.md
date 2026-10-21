# 02: Avatar de Usuário compartilhado

Status: open

Blocked by: None (can start immediately)

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §4.5 (avatar seguro) e §8.5 (último item).

**What to build:** Prefactor para as telas novas. Hoje o avatar do chat é o único que aguenta Usuário sem foto. Ele vira um widget compartilhado de avatar de Usuário. O chat passa a usar o widget compartilhado, e a pilha de avatares de participantes do detalhe do evento também. Com isso acaba a quebra em tempo de execução quando um participante não tem foto. O visual não muda.

## Acceptance criteria

- [ ] Existe um widget compartilhado de avatar de Usuário com o mesmo comportamento do avatar do chat, inclusive o fallback para URL vazia.
- [ ] Todas as telas do chat usam o widget compartilhado, e o widget antigo deixa de existir.
- [ ] A pilha de avatares de participantes usa o widget compartilhado, e o detalhe de um evento com participante sem foto abre sem erro.
- [ ] Testes de widget cobrem o fallback de URL vazia, no widget compartilhado e na pilha de participantes.

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `refactor: avatar de usuario compartilhado entre chat e eventos`
