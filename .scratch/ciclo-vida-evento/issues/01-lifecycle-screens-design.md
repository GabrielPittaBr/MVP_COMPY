# 01: Desenhar as telas do ciclo de vida no Claude Design

Status: open

Blocked by: None (can start immediately)

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §9, com os textos do §8.10.

**What to build:** Um canvas do tipo Design no Claude Design com as 12 pranchas do §9. Ele usa os tokens do app (Inter, a paleta do §9 item 2, pílulas e cards arredondados, telas de 390×844) e os textos reais do §8.10. O usuário pediu isso explicitamente ("Use o claude design para pensar no design"). Este ticket é uma **parada**: ele só fecha quando o usuário aprovar o visual. Os tickets com tela (06, 07, 09, 11 e 13, e os que dependem deles) esperam esse ok.

## Acceptance criteria

- [ ] O canvas foi criado pelo tipo Design, com o `type_url` do §9 item 1 ou, se ele falhar, com `quickstart` e `intent: design`. Foi construído com os tokens do app, porque a conta não tem design system.
- [ ] A referência visual são as capturas atuais do app (`docs/assets/screenshots/`): branco e limpo, pílulas cinza-claro e CTA azul-escuro.
- [ ] As 12 pranchas do §9 item 3 existem, com os textos reais:
  - Home com sino e badge, e "COMPY" centralizado;
  - central de notificações com itens não lidos, lidos e "Avaliado ✓", mais o estado vazio;
  - aba Eventos com o card ao vivo e o selo;
  - tela ao vivo do participante;
  - tela ao vivo do criador em atraso, com o diálogo de confirmação;
  - os três passos da avaliação, com o erro de nota abaixo de 3;
  - avaliação concluída;
  - diálogo de encerramento automático;
  - detalhe do evento encerrado antes e depois de avaliar;
  - perfil com as avaliações reais e ficha do local com a nota.
- [ ] O contraste AA é respeitado (§13 item 11): texto do selo escuro, com o verde só no ponto; estrelas com contorno visível; badge legível. Nenhuma cor existente muda. Se precisar de cor nova, ela ganha nome.
- [ ] O link foi enviado ao usuário com uma pergunta (AskUserQuestion), e ele aprovou. Se pediu ajustes, os ajustes foram feitos e aprovados.

## Verification

- [ ] O link do canvas está registrado neste ticket.
- [ ] Os ajustes e as decisões do usuário estão anotados aqui, para os tickets de tela seguirem.
- [ ] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `docs: registra o design aprovado da tarefa 14`
