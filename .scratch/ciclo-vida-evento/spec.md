# Tarefa 14: ciclo de vida do evento + central de notificações

A spec é o plano de execução `docs/tarefa-14-ciclo-de-vida-do-evento.md`. Este arquivo não repete o conteúdo dele: só aponta para o plano e registra a quebra final em tickets, aprovada pelo usuário em 21/10/2026.

## Tickets

Trabalhe pela fronteira: o primeiro ticket aberto cujos bloqueadores estão todos `resolved`.

| # | Ticket | Bloqueado por |
|---|---|---|
| 01 | Desenhar as telas do ciclo de vida no Claude Design (parada para o usuário) | — |
| 02 | Avatar de Usuário compartilhado | — |
| 03 | Status derivado do evento (agendado, acontecendo, encerrado) | — |
| 04 | Eventos encerrados somem das listas e não aceitam mais participantes | 03 |
| 05 | Encerramento automático de eventos esquecidos | — |
| 06 | Selo "Acontecendo agora" e CTA do detalhe por status | 01, 03 |
| 07 | Card e tela do evento ao vivo | 01, 02, 04, 06 |
| 08 | Criador encerra o evento | 07 |
| 09 | Avaliar o evento e o Local Esportivo | 01, 08 |
| 10 | Avaliar quem jogou (passo Participantes) | 09 |
| 11 | Central de notificações com o convite para avaliar | 01, 08, 09 |
| 12 | Aviso único ao criador de encerramento automático | 11 |
| 13 | Médias reais no perfil, no Local Esportivo e no evento encerrado | 01, 09 |
| 14 | E2E no Chrome com emuladores | 02 a 13 |
| 15 | Fechamento: documentação, merge e deploy | 14 |

Enquanto o design (01) espera o ok do usuário, os tickets 02 a 05 podem andar, porque não mudam o visual.

## Numeração do plano (§10) para os tickets

| Plano §10 | Tickets |
|---|---|
| Fase 1 (design) | 01 |
| — (prefactor novo) | 02 |
| 01 Status do evento | 03 |
| 02 Listas sem encerrados e selo | 04 (listas e join) e 06 (selo e CTA do detalhe) |
| 03 Evento ao vivo e encerrar | 07 (card e tela) e 08 (encerrar) |
| 04 Encerramento automático | 05 |
| 05 Central de notificações | 11 (central) e 12 (diálogo único) |
| 06 Avaliação | 09 (evento e local) e 10 (participantes) |
| 07 Médias reais | 13 |
| 08 Fechamento | 14 (E2E) e 15 (docs, merge e deploy) |

## O que mudou em relação ao §10, e por quê

- **A avaliação vem antes da central de notificações.** No plano, encerrar e tocar na notificação levavam a `/avaliacao/:id` antes de a rota existir. Agora a notificação já nasce levando à avaliação. A callable ganha a marcação de "Avaliado" na notificação só no ticket 11, porque ela já tolerava a notificação ausente.
- **Dependências que não eram reais saíram:** a Function do encerramento automático não depende do domínio Dart (é só TypeScript), e a central não depende dela (o gatilho cobre os dois encerramentos, e no E2E o automático é simulado pela REST).
- **Os tickets grandes foram divididos em fatias verticais**, cada uma verde e verificável sozinha: listas e selo; ver ao vivo e encerrar; avaliar evento e local e avaliar quem jogou; central e diálogo; E2E e fechamento.
- **O widget de estrelas** nasce no 09, em modo de entrada, porque a tela de avaliação precisa dele; o modo de exibição entra no 13.
- **A tabela de CTA do §8.4** foi distribuída: cada um dos tickets 06, 07, 09 e 13 diz quais linhas entrega.
- **As hipóteses do §13** estão dentro do ticket em que precisam ser conferidas.
