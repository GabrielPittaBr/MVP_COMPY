# 10: Avaliar quem jogou (passo Participantes)

Status: resolved

Blocked by: 09 — Avaliar o evento e o Local Esportivo

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §6.3 (participantes) e §8.7 (Passo de participantes).

**What to build:** O fluxo de avaliação ganha o último passo, opcional: "Quem jogou com você".

- **Cards:** cada participante, menos a própria pessoa, aparece num card com avatar, nome, @handle e a tag "Organizador", mais estrelas, comentário e "Pular".
- **Pular:** um card pulado vira "Pulado · Desfazer", e "Pular todas" fica no topo.
- **Envio:** card sem estrelas conta como não avaliado. O envio só trava se algum card com nota abaixo de 3 estiver sem motivo.
- **Criador:** passa a fazer Local → Participantes. Sem outros participantes, o passo some.
- **Callable:** passa a aceitar e validar os participantes avaliados. Cada avaliação alimenta a média do Usuário avaliado.

## Acceptance criteria

- [x] Validação na callable:
  - participante avaliado fora de `participantIds` (ou dos ids legados) → `invalid-argument`;
  - participante avaliado igual a quem chama → `invalid-argument`;
  - uid repetido → `invalid-argument`;
  - cada avaliado gera uma `rating` e o agregado `user`.
- [x] Testes com fakes: "criador avalia local e participantes", "participante sem participantes avaliados" e a validação dos participantes.
- [x] O passo de participantes tem Pular, "Pulado · Desfazer" e "Pular todas", e a própria pessoa nunca aparece.
- [x] O envio só bloqueia nota abaixo de 3 sem motivo. Cards sem nota não entram no envio.
- [x] O mock registra as avaliações de participantes.
- [x] Testes de widget:
  - "Pular todas";
  - desfazer;
  - bloqueio por nota baixa sem motivo;
  - criador com Local → Participantes;
  - o passo some quando não há outros participantes.

## Verification

- [x] `flutter test` verde.
- [x] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [x] `npm run lint --prefix functions` e `npm test --prefix functions` verdes.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Notas:

- A validação dos participantes na callable já tinha entrado no ticket 09. Aqui entraram os testes que o ticket pede: criador avalia local e participantes, participante sem ninguém avaliado, média do Usuário com duas notas, evento legado e nota baixa de participante sem motivo. A suíte das Functions foi para 70 testes.
- Um card pulado guarda a nota para o "Desfazer", mas fica fora da validação e do envio. Pular o card com nota baixa sem motivo destrava o envio.
- O aviso de privacidade aparece uma vez, embaixo dos cards, e não em cada card (versão compacta do `RatingInput`).
- Com o passo novo, o criador de evento legado sem local, mas com outros participantes, passa a ter o que avaliar. Isso resolve a pendência anotada no ticket 09.

Commit sugerido: `feat: passo de avaliacao dos participantes`
