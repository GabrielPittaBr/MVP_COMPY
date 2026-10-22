# 14: E2E no Chrome com emuladores

Status: resolved

Blocked by: 02 a 13 — todos os tickets de código

Spec: docs/tarefa-14-ciclo-de-vida-do-evento.md §11.2 e §11.3.

Hipóteses a conferir na prática (§13): 6 (o gatilho dispara no emulador com escrita pela REST) e 8 (`push` e `pop` da avaliação no navegador).

**What to build:** O roteiro do §11.3 executado de ponta a ponta no Chrome, contra os emuladores de Auth, Firestore e Functions. Nunca contra o `compy-tcc`.

- **Preparação:** três contas (o criador, um participante e alguém de fora do evento) e a Quadra de Teste semeada no emulador.
- **O que o roteiro cobre:**
  - o evento ao vivo e a DM;
  - o encerramento manual, com as duas avaliações;
  - a notificação e o "Avaliado";
  - o sumiço do evento das listas;
  - as médias;
  - o encerramento automático simulado, com o diálogo único;
  - as regressões.
- **Bugs:** os pequenos são corrigidos aqui, com teste. Os grandes viram ticket novo.

## Acceptance criteria

- [x] Os passos 1 a 9 do §11.3 foram conferidos, com o resultado de cada um registrado neste ticket.
- [x] Nenhum alerta do navegador foi disparado. O trabalho foi feito em abas próprias, criadas a partir do contexto do navegador.
- [x] As correções vieram com teste automatizado, e as suítes ficaram verdes de novo.

## Verification

- [x] Emuladores e app parados no fim.
- [x] Todas as suítes verdes depois das correções: `flutter test`, `dart analyze`, Functions (lint e test) e regras.
- [x] Resultado das hipóteses 6 e 8 anotado aqui.
- [x] Bullet no caderno do dia, no mesmo commit, e o ticket em `Status: resolved`.

## Resultado (22/10/2026)

Ambiente: emuladores de Auth, Firestore e Functions, e três instâncias do app (`flutter run -d web-server`) nas portas 8686, 8687 e 8688, uma por conta. Cada porta é uma origem própria no navegador, então A, B e C ficaram logados ao mesmo tempo. A outra origem (`127.0.0.1`) não serve: o servidor de debug do Flutter não inicia o app nela. Os eventos de teste foram criados pela tela, com o início marcado pelo relógio do seletor de horário.

1. **Ok.** A criou "Pelada E2E ao vivo" (15 min, Quadra de Teste) e B entrou.
2. **Ok.** Ao começar, o card AO VIVO apareceu no topo da aba Eventos para A e B, e não para C. C viu o selo "Acontecendo agora" em "Todos".
3. **Ok.** B abriu a tela ao vivo, tocou em "Falar com o organizador" e a DM com A abriu; a mensagem chegou para A, com o badge de não lida.
4. **Ok.** A encerrou, confirmou e caiu na avaliação Local → Participantes. O comentário ficou travado sem estrelas, 2 estrelas sem motivo deixaram "Continuar" desabilitado com o aviso, e o envio deu certo pela callable no emulador.
5. **Ok.** B recebeu a notificação com "1" no sino. O toque abriu Evento → Local → Participantes; depois do envio a notificação foi para "Anteriores" com "Avaliado", e o detalhe mostrou "Você já avaliou".
6. **Ok.** O evento sumiu de "Todos", "Criados por mim", "Participando", da Home e da busca. O detalhe mostrou "Encerrado" e "Nota do evento 5,0 · 1 avaliação". Observação: a lista "Todos" de quem já estava com ela aberta (C) continua mostrando o evento com o selo antigo até recarregar, porque ela é paginada e não é um stream. É o comportamento previsto no ticket 04.
7. **Ok.** O perfil de A mostrou 5,0 (1 avaliação) e a ficha da Quadra de Teste, ★★★ 3,0 (2 avaliações), média do 2 de A e do 4 de B. Nenhum comentário apareceu.
8. **Ok.** A criou "Pelada E2E automatico"; depois do início, a REST gravou `endedAt` e `endedAutomatically`. O gatilho criou a notificação automática. Ao recarregar, A viu o diálogo; "Avaliar" abriu a avaliação só com o passo do local ("Passo 1 de 1", porque não havia outros participantes). Ao recarregar de novo, e depois de sair e entrar, o diálogo não voltou.
9. **Ok.** Login e logout, criar evento, filtros da aba Eventos (chips e estado vazio), chat, editar esportes no perfil e mapa com a ficha do local.

Nenhum alerta do navegador foi disparado; os diálogos são todos do Flutter.

**Hipóteses:**

- **4:** confirmada na prática. `useFunctionsEmulator` funciona na web e a callable respondeu nos dois envios.
- **6:** confirmada. A escrita pela REST com `Bearer owner` disparou o `onEventEnded` no emulador.
- **8:** confirmada. A avaliação abre em tela cheia, sem a barra; o "X" volta para a Home e o "Voltar" do sucesso leva ao detalhe do evento.

**Bug corrigido:** as etiquetas "Organizador" e "Você" (tela ao vivo e passo de participantes) e "Opcional" (passo de participantes) ocupavam a linha inteira. Um `Container` com `alignment` dentro de um `Wrap` estica até a largura máxima, então no celular a etiqueta também virava uma barra. As três cópias viraram a `PillTag` em `lib/shared/widgets/`, que tem a largura do texto. O teste `test/shared/widgets/pill_tag_test.dart` falha com o desenho antigo (400 px) e passa com o novo.

**Suítes depois da correção:** `flutter test` 343 verdes (eram 342 antes do teste novo); `dart analyze` com os 10 avisos da linha de base; Functions com lint limpo e 81 testes verdes; regras com 167 verdes.

**Ambiente, para a próxima vez:**

- O emulador de Functions pode falhar na primeira carga com "Timeout after 10000" ao descobrir as funções, porque o primeiro `require` do código no D: levou 32 s. Depois de aquecido leva menos de 1 s; basta encostar no `functions/lib/src/index.js` para ele recarregar.
- O CLI avisou que as credenciais do `firebase login` expiraram. Os emuladores funcionam assim, mas o deploy do ticket 15 vai pedir `firebase login --reauth`.
- Parar o processo em background não encerra os filhos no Windows; os processos que escutam nas portas precisam ser encerrados à parte.

**Fora do escopo, anotado para decidir depois (já existiam antes da tarefa 14):**

- O formulário de criar evento continua preenchido depois de criar, porque a aba guarda o estado.
- O card de evento na Home mostra "Participar" para todo mundo, inclusive para quem criou o evento; o botão só abre o detalhe.

Commit sugerido: `fix: ...` para cada correção, ou `docs: registra o e2e da tarefa 14` se nada mudar no código.
