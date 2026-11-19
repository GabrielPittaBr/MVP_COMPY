# Issues do Painel do Local (#56–#70)

Abertas no GitHub em 18/11/2026 com a label `painel-do-local`. Abaixo, o texto de cada uma.

---

## #56 · Página do local parceiro: selo, logo, fotos, comodidades, quadras e preços (RF-A01)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/56

## O que construir

Quando um Local Esportivo vira **Local Parceiro** (`partners/{placeId}` ativo), a ficha do local no mapa (`PlaceDetailsSheet`) passa a mostrar o que o local publica pelo painel:

- selo **Parceiro** ao lado do nome;
- logo do local numa plaqueta branca ou, sem logo, o monograma com as iniciais;
- fotos do parceiro, no lugar da galeria do catálogo quando houver;
- comodidades: coberta, iluminação, vestiário, estacionamento, bar, aluguel de material e acessibilidade;
- quadras com modalidades, piso e preço por faixa de horário (ex.: "Dia útil à noite · R$ 90/h");
- WhatsApp, Instagram e a política de cancelamento do local.

Local que não é parceiro, ou parceiro suspenso, continua exatamente como hoje.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A01** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Ler `partners/{placeId}` e `partners/{placeId}/courts` só ao abrir a ficha, nunca para todos os pins do mapa.
- `places/{placeId}` não muda: os dados do parceiro ficam fora do contrato do catálogo, como a média das avaliações em `ratingSummaries`.
- Camadas no padrão do projeto (datasource → repository → use case → provider), com mock e Firestore.
- O selo de acesso (`_PlaceAccessBadge`) e o selo Parceiro usam o mesmo componente em `lib/shared/widgets/` (a #36 já prevê essa extração).
- Textos em `app_strings.dart`.

## Critérios de aceite

- [ ] Local parceiro mostra selo, logo ou monograma, fotos, comodidades, quadras com preços, contatos e política
- [ ] Local não parceiro e parceiro suspenso aparecem como hoje
- [ ] Nenhuma leitura nova na lista do mapa; só ao abrir a ficha
- [ ] Testes de widget da ficha com parceiro, sem parceiro e com parceiro suspenso
- [ ] `flutter test` e `dart analyze` passam
- [ ] Caderno de campo atualizado

## Fora do escopo

- Disponibilidade por quadra: #57.
- Horários livres: #58.
- Solicitar reserva: #59.

## Branch

`feature/pagina-local-parceiro`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- A base do Painel do Local: coleções `partners`, `partners/{placeId}/courts`, `partners/{placeId}/days`, `slotOffers` e `bookings`, com as regras e as Functions de reserva ([documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit)). Ainda sem issue.


---

## #57 · Disponibilidade dos próximos 7 dias por quadra na ficha do local parceiro (RF-A02)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/57

## O que construir

Na ficha do local parceiro entra a **disponibilidade**: o jogador escolhe o dia (hoje e os 6 seguintes) e vê cada quadra com os horários **livres** e **ocupados**, dentro do horário de funcionamento do local. Ocupado não mostra quem reservou nem o motivo. Dia fechado aparece como fechado.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A02** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Fonte: a grade do dia, `partners/{placeId}/days/{aaaa-mm-dd}`, que só tem intervalos e tipos, sem dados pessoais. São no máximo 7 documentos para a semana, lidos só com a ficha aberta.
- Stream apenas do dia escolhido, para a grade atualizar em tempo real enquanto o jogador olha.
- Solicitação pendente aparece como ocupada: ela segura o horário até o local responder.
- Os horários saem do funcionamento e da duração de cada quadra (`courts`). A conta fica numa função pura no domínio, testável sem widget.
- Fuso America/Sao_Paulo, inclusive na virada do dia (o padrão de testes de datas do app vale aqui).

## Critérios de aceite

- [ ] A grade mostra livre e ocupado por quadra, sem dados pessoais
- [ ] Troca de dia funciona para hoje e os 6 dias seguintes, e dia fechado aparece como fechado
- [ ] A grade do dia aberto atualiza em tempo real
- [ ] Testes de unidade do cálculo de horários: funcionamento, duração da quadra, virada de dia e dia fechado
- [ ] Testes de widget da grade
- [ ] `flutter test` e `dart analyze` passam
- [ ] Caderno de campo atualizado

## Fora do escopo

- Reservar um horário: #59.

## Branch

`feature/disponibilidade-local-parceiro`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- A base do Painel do Local: coleções `partners`, `partners/{placeId}/courts`, `partners/{placeId}/days`, `slotOffers` e `bookings`, com as regras e as Functions de reserva ([documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit)). Ainda sem issue.
- #56: a grade entra na ficha do local parceiro.


---

## #58 · Horários livres dos locais parceiros na ficha do local, no mapa e num filtro (RF-A03)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/58

## O que construir

O **Horário Livre** que o local publica pelo painel aparece em três lugares:

1. **Ficha do local**, em destaque acima da disponibilidade: "Hoje, 22h às 23h · Quadra 2 · ~~R$ 90~~ R$ 72".
2. **Mapa**, com o selo "livre hoje" no pin do local.
3. **Filtro** "Com horário livre hoje" na folha de filtros do mapa.

Tocar num horário livre abre a solicitação de reserva (#59).

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A03** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Consulta em `slotOffers` com `status == open`, início entre agora e o fim do dia e, com modalidade filtrada, `sports` em array-contains. O índice composto entra no `firestore.indexes.json`.
- Um listener só para o mapa inteiro, e não um por local.
- O horário livre sai sozinho quando é reservado, bloqueado ou começa (a rotina das Functions tira); o app também esconde pelo horário de início, para não depender do atraso da rotina.
- Preço promocional com o preço normal riscado; sem promoção, só o preço normal.

## Critérios de aceite

- [ ] Horários livres aparecem na ficha, com quadra, horário e preço
- [ ] O pin do local mostra "livre hoje" enquanto houver horário livre aberto no dia
- [ ] O filtro mostra só locais com horário livre hoje e combina com o filtro de modalidade
- [ ] Horário reservado ou já começado some do app
- [ ] Testes de widget da ficha e do filtro, e teste de unidade da regra que esconde horários passados
- [ ] `flutter test` e `dart analyze` passam
- [ ] Caderno de campo atualizado

## Fora do escopo

- Push avisando de horário livre perto do jogador. Pode virar issue depois da #41.

## Branch

`feature/horarios-livres-app`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- A base do Painel do Local: coleções `partners`, `partners/{placeId}/courts`, `partners/{placeId}/days`, `slotOffers` e `bookings`, com as regras e as Functions de reserva ([documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit)). Ainda sem issue.
- #56: o destaque entra na ficha do local parceiro.


---

## #59 · Solicitar reserva de quadra num local parceiro (RF-A04)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/59

## O que construir

A partir de um horário livre (#58) ou de um horário vago na disponibilidade (#57), o jogador toca em **Solicitar reserva** e vê:

- o resumo: local, quadra, data, horário, duração e preço;
- a política de cancelamento do local;
- um campo de telefone **opcional**, com o aceite explícito de compartilhar o número com o local. Nome de exibição e foto sempre vão.

Confirmar cria a reserva como **Solicitada**, que segura o horário até o local responder no painel. O app mostra quanto tempo o local tem para responder (30 min, por padrão).

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A04** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Regras

- Antecedência mínima de 1 h e máxima de 14 dias, ou o que o local definir.
- No máximo 3 solicitações pendentes por jogador.
- Se outra pessoa reservou o mesmo horário um instante antes, aparece "Esse horário acabou de ser reservado" e a disponibilidade atualiza.

## Notas de implementação

- Callable `requestBooking` com App Check, no codebase `administrative` e na região `southamerica-east1`, como as outras. Ela confere as regras acima e grava a reserva e a grade do dia numa única transação.
- Id determinístico para a repetição não duplicar a reserva.
- As regras do Firestore negam escrita direta em `bookings` pelo cliente.
- O app hoje não guarda telefone do jogador (o contato fica protegido), por isso o campo é da solicitação e não do perfil.
- **Decisão pendente:** reservas de contas com 16 e 17 anos (seção de pontos em aberto do documento).

## Critérios de aceite

- [ ] O jogador solicita a partir de um horário livre e de um horário vago da grade
- [ ] Telefone só vai ao local com o aceite marcado
- [ ] Antecedência, limite de 3 pendentes e conflito são recusados com mensagem clara
- [ ] Testes das Functions: duas solicitações simultâneas no mesmo horário gravam só uma; limite de 3; antecedência
- [ ] Testes das regras: o cliente não grava em `bookings` nem na grade do dia
- [ ] Testes de widget da tela de solicitação
- [ ] `flutter test`, `dart analyze`, `npm test --prefix functions` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Fora do escopo

- Acompanhar e cancelar a reserva: #60.
- Avisos de confirmação e recusa: #61.
- Pagamento online, que fica para depois do CNPJ.

## Branch

`feature/solicitar-reserva`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- A base do Painel do Local: coleções `partners`, `partners/{placeId}/courts`, `partners/{placeId}/days`, `slotOffers` e `bookings`, com as regras e as Functions de reserva ([documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit)). Ainda sem issue.
- #57: a solicitação parte da grade de disponibilidade.


---

## #60 · Minhas reservas: solicitadas, confirmadas e passadas, com cancelamento (RF-A05)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/60

## O que construir

O Perfil ganha a entrada **Minhas reservas**, com duas seções:

- **Próximas:** solicitadas e confirmadas, da mais perto para a mais longe.
- **Passadas:** concluídas, recusadas, vencidas, canceladas e faltas.

Cada item mostra a logo do local, a quadra, a data, o horário, o preço e o estado. Uma reserva próxima pode ser **cancelada** dentro da política do local, com motivo opcional. Depois do prazo da política, o app avisa que vale a regra do local antes de confirmar o cancelamento.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A05** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Leitura de `bookings` com `customer.uid == uid`, ordenada por `start` e paginada. O índice composto entra no `firestore.indexes.json`.
- Cancelar chama a Callable `cancelMyBooking`, que libera o horário na grade do dia e avisa o local.
- Exclusão de conta: as reservas futuras são canceladas, com aviso ao local, e as passadas têm nome e telefone apagados. Entra no `account_cleanup.ts` e na exportação de dados (`data_export.ts`).

## Critérios de aceite

- [ ] As duas seções listam as reservas certas, na ordem certa
- [ ] Cancelar dentro da política libera o horário e avisa o local
- [ ] Depois do prazo, o aviso da política aparece antes de cancelar
- [ ] Excluir a conta cancela as futuras e anonimiza as passadas
- [ ] Testes das regras: o jogador só lê as próprias reservas
- [ ] Testes de widget da lista e do cancelamento; testes da Function
- [ ] `flutter test`, `dart analyze`, `npm test --prefix functions` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Branch

`feature/minhas-reservas`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #59: só há reservas depois da solicitação.


---

## #61 · Notificações de reserva na central: confirmada, recusada, vencida e cancelada pelo local (RF-A06)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/61

## O que construir

A central de notificações ganha os avisos de reserva:

- **Reserva confirmada:** "{local} confirmou sua reserva de qui., 21/11, às 22h".
- **Reserva recusada**, com o motivo escolhido pelo local.
- **Reserva vencida:** o local não respondeu no prazo e o horário foi liberado.
- **Reserva cancelada pelo local**, com o motivo.

Tocar no aviso abre a reserva em Minhas reservas (#60).

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A06** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Novos valores em `AppNotificationType` (hoje `eventEnded` e `eventCancelled`): `bookingConfirmed`, `bookingRejected`, `bookingExpired` e `bookingCancelledByVenue`.
- Gatilho `onDocumentUpdated` em `bookings/{bookingId}` quando o estado muda, com id determinístico `{tipo}_{bookingId}`, no mesmo padrão de `eventEnded_{eventId}` (`event_notifications.ts`). Usar `create`, nunca `set`, para a reentrega não zerar o `readAt`.
- O texto continua montado no app pelo `NotificationText`.
- Com a #41, estes avisos saem por push sem nada a mais, porque são avisos da central.

## Critérios de aceite

- [ ] Cada mudança de estado gera um único aviso, mesmo com reentrega do gatilho
- [ ] Os textos de cada tipo, com e sem motivo, são montados no app e testados
- [ ] Tocar no aviso abre a reserva
- [ ] Testes da Function e das regras de `notifications` com os tipos novos
- [ ] `flutter test`, `dart analyze`, `npm test --prefix functions` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Relacionada

- #41: push dos avisos da central.

## Branch

`feature/notificacoes-reserva`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #59: os avisos dependem das reservas existirem.


---

## #62 · Evento do Local nas listas e no mapa, com selo do local e valor por pessoa (RF-A07)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/62

## O que construir

O **Evento do Local** é um Evento Esportivo criado pela equipe do local, pelo painel, num horário livre: por exemplo, beach tennis, intermediário, 4 vagas, R$ 20 por pessoa, mínimo de 4. Ele serve para o local preencher horário vazio com jogadores avulsos, o que hoje o atendente faz chamando clientes um por um.

No app, ele aparece na aba Eventos, na Início e no mapa como os outros eventos, com:

- a logo e o nome do local no lugar do Organizador;
- o valor por pessoa;
- "Confirma com 4 participantes até 19h" e o estado (aguardando o mínimo ou confirmado).

Entrar e sair seguem as regras de vagas de hoje. Se o mínimo não for atingido no prazo, o evento é cancelado e os inscritos recebem o aviso na central.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A07** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Hoje o `creator` (`UserSummary`) do `Event` é obrigatório. O modelo precisa aceitar um Organizador do tipo local (ex.: `organizer: {type: 'venue', placeId}`). Registrar a escolha numa ADR, porque mexe nas regras de `events`, nas listas e nas avaliações.
- O `CONTEXT.md` muda: o Organizador pode ser um Local Parceiro.
- O local não avalia o próprio evento; os participantes avaliam o evento e o local.
- A criação (`createVenueEvent`) é do Painel do Local e fica fora desta issue.

## Critérios de aceite

- [ ] Evento do Local aparece nas listas, na Início e no mapa com o selo do local e o valor por pessoa
- [ ] O estado do mínimo aparece e muda para confirmado quando atingido
- [ ] Cancelado por falta de mínimo, os inscritos recebem o aviso
- [ ] ADR e `CONTEXT.md` atualizados
- [ ] Testes de widget dos cards e do detalhe; testes das regras de `events` com Organizador local
- [ ] `flutter test`, `dart analyze` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Branch

`feature/evento-do-local-app`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- A base do Painel do Local: coleções `partners`, `partners/{placeId}/courts`, `partners/{placeId}/days`, `slotOffers` e `bookings`, com as regras e as Functions de reserva ([documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit)). Ainda sem issue.
- A criação do Evento do Local no Painel do Local (`createVenueEvent`).


---

## #63 · Pedir a quadra ao criar evento num local parceiro (RF-A08)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/63

## O que construir

Na criação de evento, quando o local escolhido é parceiro, aparece a opção **Reservar a quadra também**: o organizador escolhe a quadra na grade daquele dia e vê o preço. Criar o evento envia junto a solicitação de reserva, ligada ao evento.

Enquanto o local não responde, o evento mostra o selo **Aguardando o local**. Se a solicitação for recusada ou vencer, o evento é cancelado e os inscritos recebem o aviso, para ninguém aparecer numa quadra ocupada.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A08** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Entra na etapa de local da criação em etapas (#45).
- Reaproveita a `requestBooking` da #59, com o `eventId` na reserva.
- Horário e duração do evento definem o horário da reserva; se não couberem na grade, a opção fica desabilitada com o motivo.

## Critérios de aceite

- [ ] Local parceiro oferece reservar a quadra na criação do evento
- [ ] O evento fica "Aguardando o local" até a resposta
- [ ] Recusa ou vencimento cancelam o evento e avisam os inscritos
- [ ] Testes de widget da etapa e testes da Function com `eventId`
- [ ] `flutter test`, `dart analyze` e `npm test --prefix functions` passam
- [ ] Caderno de campo atualizado

## Relacionada

- #43: o aviso do local público pode sugerir um local parceiro com horário livre.

## Branch

`feature/evento-com-quadra`, a partir de `develop` depois do merge da #45. PR para `develop`.

## Bloqueado por

- #59: a solicitação de reserva.
- #45: a criação de evento em etapas.


---

## #64 · Lembrete por push antes do horário da reserva (RF-A09)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/64

## O que construir

Duas horas antes de uma reserva confirmada, ou de um Evento do Local confirmado, o jogador recebe o lembrete: "Sua quadra no {local} é hoje às 22h". Tocar abre a reserva.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A09** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- A rotina das Functions que roda a cada 10 min (a mesma que vence solicitações) acha as reservas que começam entre 2 h e 2 h 10 min dali e cria o aviso `bookingReminder` na central, com id determinístico por reserva.
- O push sai pela #41, respeitando o switch **Eventos** das Configurações.

## Critérios de aceite

- [ ] Cada reserva confirmada gera um único lembrete, cerca de 2 h antes
- [ ] Reserva cancelada antes do horário não gera lembrete
- [ ] Testes da rotina: janela de horário, reserva cancelada e repetição
- [ ] `npm test --prefix functions` passa
- [ ] Caderno de campo atualizado

## Branch

`feature/lembrete-reserva`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #41: push das notificações.
- #61: tipos de aviso de reserva na central.


---

## #65 · Avaliar o local depois de uma reserva concluída (RF-A10)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/65

## O que construir

Quando uma reserva fica **Concluída**, o jogador recebe na central "Como foi no {local}?" e avalia o local com 1 a 5 estrelas e comentário opcional, que nunca é público. A nota entra na média do local, que já aparece na ficha do mapa.

Falta, recusa, vencimento e cancelamento não geram convite para avaliar.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-A10** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Reaproveita a Avaliação que já existe (`RatingTargetType.place` e `ratingSummaries/place_{id}`).
- A Callable de avaliação passa a aceitar uma reserva como origem (hoje só aceita evento), com uma avaliação por reserva.
- Regras e testes ajustados para a nova origem.

## Critérios de aceite

- [ ] Reserva concluída gera o convite; os outros estados não
- [ ] Uma avaliação por reserva, e a média do local atualiza
- [ ] Testes da Function e das regras
- [ ] `flutter test`, `dart analyze`, `npm test --prefix functions` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Branch

`feature/avaliar-local-reserva`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #60: Minhas reservas.
- #61: avisos de reserva na central.


---

## #66 · Painel admin: tornar um local privado em Local Parceiro e convidar o primeiro Proprietário (RF-AD01)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/66

## O que construir

Na página de um local (`/places/:id`), os locais **privados e ativos** ganham a seção **Parceria** com o botão **Tornar parceiro**. O diálogo pede:

- nome de exibição inicial (vem preenchido com o nome do local);
- início do período gratuito, que dura no máximo 3 meses;
- e-mail do Proprietário, opcional, só para registro.

Confirmar cria o parceiro e um **convite de Proprietário**. O painel mostra o link e o QR do convite, para enviar pelo WhatsApp ou mostrar na visita ao local. Dá para gerar um convite novo e revogar o atual.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-AD01** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Callable `createPartner` com Admin SDK, no codebase `administrative` e na região `southamerica-east1`, com App Check, como a `deleteEvent`. Só a claim `admin` chama.
- Ela cria `partners/{placeId}` (estado ativo e tema automático pela `primarySport`), `partners/{placeId}/private/billing` (plano piloto e fim do período gratuito) e o convite em `partnerInvites`, com validade de 7 dias e uso único.
- Esta issue define, junto com a base do Painel do Local, o contrato de `partners` e `partnerInvites`.
- As regras negam ao cliente criar `partners`, `billing` e convites.
- Textos em `AdminStrings`.

## Critérios de aceite

- [ ] Só locais privados e ativos mostram "Tornar parceiro"
- [ ] O parceiro e o convite são criados, e o link e o QR aparecem
- [ ] Gerar de novo revoga o convite anterior
- [ ] O período gratuito não passa de 3 meses
- [ ] Testes da Function (só admin, local público recusado, convite revogado) e das regras
- [ ] `flutter test` em `admin/`, `npm test --prefix functions` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Branch

`feature/admin-tornar-parceiro`, a partir de `develop`. PR para `develop`.

## Bloqueado por

Nenhuma issue. O contrato de `partners` sai daqui.


---

## #67 · Painel admin: lista de locais parceiros com plano, período gratuito e membros (RF-AD02)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/67

## O que construir

O menu do painel ganha **Parceiros** (`/partners`), com a lista dos locais parceiros:

- logo e nome;
- plano (piloto, Vitrine ou Pro) e fim do período gratuito, com alerta quando faltam 15 dias ou menos;
- quadras ativas e a faixa de preço que elas definem (1 quadra: R$ 49; 2 a 3: R$ 99; 4 a 5: R$ 149; acima de 5: R$ 20 por quadra a mais);
- membros (Proprietário e quantidade de atendentes) e convites pendentes;
- estado (ativo ou suspenso) e última atividade.

O detalhe (`/partners/:id`) mostra os membros, os convites e o resumo da atividade. O Dashboard ganha o número de parceiros ativos.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-AD02** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Leitura de `partners`, `private/billing` e `members`, que as regras liberam para o Administrador.
- A última atividade vem de um campo `lastActivityAt`, mantido pela Function que grava o histórico de atividades do painel, para a lista não ler o histórico inteiro.
- Rotas novas no `admin_router.dart`, pelo mesmo guard das outras.

## Critérios de aceite

- [ ] A lista mostra plano, período gratuito, quadras e faixa, membros, estado e última atividade
- [ ] O alerta aparece com 15 dias ou menos de período gratuito
- [ ] O detalhe abre por link direto e sobrevive ao recarregar a página
- [ ] Testes de widget da lista e do detalhe
- [ ] `flutter test` em `admin/` passa
- [ ] Caderno de campo atualizado

## Branch

`feature/admin-lista-parceiros`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #66: a criação dos parceiros.


---

## #68 · Painel admin: suspender e reativar o Painel do Local de um parceiro (RF-AD03)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/68

## O que construir

No detalhe do parceiro, **Suspender painel**, com motivo obrigatório e confirmação, como nas exclusões; e **Reativar**.

Com o painel suspenso:

- os horários livres saem do app;
- as solicitações pendentes são recusadas, com aviso ao jogador;
- as reservas confirmadas continuam valendo e visíveis para o jogador;
- a equipe do local não consegue mais escrever no painel.

Reativar volta tudo, menos as solicitações que já foram recusadas.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-AD03** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Callable `setPartnerStatus`, no mesmo padrão da `setUserSuspension`: grava o estado, o motivo, a data e quem fez.
- As regras do Firestore conferem o estado do parceiro antes de aceitar escritas da equipe.
- O aviso ao jogador usa o tipo de recusa da #61.

## Critérios de aceite

- [ ] Suspender pede motivo e confirmação, e reativar volta o painel
- [ ] Suspenso, os horários livres somem do app e as pendentes são recusadas com aviso
- [ ] Reservas confirmadas continuam
- [ ] Testes da Function e das regras (equipe de local suspenso não escreve)
- [ ] `flutter test` em `admin/`, `npm test --prefix functions` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Branch

`feature/admin-suspender-parceiro`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #67: o detalhe do parceiro.
- #61: o aviso de recusa ao jogador.


---

## #69 · Painel admin: fila de pedidos de alteração de endereço e modalidades vindos do Painel do Local (RF-AD04)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/69

## O que construir

No Painel do Local, endereço, coordenadas e modalidades são só leitura, porque o catálogo continua com a curadoria do COMPY. O local pede a mudança pelo botão **Pedir alteração**.

No painel admin entra a fila **Pedidos dos parceiros** (`/partners/requests`), com o pedido, o local e quem pediu. **Aceitar** abre o formulário do local já com a mudança preenchida; **Recusar** pede um motivo. O local vê o resultado na central do painel.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-AD04** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Pedidos em `partnerChangeRequests`, criados por Function a partir do painel do local.
- A fila segue o padrão da fila de Denúncias (`/reports`).
- Aceitar não grava nada sozinho: a mudança passa pelo formulário de local, que já valida o contrato de `places`.

## Critérios de aceite

- [ ] Os pedidos aparecem na fila, do mais antigo para o mais novo
- [ ] Aceitar abre o formulário preenchido; recusar pede motivo
- [ ] O local recebe o resultado
- [ ] Testes de widget da fila e testes das regras de `partnerChangeRequests`
- [ ] `flutter test` em `admin/` e `npm test --prefix tools/firestore-rules-tests` passam
- [ ] Caderno de campo atualizado

## Branch

`feature/admin-pedidos-parceiros`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #67: a seção Parceiros do painel.
- O botão "Pedir alteração" no Painel do Local.


---

## #70 · Painel admin: métricas dos parceiros, com horários publicados, preenchidos e tempo de resposta (RF-AD05)

https://github.com/GabrielPittaBr/MVP_COMPY/issues/70

## O que construir

O Dashboard e o detalhe de cada parceiro ganham as métricas do mês:

- horários livres publicados e quantos foram preenchidos pelo COMPY;
- reservas por origem (app, horário livre, Evento do Local, manual e externo) e jogadores novos trazidos;
- horas e valor recuperados;
- tempo médio de resposta às solicitações e porcentagem de solicitações vencidas.

São o argumento de renovação do plano de negócios e a base do relatório mensal entregue ao dono.

Faz parte da integração com o **Painel do Local**, a plataforma web em que os locais parceiros publicam horários livres e confirmam reservas. Requisito **RF-AD05** do [documento de requisitos](https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit).

## Notas de implementação

- Agregados mensais em `partners/{placeId}/stats/{aaaa-mm}`, mantidos por Function a cada mudança de reserva, para o painel não contar reservas no cliente.
- Toda reserva já grava a origem e se o jogador é novo no local, desde o MVP.

## Critérios de aceite

- [ ] As métricas aparecem no Dashboard (todos os parceiros) e no detalhe (um parceiro), por mês
- [ ] Os números batem com as reservas do mês num teste com dados de exemplo
- [ ] Testes da Function de agregação
- [ ] `flutter test` em `admin/` e `npm test --prefix functions` passam
- [ ] Caderno de campo atualizado

## Branch

`feature/admin-metricas-parceiros`, a partir de `develop`. PR para `develop`.

## Bloqueado por

- #67: o detalhe do parceiro.

