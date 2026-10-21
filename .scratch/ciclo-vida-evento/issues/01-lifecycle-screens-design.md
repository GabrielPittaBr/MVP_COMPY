# 01: Desenhar as telas do ciclo de vida no Claude Design

Status: resolved

Blocked by: None (can start immediately)

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §9, com os textos do §8.10.

**What to build:** Um canvas do tipo Design no Claude Design com as 12 pranchas do §9. Ele usa os tokens do app (Inter, a paleta do §9 item 2, pílulas e cards arredondados, telas de 390×844) e os textos reais do §8.10. O usuário pediu isso explicitamente ("Use o claude design para pensar no design"). Este ticket é uma **parada**: ele só fecha quando o usuário aprovar o visual. Os tickets com tela (06, 07, 09, 11 e 13, e os que dependem deles) esperam esse ok.

## Acceptance criteria

- [x] O canvas foi criado pelo tipo Design, com o `type_url` do §9 item 1 ou, se ele falhar, com `quickstart` e `intent: design`. Foi construído com os tokens do app, porque a conta não tem design system.
- [x] A referência visual são as capturas atuais do app (`docs/assets/screenshots/`): branco e limpo, pílulas cinza-claro e CTA azul-escuro.
- [x] As 12 pranchas do §9 item 3 existem, com os textos reais:
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
- [x] O contraste AA é respeitado (§13 item 11): texto do selo escuro, com o verde só no ponto; estrelas com contorno visível; badge legível. Nenhuma cor existente muda. Se precisar de cor nova, ela ganha nome.
- [x] O link foi enviado ao usuário com uma pergunta (AskUserQuestion), e ele aprovou. Se pediu ajustes, os ajustes foram feitos e aprovados.

## Verification

- [x] O link do canvas está registrado neste ticket: https://claude.ai/artifact/GR4BpTc6MnEnoHrDkYCPXS (privado do dono; 16 pranchas em 4 linhas).
- [x] Os ajustes e as decisões do usuário estão anotados aqui, para os tickets de tela seguirem.
  - 21/10/2026: título da notificação do participante e do criador com encerramento manual = "{título} terminou" (em vez de "Como foi o {título}?", que erra o gênero com títulos femininos). O diálogo de encerramento automático também perde o "O" inicial.
  - 21/10/2026: card ao vivo em azul primário, com texto branco.
  - 21/10/2026: cor nova `warningText` (#B45309), para o texto de atraso ("Passou X do previsto") e o contorno da estrela cheia. Dá 5,0:1 sobre branco. Ela entra no `AppColors` com esse nome no primeiro ticket de tela que precisar dela; nenhuma cor existente muda.
  - 21/10/2026: o usuário pediu para levar o design ao Figma, pelo connector, no arquivo https://www.figma.com/design/dBrJFCVi0EkAWkBP2Zifmr. A página "Tarefa 14 · Ciclo de vida do evento" (https://www.figma.com/design/dBrJFCVi0EkAWkBP2Zifmr/aplicativo-ponto-de-encontro-para-a-pratica-de-esportes?node-id=393-348) já tem:
    - a coleção de variáveis "COMPY" com a paleta do `AppColors`, as cores dos esportes e variáveis com alfa (tints, scrim, desabilitado); a cor nova `color/warningText` (#B45309) é o texto de atraso e o contorno da estrela;
    - a seção "Componentes": 29 ícones, Avatar, Estrela, Selo de status, Tag, Botão, NavBar, Ícone de esporte, Banner do card, EventCard, Linha de participante, Item de notificação, Campo de comentário e Nota resumida;
    - a linha "Notificações e aviso único" (pranchas 01, 02, 02 vazia e 10).
  - Falta no Figma: as linhas "Durante o evento", "Avaliação" e "Depois do evento", e corrigir os círculos de categoria da Home (01 e 10), que aparecem com a cor cheia em vez do tint. O trabalho parou porque o plano Starter do Figma só dá cerca de 20 chamadas de MCP por mês. O prelúdio dos scripts está em `.scratch/ciclo-vida-evento/figma-prelude.js`.
  - 21/10/2026: o usuário aprovou o visual pelo canvas do Claude Design, que é a referência dos tickets de tela. O Figma fica parcial e será completado quando o limite voltar.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

Commit sugerido: `docs: registra o design aprovado da tarefa 14`
