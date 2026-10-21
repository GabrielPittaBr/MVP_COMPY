# 06: Selo "Acontecendo agora" e CTA do detalhe por status

Status: open

Blocked by: 01 — Desenhar as telas do ciclo de vida no Claude Design; 03 — Status derivado do evento

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §8.3, §8.4 e §8.10 (Status, Detalhe).

Hipóteses a conferir (§13): 9 (o "agora" a cada 30s não reconstrói a lista inteira) e 11 (contraste do selo).

**What to build:** O status passa a aparecer na tela, seguindo o design aprovado no ticket 01.

- O selo de status ("Acontecendo agora", "Encerrado" e "Encerrado automaticamente") aparece no detalhe. Nos cards das listas e da Home, aparece quando o evento está acontecendo.
- O detalhe passa a acompanhar o documento em tempo real e mostra o CTA certo para cada status e papel. Isso corrige o bug de "Participar" aparecer para quem já participa e para o criador.
- Os textos que hoje estão fixos no detalhe vão para as strings do app.

Este ticket entrega estas linhas da tabela de CTA do §8.4:

- **Agendado:** quem não participa vê "Participar"; o participante vê "Você está participando" (desabilitado); o criador vê "Você organiza este evento" (desabilitado).
- **Acontecendo, quem não participa:** "Participar".
- **Encerrado, para todos:** selo "Encerrado" ou "Encerrado automaticamente" e "Este evento já terminou", sem CTA.

Outras linhas ficam para os tickets seguintes: "Abrir evento ao vivo" no 07, "Avaliar…" e "Você já avaliou" no 09, "Nota do evento" no 13. Até o 07 existir, participante e criador de um evento acontecendo veem o selo com o CTA desabilitado do evento agendado.

## Acceptance criteria

- [ ] O selo tem ponto verde e texto escuro sobre fundo claro (AA). "Encerrado" aparece em cinza.
- [ ] O card recebe o status, calculado por quem monta a lista com o "agora" do relógio. O cálculo fica no widget folha (ou usa `select`), para não reconstruir a lista inteira a cada 30s.
- [ ] O detalhe acompanha o documento por stream (o repositório e o mock ganham `watchById`), e um encerramento aparece sem recarregar.
- [ ] O CTA segue status e papel conforme as linhas acima, com um teste de widget por linha (relógio fixo).
- [ ] Os textos fixos do detalhe vão para as strings do app: "Participantes (N)", "Você entrou no evento!", "Evento não encontrado." e "Erro ao entrar no evento".

## Verification

- [ ] `flutter test` verde.
- [ ] `dart analyze` com 0 erros e sem infos novas além das 10 da linha de base.
- [ ] Resultado das hipóteses 9 e 11 anotado aqui.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `feat: selo acontecendo agora e cta do detalhe por status`
