# COMPY para Locais: requisitos da plataforma dos gestores

Nov 18, 2026 · @Gabriel Fernandes Pitta

## 1. Resumo e decisões principais

O COMPY para Locais é o produto para os locais parceiros. A interface dele, o Painel do Local, é um app web, instalável no celular, em que a equipe de cada local parceiro publica horários livres, recebe as reservas que vêm do COMPY e organiza a agenda das quadras. O foco é o que os sistemas de agenda não fazem: trazer jogador novo para horário vazio.

| Tema | Decisão | Por quê |
| --- | --- | --- |
| Para quem | Locais esportivos privados parceiros: proprietário e funcionários | No L01, quem opera é o atendente e quem decide a compra é o dono |
| Foco do MVP | Horários livres publicados, solicitações vindas do app e agenda mínima sem conflito | O L01 já paga um sistema de agenda; nenhum desses sistemas traz demanda nova |
| Convivência | Funciona ao lado do sistema que o local já usa; migrar a agenda inteira é opcional | Trocar o que já funciona é o maior risco de venda apontado no plano de negócios |
| Perfis | Proprietário (tudo) e Atendente (só horários e reservas) no MVP; Gerente (opera e configura) na v2 | Pedido da equipe e papel do atendente no L01 |
| Tecnologia | Flutter Web como PWA, com a arquitetura do painel admin (Riverpod, GoRouter, Material 3) | A equipe já domina; o mesmo código pode virar app Android depois |
| Repositório | Mesmo repositório (`MVP_COMPY`), que passa a ser privado quando o painel começar; pasta nova `gestor/`, separada de `admin/` e do app | Regras, índices e Functions são compartilhados e publicados juntos |
| Hospedagem | Firebase Hosting, terceiro site do projeto `compy-tcc`; depois, domínio próprio | Mesmo Auth, App Check e Functions; o runbook de deploy já existe |
| Visual | Base do painel admin, com tema por modalidade (areia, padel, campo, saibro, ginásio ou quadra) e a logo do local | Pedido da equipe, mantendo o contraste AA que o admin já testa |
| Celular primeiro | Telas a partir de 360 px, com barra inferior; no computador, barra lateral | No L01, o celular é o aparelho do atendimento |

Códigos usados: RF-P (painel), RF-A (app), RF-AD (painel admin) e RNF (não funcional). O documento vale para a fase B6 do plano de etapas (jan.–abr. 2027) e deve ser revisto depois das entrevistas L02 a L08.

## 2. O que a entrevista L01 mostrou e o que muda no painel

A L01 (29/10/2026) é um caso só: uma arena coberta de esportes de areia com 5 quadras, ouvida pelo atendente que cuida das reservas. Cada achado abaixo virou requisito, mas precisa ser confirmado nas entrevistas L02 a L08.

| Achado no L01 | O que muda no painel | Requisitos |
| --- | --- | --- |
| Quem atendeu cuida das reservas, mas não decide a contratação; quem decide é o proprietário | Dois públicos: o atendente usa todo dia; o dono configura, acompanha o resultado e paga | Seção 4, RF-P06, RF-P13 |
| As reservas chegam pelo app de um sistema contratado (link no Instagram) e pelo WhatsApp, que o atendente lança à mão | O painel convive com outro sistema e registra uma reserva manual em segundos | RF-P21, RF-P24, RF-P33 |
| O celular é o aparelho mais usado no atendimento | Celular primeiro, instalável na tela inicial, com aviso de nova solicitação | RNF-01, RNF-02, RF-P81 |
| O local já paga um sistema de gestão, cerca de R$ 180 por mês pela tabela pública do fornecedor | Há orçamento, mas não para mais uma agenda: o valor do painel é demanda nova | Seção 3, RF-P40, RF-P45 |
| Não há parte difícil; o maior trabalho é físico, como regar a areia | Nada de manutenção no escopo; telas curtas e sem burocracia; bloqueio rápido para manutenção | Seção 3, RF-P23 |
| Das 22h às 23h e nas quintas sobram até 2 quadras: ao menos 4 h vazias por semana, cerca de R$ 1.440 por mês a R$ 90 a hora | Publicar horários livres, inclusive recorrentes, e mostrar quanto o COMPY recuperou | RF-P40 a RF-P45, RF-P72 |
| Quando não há jogo marcado, o atendente chama clientes para jogar | Evento do Local: abrir vagas num horário vazio para jogadores avulsos do COMPY | RF-P46 a RF-P48 |
| Cancelamentos são raros; a 1ª falta sem aviso gera advertência e a 2ª cobra o horário | Registrar falta, mostrar o histórico do cliente e deixar a política configurável | RF-P27, RF-P28, RF-P54 |
| Cerca de 90% dos clientes novos chegam pelo Instagram; o local divulga torneios, mas nunca horários livres | Gerar imagem dos horários livres para stories e feed, com logo e link do COMPY | RF-P49 |
| Não houve relato de inadimplência | Pagamento online não é urgente e fica para depois do CNPJ | Seção 12 |

Ainda falta saber se locais sem sistema de reservas precisam da agenda completa, o que o dono quer ver e quanto pagaria, se society e padel têm a mesma ociosidade e se há computador na recepção.

## 3. Escopo e princípios

O painel tem um trabalho principal, transformar horário vazio em reserva, e o resto existe para apoiá-lo sem dar trabalho ao atendente.

**O painel faz**

- Mostra e organiza a agenda das quadras do dia e da semana.
- Recebe, confirma e recusa reservas pedidas pelo app COMPY.
- Publica horários livres, com preço promocional opcional, para os jogadores do COMPY.
- Registra reservas feitas por WhatsApp, telefone ou no balcão, além de bloqueios.
- Mantém o perfil do local no app: fotos, logo, contatos, quadras, preços e regras.
- Gerencia a equipe e as permissões de cada pessoa.

**O painel não faz, por enquanto**

- Cobrança online, Pix, divisão de pagamento ou controle financeiro (depois do CNPJ, seção 12).
- Gestão de bar, estoque, aulas, professores ou campeonatos completos.
- Integração automática com outros sistemas de agenda, que depende de o fornecedor ter API.
- Alteração de endereço, coordenadas e modalidades do catálogo, que continuam com a curadoria do COMPY no painel admin.

**Princípios de desenho**

1. Celular primeiro: tudo que o atendente faz no dia a dia funciona com uma mão, numa tela de 360 px.
2. Três toques: confirmar uma solicitação, registrar uma reserva e publicar um horário livre levam no máximo três toques depois de abrir o painel.
3. Convivência: o local escolhe o que publica, e nada exige migrar a agenda inteira para o COMPY.
4. Resultado visível: toda reserva guarda a origem, para o dono ver quanto o COMPY trouxe.
5. Linguagem do local: “reserva”, “horário livre” e “quadra”, nunca termos técnicos.
6. O local é a marca: logo e tema do local na frente; o COMPY aparece discreto, com um selo “com COMPY”.
7. Nada some sem rastro: cancelamentos e remoções pedem motivo e ficam no histórico, como no painel admin.

## 4. Perfis de acesso e permissões

Cada local tem três papéis, Proprietário, Gerente e Atendente, e cada pessoa entra com a própria conta, nunca com um login compartilhado.

- **Proprietário:** dono ou sócio. Pode tudo, inclusive equipe, plano e dados do local. Todo local tem pelo menos um.
- **Gerente:** quem administra no dia a dia. Configura quadras, preços e perfil e vê relatórios, mas não mexe na equipe nem no plano e não convida Atendentes. Entra só na v2; no MVP, o Proprietário faz esse papel.
- **Atendente:** funcionário da recepção. Só cuida de horários e reservas, dentro dos preços e regras definidos.
- **Administrador COMPY:** a equipe do COMPY, pelo painel admin. Cria o local parceiro, convida o primeiro proprietário e suspende o acesso, mas não mexe nas reservas.

| Ação | Proprietário | Gerente | Atendente |
| --- | --- | --- | --- |
| Ver agenda, solicitações e horários livres | ✓ | ✓ | ✓ |
| Criar, mover e cancelar reservas | ✓ | ✓ | ✓ |
| Confirmar ou recusar solicitações do app | ✓ | ✓ | ✓ |
| Bloquear horário e marcar como ocupado | ✓ | ✓ | ✓ |
| Marcar falta ou reserva concluída | ✓ | ✓ | ✓ |
| Publicar horário livre e criar Evento do Local | ✓ | ✓ | ✓ |
| Dar desconto em horário livre ou reserva | Qualquer valor | Até o limite | Até o limite |
| Editar perfil, fotos, logo e tema | ✓ | ✓ | — |
| Cadastrar quadras, preços e horário de funcionamento | ✓ | ✓ | — |
| Definir políticas: cancelamento, faltas, prazo de resposta e modo de confirmação | ✓ | ✓ | — |
| Ver relatórios, receita e histórico de atividades | ✓ | ✓ | — |
| Convidar, remover e mudar o papel de membros | ✓ | — | — |
| Transferir a propriedade | ✓ | — | — |
| Ver o plano, o período gratuito e os dados de cobrança | ✓ | — | — |
| Exportar dados ou pedir a desativação do local | ✓ | — | — |

O limite de desconto é definido pelo Proprietário (por exemplo, até 20%). O Atendente vê o preço de cada reserva, porque informa o cliente, mas não vê receita nem relatórios.

**Regras da equipe**

1. Conta individual: cada membro entra com Google ou com e-mail e senha verificado. A mesma conta pode ser de jogador no app.
2. Convite: o Proprietário gera um link ou QR com o papel escolhido. Vale por 7 dias, é de uso único e pode ser revogado.
3. Remoção imediata: as regras do Firestore conferem o papel em cada leitura e escrita, sem depender de claim no token. Quem sai da equipe perde o acesso na ação seguinte.
4. Sempre há um Proprietário: o último não sai nem é rebaixado sem antes transferir a propriedade.
5. Vários locais: uma pessoa pode estar em mais de um local, com papéis diferentes, e escolhe qual abrir depois do login.
6. Rastro: toda escrita grava quem fez e quando, e o histórico aparece para Proprietário e Gerente.
7. Primeiro acesso: o Administrador COMPY convida o primeiro Proprietário depois de verificar o local, na visita presencial que a equipe já faz.
8. Aparelho da recepção: se for compartilhado, cada atendente usa a própria conta, e o topo do painel mostra quem está conectado.

## 5. Funcionalidades do painel

São 64 requisitos em 10 módulos; os 38 do MVP fecham o ciclo “publicar horário livre, jogador solicita, local confirma” com uma agenda mínima sem conflito. A prioridade de cada linha pode ser trocada no próprio documento.

Quem: P = Proprietário, G = Gerente, A = Atendente, Todos = os três, Sistema = regra automática. Prioridade: MVP = teste gratuito (B8); v2 = antes do local piloto (B12); Futuro = depois do CNPJ ou quando houver demanda.

### A. Acesso e equipe

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P01 | Entrar com Google ou com e-mail e senha verificado; sem cadastro aberto, só por convite | Todos | MVP |
| RF-P02 | Convite por link ou QR com papel definido, validade de 7 dias e uso único, revogável | P | MVP |
| RF-P03 | Escolher o local depois do login, para quem pertence a mais de um | Todos | MVP |
| RF-P04 | Equipe: listar membros, mudar papel, remover com efeito imediato e transferir a propriedade | P | MVP |
| RF-P05 | Sair de todos os aparelhos, pelo próprio membro ou pelo Proprietário | P | v2 |
| RF-P06 | Primeiro acesso guiado: dados, logo, tema, quadras, preços, horários e convite da equipe, em até 15 min | P | MVP |
| RF-P07 | Histórico de atividades: quem criou, mudou ou cancelou o quê, e quando | P · G | v2 |

### B. Hoje (tela inicial)

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P10 | Grade do dia: quadras × horários, com livre, solicitado, reservado e bloqueado | Todos | MVP |
| RF-P11 | Solicitações pendentes no topo, com o tempo que falta para vencer | Todos | MVP |
| RF-P12 | Atalho “Publicar horários livres de hoje” a partir da grade | Todos | MVP |
| RF-P13 | Resumo da semana: ocupação, reservas vindas do COMPY e horas recuperadas | P · G | v2 |

### C. Agenda e reservas

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P20 | Agenda do dia com as quadras em colunas, em lista no celular; semana no computador | Todos | MVP |
| RF-P21 | Reserva manual (WhatsApp, telefone, balcão) em até 30 s: quadra, horário, duração, nome, telefone opcional e preço da tabela | Todos | MVP |
| RF-P22 | Editar, mover e cancelar com motivo; se a reserva veio do app, o jogador é avisado | Todos | MVP |
| RF-P23 | Bloqueio com motivo (manutenção, chuva, aula, evento interno), inclusive do dia inteiro | Todos | MVP |
| RF-P24 | “Marcar como ocupado” em um toque, sem dados do cliente, para quem usa outro sistema | Todos | MVP |
| RF-P25 | Reserva fixa semanal (mensalista), com data de fim e exceções | Todos | v2 |
| RF-P26 | Sem conflito: duas reservas ou bloqueios nunca ocupam a mesma quadra no mesmo horário, conferido no servidor | Sistema | MVP |
| RF-P27 | Marcar falta ou reserva concluída depois do horário | Todos | MVP |
| RF-P28 | Histórico do cliente no local: reservas, faltas e cancelamentos | Todos | v2 |
| RF-P29 | Buscar reserva por nome ou telefone | Todos | v2 |

### D. Solicitações vindas do app

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P30 | Lista de solicitações com nome e foto do jogador, quadra, horário e valor | Todos | MVP |
| RF-P31 | Confirmar ou recusar em um toque; a recusa pede um motivo de uma lista curta | Todos | MVP |
| RF-P32 | Prazo de resposta configurável, de 30 min por padrão e nunca depois do início; vencido, recusa automática com aviso ao jogador | P · G | MVP |
| RF-P33 | Modo de confirmação: manual (padrão, para quem tem outro sistema) ou automático (para quem usa só o COMPY) | P · G | MVP |
| RF-P34 | Antecedência para reservar: mínima (ex.: 1 h) e máxima (ex.: 14 dias) | P · G | MVP |

### E. Horários livres e Evento do Local

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P40 | Publicar horário livre no app: quadra, horário, preço normal e preço promocional opcional | Todos | MVP |
| RF-P41 | Limite de desconto definido pelo Proprietário; Gerente e Atendente publicam dentro dele | P | MVP |
| RF-P42 | Publicação recorrente (ex.: toda quinta, das 22h às 23h), com data de fim | Todos | v2 |
| RF-P43 | Retirar a publicação; ela também sai sozinha quando o horário é reservado, bloqueado ou começa | Todos | MVP |
| RF-P44 | Sugestão de horários para publicar, a partir da ociosidade das últimas semanas | Todos | Futuro |
| RF-P45 | Contador “horas recuperadas pelo COMPY neste mês” na tela Hoje | Todos | MVP |
| RF-P46 | Criar Evento do Local num horário livre: modalidade, nível, vagas, valor por pessoa e mínimo para confirmar | Todos | v2 |
| RF-P47 | Prazo para atingir o mínimo: atingiu, vira reserva confirmada; não atingiu, cancela e avisa os inscritos | Sistema | v2 |
| RF-P48 | Ver os inscritos no Evento do Local | Todos | v2 |
| RF-P49 | Compartilhar horários livres em imagem para stories (1080 × 1920) e feed (1080 × 1350), com logo, tema e link ou QR do COMPY | Todos | v2 |

### F. Perfil do local e visual

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P50 | Nome de exibição, descrição, até 8 fotos, WhatsApp e Instagram | P · G | MVP |
| RF-P51 | Logo em PNG, JPG ou WebP, até 2 MB, com recorte quadrado; sem logo, monograma | P · G | MVP |
| RF-P52 | Tema automático pela modalidade principal ou escolhido na lista, com pré-visualização | P · G | MVP |
| RF-P53 | Comodidades: coberta, iluminação, vestiário, estacionamento, bar, aluguel de material e acessibilidade | P · G | v2 |
| RF-P54 | Políticas: cancelamento sem custo até X horas antes, regra de faltas e regras da casa | P · G | MVP |
| RF-P55 | Ver o local como o jogador vê no app | P · G | v2 |
| RF-P56 | Endereço, coordenadas e modalidades do catálogo só para leitura, com botão para pedir alteração ao COMPY | P · G | MVP |

### G. Quadras, preços e funcionamento

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P60 | Quadras: nome, modalidades, piso (areia, sintético, saibro, cimento, madeira, grama), coberta, iluminação e ordem | P · G | MVP |
| RF-P61 | Estado da quadra: ativa, em manutenção (bloqueia a agenda) ou inativa (preservada no histórico) | P · G | MVP |
| RF-P62 | Horário de funcionamento por dia da semana | P · G | MVP |
| RF-P63 | Tabela de preços por quadra, dia da semana e faixa de horário (ex.: dia útil até 18h, dia útil à noite, fim de semana) | P · G | MVP |
| RF-P64 | Duração do horário: 60 min por padrão; 30, 90 ou 120 min como opção por quadra | P · G | MVP |
| RF-P65 | Exceções: feriados, dias fechados e horário especial; no MVP, o bloqueio do dia inteiro cobre o fechamento | P · G | v2 |
| RF-P66 | Intervalo opcional entre reservas (ex.: 10 min para preparar a quadra) | P · G | v2 |

### H. Relatórios

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P70 | Ocupação por quadra, dia e hora, num mapa de calor semanal | P · G | v2 |
| RF-P71 | Reservas e receita estimada por origem: COMPY, manual e sistema externo | P · G | v2 |
| RF-P72 | Horas e valor recuperados pelo COMPY e jogadores novos trazidos | P · G | v2 |
| RF-P73 | Relatório mensal em PDF, com logo e tema, para entregar ao dono | P · G | v2 |
| RF-P74 | Taxas de falta e cancelamento e tempo médio de resposta às solicitações | P · G | v2 |
| RF-P75 | Exportar reservas em CSV | P | Futuro |

### I. Notificações

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P80 | Central de notificações no painel, com o número de não lidas no ícone | Todos | MVP |
| RF-P81 | Push no celular e no computador para nova solicitação e para cancelamento feito pelo jogador | Todos | MVP |
| RF-P82 | Push para solicitação perto de vencer e para Evento do Local fechado ou cancelado | Todos | v2 |
| RF-P83 | Preferências de aviso por membro | Todos | v2 |

### J. Plano e ajuda

| Código | Requisito | Quem | Prioridade |
| --- | --- | --- | --- |
| RF-P90 | Ver o plano (Vitrine ou Pro), a faixa de preço pelo número de quadras e o fim do período gratuito, com aviso 15 dias antes | P | MVP |
| RF-P91 | Funções do Pro aparecem com explicação quando o local está na Vitrine | Todos | v2 |
| RF-P92 | Faturas e pagamento da assinatura dentro do painel | P | Futuro |
| RF-P93 | Ajuda: falar com o COMPY pelo WhatsApp, perguntas frequentes e reportar um problema | Todos | MVP |

## 6. Integração com o app COMPY e com o painel admin

Painel, app e admin usam o mesmo Firestore e as mesmas Functions: o que o local publica aparece no app em segundos, e o que o jogador pede chega ao painel como solicitação.

&#91;embedded content: do horário livre à reserva · 7 passos em 3 raias\]

Se o local recusar ou não responder no prazo, o horário volta a ficar livre e o jogador é avisado do mesmo jeito.

**Evento do Local (v2)**

1. O atendente cria o evento num horário livre, por exemplo: beach tennis, intermediário, 4 vagas, R$ 20 por pessoa, mínimo de 4.
2. O evento entra nas listas e no mapa do app com o selo do local, como os eventos criados por usuários.
3. Os jogadores entram como Participantes; atingido o mínimo até o prazo (ex.: 3 h antes), o horário vira reserva confirmada.
4. Sem o mínimo, o evento é cancelado, os inscritos são avisados e o horário volta a ficar livre.

O Organizador desse evento é o Local Parceiro, então a definição de Organizador no `CONTEXT.md` muda (seção 15).

**Evento de usuário com quadra (v2):** ao criar um evento num local parceiro, o organizador pede a quadra no mesmo passo. O evento fica “aguardando o local” até a confirmação e é cancelado se a solicitação for recusada.

**Mudanças no app**

| Código | Mudança no app | Prioridade |
| --- | --- | --- |
| RF-A01 | Página do local parceiro: selo “Parceiro”, logo, fotos, comodidades, quadras e preços | MVP |
| RF-A02 | Disponibilidade dos próximos 7 dias por quadra (livre ou ocupado), sem dados de clientes | MVP |
| RF-A03 | Horários livres na página do local, no mapa (selo “livre hoje”) e num filtro “com horário livre” | MVP |
| RF-A04 | Solicitar reserva vendo preço e política de cancelamento, com aceite para compartilhar nome e telefone com o local | MVP |
| RF-A05 | “Minhas reservas”: solicitadas, confirmadas e passadas, com cancelamento dentro da política | MVP |
| RF-A06 | Notificações de reserva confirmada, recusada, vencida e cancelada pelo local, na central que já existe | MVP |
| RF-A07 | Evento do Local nas listas e no mapa, com o selo do local e o valor por pessoa | v2 |
| RF-A08 | Pedir a quadra ao criar um evento num local parceiro | v2 |
| RF-A09 | Lembrete por push antes do horário (o FCM no app está no backlog D do roadmap) | v2 |
| RF-A10 | Avaliar o local depois de uma reserva concluída, com a Avaliação que já existe | v2 |

**Mudanças no painel admin**

| Código | Mudança no painel admin | Prioridade |
| --- | --- | --- |
| RF-AD01 | Tornar um Local Esportivo privado em Local Parceiro e gerar o convite do primeiro Proprietário | MVP |
| RF-AD02 | Lista de parceiros: plano, fim do período gratuito, membros e última atividade | MVP |
| RF-AD03 | Suspender e reativar o painel de um local, com motivo, como nas exclusões | MVP |
| RF-AD04 | Fila de pedidos de alteração de endereço e modalidades vindos do painel | v2 |
| RF-AD05 | Métricas gerais: horários publicados, preenchidos pelo COMPY e tempo de resposta | v2 |

O documento `places/{placeId}` continua sendo do catálogo, editado só pelo Administrador. Os dados do parceiro ficam em coleções novas (seção 9), como já acontece com a média das avaliações em `ratingSummaries`. Se o local for suspenso, os horários livres saem do app, as solicitações pendentes são recusadas com aviso e as reservas confirmadas continuam visíveis para o jogador.

## 7. Identidade visual: temas por local e logo

O painel pode e deve parecer com o painel admin: navegação sobre uma quadra desenhada, painéis brancos sobre fundo cinza-claro e fonte Barlow. Muda a quadra, que segue a modalidade do local, e entra a logo dele.

A prévia abaixo mostra os seis temas na barra lateral do painel, com um local sem logo (monograma) e o item “Hoje” selecionado.

&#91;image: Prévia dos seis temas do Painel do Local: areia, padel, campo, saibro, ginásio e quadra padrão\]

**O que vem do painel admin**

- A quadra desenhada em código (`AdminCourtSurface` e `_CourtLinesPainter`), em pé na navegação e deitada no login.
- O teste automático de contraste (`admin_theme_test.dart`), estendido a todos os temas.
- A Barlow embutida, condensada nos títulos e números, sem depender de serviço externo.
- Painéis brancos (#FFFFFF) sobre fundo #F3F5F9 e etiquetas de estado coloridas.

**O que muda**

- No celular, barra inferior com quatro itens (Hoje, Agenda, Livres, Mais) e cabeçalho com a quadra do tema; a partir de 840 px, barra lateral como no admin.
- O tema vale só para a moldura: navegação, cabeçalho, login do local, carregamento, estados vazios e imagens de divulgação. Agenda e formulários ficam neutros, legíveis em qualquer tema.
- As cores de estado da agenda (livre, solicitado, confirmado, bloqueado, falta) são as mesmas em todos os temas, para quem trabalha em mais de um local.

**Temas**

| Tema | Modalidade principal | Piso | Desenho da quadra | Texto | Destaque | Item selecionado |
| --- | --- | --- | --- | --- | --- | --- |
| Quadra (padrão) | futsal, handebol, tênis de mesa e locais sem quadra | #1F3A8A, o azul do admin | linhas brancas de futsal, como no admin | #FFFFFF (10,3:1) | #34D399 (5,4:1) | #182D6C |
| Areia | beach tennis, vôlei de praia, futevôlei e futebol de areia | #E6CF9F, com grãos #D4B67E | fitas azuis de demarcação e rede no meio | #3A2A12 (9,1:1) | #1D4ED8 (4,4:1) | #F1E5CA |
| Padel | padel | #1E4E8C, grama sintética azul | linhas de saque, rede e paredes de vidro nas pontas | #FFFFFF (8,3:1) | #A3E635 (5,5:1) | #173D6D |
| Campo | futebol (society) | #1E6B3A, em faixas #23763F | círculo central, áreas e gols | #FFFFFF (6,5:1) | #FACC15 (4,3:1) | #17532D |
| Saibro | tênis | #A84B24 | linhas de simples e duplas e rede | #FFFFFF (5,7:1) | #FDE68A (4,6:1) | #833A1C |
| Ginásio | vôlei e basquete | #8A5228, em tábuas #7F4B24 | linhas de vôlei | #FFFFFF (6,3:1) | #FBBF24 (3,8:1) | #6C401F |

Entre parênteses está o contraste com o piso: texto com pelo menos 4,5:1 e destaque com pelo menos 3:1 (WCAG AA); o item selecionado tem pelo menos 8:1 com o texto. Corrida, ciclismo, caminhada e skate usam o tema padrão.

O tema vem da modalidade principal (`primarySport`), e o dono pode trocar por qualquer um da lista. Cor livre fica de fora, porque quebraria o contraste testado. As linhas são decoração, com 14% a 30% de opacidade, e nunca animam; cada tema é um `CustomPainter` com a mesma interface, em pé ou deitado.

**Logo do local**

- Envio em PNG, JPG ou WebP, até 2 MB e com pelo menos 256 × 256 px, com recorte quadrado no próprio painel. SVG não é aceito.
- Uma Function gera as versões de 128 e 512 px em WebP no Storage, em `partners/{placeId}/logo/`.
- A logo fica numa plaqueta branca de cantos arredondados, para logos escuras ou de fundo transparente aparecerem em qualquer tema.
- Sem logo, aparece um monograma com até duas iniciais do nome (“Arena Exemplo” vira “AE”), em Barlow Condensed, na cor do esporte no app, com pelo menos 5,6:1 sobre o branco.
- A logo aparece no topo da navegação, no login do local, na página do local no app, nos cards de Evento do Local, nas imagens de divulgação e no relatório mensal.
- O ícone do app instalado e o favicon são do COMPY, com um selo “LOCAL”, como o admin usa o selo “ADMIN”, porque o mesmo site atende todos os locais.

O link de convite e o endereço do local (`/l/<placeId>`) abrem o login já com o tema e a logo do local; o login genérico usa o tema padrão.

## 8. Tecnologia, repositório e hospedagem

Recomendação: Flutter Web como app instalável (PWA), numa pasta nova `gestor/` do mesmo repositório, publicado como terceiro site do Firebase Hosting no projeto `compy-tcc`.

&#91;embedded content: arquitetura · 3 apps e 1 projeto Firebase\]

Leituras vão direto ao Firestore, protegidas pelas regras. Tudo que mexe em reserva, convite ou horário livre passa por uma Function, que confere o papel e grava em transação.

**Opções avaliadas**

| Opção | A favor | Contra | Decisão |
| --- | --- | --- | --- |
| Flutter Web separado, em `gestor/` | Mesma linguagem, padrões e testes do admin; reaproveita o desenho da quadra; instala na tela inicial; o mesmo código pode virar app Android | Primeira abertura mais pesada no celular; push no iPhone só com o painel na Tela de Início | Escolhida |
| Modo gestor dentro do app COMPY | Push nativo e um app só | Mistura jogador e empresa; cada mudança espera a revisão das lojas; o dono quer o computador para configurar | Não |
| React ou Next.js, como um site comum | Web mais leve e com cara de site | Stack nova para duas pessoas; modelos duplicados em TypeScript e Dart; dois jeitos de testar | Não agora |
| Perfis de local dentro do painel admin | Menos código | Mistura a área interna com clientes; um erro de permissão exporia ferramentas de administrador | Não |

**Repositório**

```
MVP_COMPY/
├── lib/                          app dos jogadores (mobile)
├── admin/                        painel administrativo (interno)
├── gestor/                       Painel do Local: Flutter Web, pubspec próprio
├── packages/compy_courts/        temas e desenhos de quadra, usados por admin e gestor
├── functions/                    Cloud Functions: + reservas, convites e horários livres
├── firestore.rules · firestore.indexes.json · storage.rules
├── tools/firestore-rules-tests/  + testes das coleções novas
└── docs/gestores/ · docs/adr/0004-painel-do-local.md
```

- Mesmo repositório, porque regras, índices e Functions são compartilhados e precisam ser publicados juntos. Também valem o `AGENTS.md`, o caderno de campo e o padrão de branches (`feature/gestor-…` para a `develop`).
- `gestor/` não importa código do app nem do admin, como o admin já faz. Os dois painéis só compartilham o pacote `compy_courts`, que depende apenas do Flutter.
- A lista de modalidades ganha um quinto lugar (o painel), e o teste que compara as listas com o enum `Sport` precisa incluí-lo.
- O repositório passa a ser privado quando o desenvolvimento do painel começar, então o código comercial não precisa de um repositório separado.

**Stack do painel**

- Flutter estável mais novo, fixado no projeto (por exemplo, com FVM), porque a máquina da equipe já teve versão mais antiga que a exigida pelo admin.
- Riverpod, GoRouter, Material 3 e Feature-First, como no admin.
- Firebase Auth (Google e e-mail e senha), Firestore, Functions callables em TypeScript (Node 22, `southamerica-east1`), Storage, App Check com reCAPTCHA v3, Cloud Messaging para push e Analytics para o funil.
- Build com `--wasm --web-content-hash`, que o [Flutter 3.50](https://startdebugging.net/2026/11/flutter-3-50-wasm-on-safari-and-firefox-and-web-content-hash/) trouxe em 11/11/2026: WebAssembly por padrão no Chrome e no Edge, Safari 26.2+ e Firefox 147+ por lista de permissão, e JavaScript como reserva nos navegadores antigos.
- Service worker próprio, para cache e push: o [Flutter não gera mais um por padrão](https://docs.flutter.dev/docs/development/platform-integration/web/initialization).
- No iPhone, o push só funciona com o painel adicionado à Tela de Início (iOS 16.4 ou mais novo), e o pedido de permissão precisa vir de um toque do usuário ([WebKit](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)). O primeiro acesso ensina os dois passos.

**Hospedagem**

- Firebase Hosting com vários sites no projeto `compy-tcc`: alvo `gestor`, publicado com `firebase deploy --only hosting:gestor`. Sugestão de site: `compy-tcc-gestor.web.app`.
- Domínio próprio quando o domínio do COMPY for comprado, já previsto no investimento inicial (por exemplo, `painel.<domínio>`). O Hosting emite o HTTPS sozinho.
- O domínio do painel entra nos domínios autorizados do Firebase Auth e na chave do reCAPTCHA do App Check.
- Arquivos com hash ficam em cache por um ano (`immutable`); `index.html`, `flutter_bootstrap.js` e `manifest.json` ficam sem cache, para a versão nova chegar rápido. Cabeçalhos de segurança: CSP, `X-Frame-Options: DENY` e `Referrer-Policy`.

**Ambientes**

| Ambiente | Para quê | Onde |
| --- | --- | --- |
| Desenvolvimento | Programar e testar com dados falsos | Emulator Suite (Auth, Firestore, Functions e Storage), com um local de areia fictício |
| Prévia | Mostrar telas ao L01 e à banca antes de publicar | Canais de prévia do Hosting, um por pull request |
| Homologação | Testar com locais reais sem misturar com produção | Projeto Firebase separado (ex.: `compy-hml`), criado antes do teste gratuito (B8) |
| Produção | Uso real | `compy-tcc` até o CNPJ; o projeto novo da empresa entra junto com a fase 5 |

No GitHub Actions, cada pull request roda análise e testes do `gestor/`, testes das regras e das Functions, a checagem `--no-deprecated-js-interop` e um deploy de prévia. A produção sai à mão, na ordem do runbook: índices, Functions, regras e, por último, Hosting.

## 9. Modelo de dados e regras das reservas

Os dados do parceiro ficam em coleções novas, sem mexer no contrato de `places/{placeId}`, e as reservas só são gravadas por Cloud Functions, que impedem conflito numa transação.

| Coleção | O que guarda | Quem lê | Quem escreve |
| --- | --- | --- | --- |
| `partners/{placeId}` | Perfil público: nome de exibição, logo, tema, fotos, contatos, comodidades, políticas, modo de confirmação e estado (ativo ou suspenso) | Usuários logados | Proprietário e Gerente, com campos validados; o estado, só Function ou admin |
| `partners/{placeId}/private/operation` | Limite de desconto, prazo de resposta e antecedência | Membros do local | Proprietário e Gerente |
| `partners/{placeId}/private/billing` | Plano, fim do período gratuito e quadras cobradas | Proprietário | Só Function ou admin |
| `partners/{placeId}/members/{uid}` | Papel, nome, quem convidou e desde quando | Membros do local | Só Function (convite, troca de papel, remoção) |
| `partners/{placeId}/courts/{courtId}` | Quadra: nome, modalidades, piso, coberta, iluminação, estado, ordem, duração e preços por faixa | Usuários logados | Proprietário e Gerente |
| `partners/{placeId}/days/{aaaa-mm-dd}` | Grade do dia: intervalos ocupados por quadra e o tipo de cada um, sem dados pessoais | Usuários logados | Só Function |
| `partners/{placeId}/blocks/{blockId}` | Bloqueios e ocupados externos, com motivo | Membros do local | Só Function |
| `bookings/{bookingId}` | Reserva: local, quadra, início, fim, estado, origem, cliente, preço, desconto, evento ligado, autor e motivos | Membros do local e o jogador da reserva | Só Function |
| `slotOffers/{offerId}` | Horário livre publicado: local, quadra, modalidades, início, fim, preço, preço promocional e estado | Usuários logados | Só Function |
| `partnerInvites/{inviteId}` | Convite: local, papel, validade e quem usou | Ninguém pelo cliente | Só Function |
| `partners/{placeId}/activity/{entryId}` | Histórico: quem fez o quê, quando, antes e depois | Proprietário e Gerente | Só Function |
| `partners/{placeId}/customers/{customerId}` (v2) | Clientes cadastrados à mão: nome, telefone e faltas | Membros do local | Só Function |

A grade do dia é a autoridade sobre ocupação. Um documento por local e por dia deixa a leitura barata (o app lê 7 para mostrar a semana) e coloca as escritas daquele dia em fila, o que basta para o movimento de um local.

&#91;embedded content: estados da reserva · 7 estados, 2 entradas\]

A solicitação pendente também ocupa a grade do dia, para ninguém pedir o mesmo horário enquanto o local decide. Bloqueios e ocupados externos não têm estado: existem ou são removidos.

**Regras de negócio**

1. Sem conflito: reserva, solicitação pendente, bloqueio e ocupado externo nunca se sobrepõem na mesma quadra. A Function confere e grava numa única transação sobre a grade do dia e, se houver conflito, responde, por exemplo, “Quadra 2 já está ocupada das 22h às 23h”.
2. A solicitação segura o horário enquanto espera. Vence no prazo do local (30 min por padrão, entre 10 e 120 min, nunca depois do início) e libera o horário.
3. Antecedência: o jogador solicita com no mínimo 1 h e no máximo 14 dias, ou o que o local definir.
4. Limite por jogador: até 3 solicitações pendentes ao mesmo tempo, para ninguém segurar horários à toa.
5. Cancelamento pelo jogador: livre até o prazo da política do local; depois dele, o app avisa que vale a regra do local. No MVP, o COMPY não cobra nada.
6. Falta: o local marca até 24 h depois do horário. Ela conta só no histórico daquele local e não aparece para outros locais nem no perfil público.
7. Preço: vem da tabela da quadra pelo dia e pela faixa, e o desconto respeita o limite do Proprietário. O valor fica gravado na reserva, e mudar a tabela não altera reservas já feitas.
8. Origem: toda reserva grava de onde veio (app, horário livre, Evento do Local, manual ou externo) e se é a primeira do jogador naquele local. Isso sustenta o relatório e a futura comissão.
9. O horário livre sai do app sozinho quando é reservado, bloqueado ou quando começa.
10. Fuso: tudo em America/Sao\_Paulo. As datas são gravadas como Timestamp, e o id da grade usa a data local.
11. Repetição segura: as Functions usam ids determinísticos e aceitam repetição sem duplicar, como as notificações de fim de evento.
12. Uma rotina a cada 10 min, como `autoEndOverdueEvents`, vence solicitações, tira do ar horários livres passados e marca reservas passadas como concluídas.

**Functions novas**

- Callables do painel: `createBooking`, `updateBooking`, `cancelBooking`, `respondToRequest`, `markNoShow`, `createBlock`, `publishFreeSlot`, `withdrawFreeSlot`, `createInvite`, `acceptInvite`, `changeMemberRole`, `removeMember` e `transferOwnership`; na v2, `createVenueEvent`.
- Callables do app: `requestBooking` e `cancelMyBooking`.
- Gatilhos: notificação ao jogador quando a reserva muda de estado, push à equipe quando chega uma solicitação e versões de 128 e 512 px da logo.
- Agendadas: a rotina de 10 min, o aviso de fim do período gratuito e, na v2, o relatório mensal no dia 1.

Índices compostos novos: `bookings` por `placeId` e `start`, por `customer.uid` e `start`, e `slotOffers` por `status` e `start` com `sports` em array-contains.

## 10. Segurança, privacidade e LGPD

O painel lida com dados pessoais de clientes, como nome e telefone, então segue o padrão do app: acesso mínimo, escrita sensível só por Functions, rastro de tudo e base legal clara.

**Segurança**

- As regras do Firestore conferem o documento `members/{uid}` e o papel em cada acesso. Cada linha da matriz da seção 4 vira um teste no emulador, além de: removido perde o acesso na hora, jogador não lê reserva de outro e o local A não lê nada do local B.
- As callables exigem App Check (reCAPTCHA v3, como o admin) e conferem o papel no servidor, sem confiar no que o painel envia.
- No Storage, só Proprietário e Gerente gravam logo e fotos do próprio local, com tipo e tamanho limitados; a leitura pública vale só para imagens publicadas.
- Sessão persistente no aparelho, para o atendente não entrar toda hora, com “Sair” sempre visível e “Sair de todos os aparelhos”, que revoga os tokens por Function.
- E-mail verificado é obrigatório. Verificação em duas etapas para o Proprietário fica para o futuro.
- O painel admin não mostra telefone de clientes por padrão; quando o suporte precisar ver, o acesso fica registrado.

**LGPD**

- Papéis: para os jogadores do app, o COMPY é controlador. Para clientes cadastrados à mão, o local é controlador e o COMPY é operador. Isso entra num termo de uso do parceiro, com cláusula de tratamento de dados, aceito pelo Proprietário no primeiro acesso.
- Minimização: o local vê do jogador o nome de exibição e a foto. O telefone só aparece se o jogador autorizar na solicitação, o que respeita o contato protegido que o app já tem.
- Retenção proposta: dados pessoais das reservas por 24 meses, para histórico e relatórios; depois, nome e telefone são apagados e ficam só os números.
- Exclusão de conta: o jogador que exclui a conta tem as reservas futuras canceladas, com aviso ao local, e os dados pessoais das passadas anonimizados.
- Atualizar a política de privacidade, o registro das operações e os documentos de `docs/lgpd/`, inclusive a designação do encarregado, que ainda precisa ser assinada e datada.
- Jogadores de 16 e 17 anos podem solicitar reserva, e o local decide se confirma (seção 16).

## 11. Requisitos não funcionais

Os números abaixo são metas para o MVP; os de desempenho devem ser medidos no celular do L01 antes do teste gratuito.

| Código | Requisito | Como conferir |
| --- | --- | --- |
| RNF-01 | Celular primeiro: telas de 360 px sem rolagem lateral, alvos de toque de 48 px e fluxos do atendente com uma mão | Testes de widget em 360 × 640 e revisão num aparelho real |
| RNF-02 | Instalável como PWA: manifest, ícones maskable e abertura em tela cheia | Lighthouse, item “instalável” |
| RNF-03 | Primeira abertura em até 6 s num Android intermediário em 4G; as seguintes em até 2 s; ações de reserva respondem em até 2 s | DevTools com rede 4G e Performance Monitoring |
| RNF-04 | Tempo real: solicitação nova aparece no painel e horário publicado aparece no app em até 5 s | Teste ponta a ponta com emuladores |
| RNF-05 | Sem internet: mostra a última agenda salva com o aviso “sem conexão” e bloqueia escritas com explicação, sem fila de reservas offline que gere conflito | Teste offline, no padrão que o admin já usa |
| RNF-06 | Acessibilidade: contraste AA em todos os temas, semântica para leitor de tela e texto a 200% sem cortes | Teste automático de contraste e testes de widget |
| RNF-07 | Navegadores: Chrome e Edge (Android e Windows), Safari 16.4 ou mais novo e Firefox, nas duas últimas versões | Checklist manual a cada versão |
| RNF-08 | Fuso e formatos: America/Sao\_Paulo, “qui., 21/11”, 24 h e R$ 72,00 | Testes de unidade com virada de dia e de ano, como no app |
| RNF-09 | Nenhuma reserva duplicada, mesmo com dois atendentes tocando ao mesmo tempo | Teste de concorrência das Functions no emulador |
| RNF-10 | Observabilidade: logs estruturados nas Functions, alerta de erro e eventos do funil no Analytics (publicou, solicitou, confirmou, venceu) | Painel de logs e alertas do Firebase |
| RNF-11 | Custo: o app lê a grade do dia, e não as reservas; alerta de orçamento no plano Blaze | Relatório de uso do Firebase, todo mês |
| RNF-12 | Qualidade: sem avisos novos na análise, testes de unidade e widget no `gestor/`, testes de regras para cada coleção nova e testes das Functions | CI verde para fazer merge |
| RNF-13 | Português do Brasil sem termos técnicos, com textos centralizados, como o `AdminStrings` | Revisão dos textos |
| RNF-14 | Versão nova chega sem reinstalar, com o aviso “nova versão disponível” | Teste num canal de prévia |

## 12. Planos, cobrança e métricas de valor

O painel segue o plano de negócios: Vitrine grátis para entrar, Pro pago pelo número de quadras, até 3 meses grátis no piloto e comissão de 10% só sobre reservas que o COMPY trouxe.

| Plano | O que libera no painel | Preço por mês |
| --- | --- | --- |
| Vitrine | Perfil do local no app: fotos, logo, contatos, quadras e preços | R$ 0 |
| Pro | Agenda, solicitações, horários livres, Evento do Local, mensalistas, relatórios e destaque na busca | 1 quadra: R$ 49; 2 a 3: R$ 99; 4 a 5: R$ 149; acima de 5: R$ 149 + R$ 20 por quadra |
| Piloto | Pro completo por no máximo 3 meses, com o preço travado por 12 meses depois | R$ 0 no período |

- O plano de negócios cita pagamentos no Pro, mas o pagamento online fica para depois do CNPJ (fase 5). Até lá, a mensalidade é cobrada fora do painel, por Pix ou boleto.
- A faixa de preço vem das quadras ativas cadastradas, e o painel mostra ao Proprietário em que faixa o local está.
- Para cobrar a comissão a partir do 10º mês, o painel grava desde o MVP a origem de cada reserva, se ela veio de um horário livre e se o jogador é novo naquele local. Sem esse registro, não dá para provar nem cobrar depois.

**Métricas que provam valor**

São o argumento central de renovação do plano de negócios, mostradas ao dono no painel e à equipe no admin:

- horas e valor recuperados pelo COMPY no mês;
- reservas por origem e jogadores novos trazidos;
- taxa de preenchimento dos horários livres publicados;
- tempo médio de resposta e porcentagem de solicitações vencidas;
- membros da equipe ativos por semana.

## 13. Roteiro de entrega e critérios de aceite

São três entregas até o piloto comercial: o MVP para o teste gratuito (B8), a v2 antes do local piloto (B12) e o restante depois do CNPJ.

&#91;embedded content: roteiro · 5 fases e 4 marcos, fora de escala\]

O MVP ocupa janeiro e fevereiro de 2027 para o teste gratuito começar em março, e a v2 fica pronta antes do local piloto, previsto para julho.

**Critérios de aceite do MVP**

- [ ] Um Proprietário convidado pelo admin configura o local, 5 quadras, preços e horários em até 15 min.
- [ ] O Proprietário convida um Atendente, que não consegue mudar preços nem ver relatórios e equipe.
- [ ] Removido da equipe, o Atendente perde o acesso na ação seguinte, sem esperar o token vencer.
- [ ] O Atendente registra no celular uma reserva vinda do WhatsApp em até 30 s.
- [ ] Dois atendentes tentando a mesma quadra e horário ao mesmo tempo: só uma reserva é gravada.
- [ ] Um horário livre publicado aparece no app em até 5 s, e a solicitação do jogador chega ao painel com push.
- [ ] Uma solicitação sem resposta vence no prazo, e o jogador é avisado na central de notificações.
- [ ] Os seis temas passam no teste de contraste AA, e um local sem logo mostra o monograma.
- [ ] Todas as suítes (app, admin, gestor, regras e Functions) ficam verdes antes do deploy.

**Teste de usabilidade com atendentes**

No teste gratuito, cada atendente faz quatro tarefas sem ajuda: confirmar uma solicitação, registrar uma reserva do WhatsApp, publicar a quinta das 22h às 23h com desconto e bloquear uma quadra para manutenção. A meta é conclusão sem ajuda em pelo menos 80% das tarefas e SUS de pelo menos 68, a média de referência que o TCC já usa (Sauro, 2011).

## 14. Riscos

O maior risco não é técnico: é o local não usar o painel porque já tem um sistema que funciona.

| Risco | Efeito | Mitigação |
| --- | --- | --- |
| Local com sistema próprio não quer duplicar trabalho | Painel parado | Modo só horários livres: o local publica 4 ou 5 horários por semana, e nada mais é obrigatório |
| Reserva dupla entre o sistema do local e o COMPY | Cliente chega e a quadra está ocupada | Confirmação manual por padrão; só vai ao app o horário que o local publicar; “marcar como ocupado” em um toque |
| Atendente não vê a solicitação a tempo | Jogador desiste e o local perde a venda | Push, prazo de resposta visível e métrica de tempo de resposta |
| Push não chega no iPhone sem o painel na Tela de Início | Atendentes com iPhone perdem avisos | O primeiro acesso ensina a instalar; se o teste mostrar falhas, o mesmo código vira app nativo |
| Flutter Web lento em celular fraco | Atendente desiste do painel | Build WebAssembly, cache dos arquivos e medição no celular do L01 antes do teste |
| Poucos jogadores no app no começo | Horário publicado não enche e o dono perde o interesse | Começar por 2 ou 3 modalidades (areia primeiro, como no L01), Evento do Local e divulgação pelo Instagram do próprio local |
| Vazamento de dados de clientes | Problema legal e perda de confiança | Regras testadas, escrita só por Functions, minimização e histórico de acessos |
| Escopo grande para duas pessoas | MVP atrasa e o teste gratuito escorrega | MVP fechado na seção 5; o resto só entra depois do teste gratuito |
| Custo do Firebase sobe | Prejuízo antes da receita | Grade do dia num documento só, alerta de orçamento e os gatilhos de migração do plano de etapas |

## 15. Glossário para o CONTEXT.md

Os termos novos seguem o formato do `CONTEXT.md` e podem ser colados como estão. Dois termos atuais mudam: o Organizador pode ser um Local Parceiro, e o Painel Administrativo passa a cuidar também dos Locais Parceiros.

```markdown
**Local Parceiro**:
Local Esportivo privado com Equipe do Local e Painel do Local ativos no COMPY.
_Evitar_: Cliente, estabelecimento, arena parceira

**Painel do Local**:
Interface web em que a Equipe do Local gerencia quadras, horários e reservas de um Local Parceiro.
_Evitar_: Painel do gestor, backoffice, painel do parceiro

**Equipe do Local**:
Pessoas com acesso ao Painel do Local de um Local Parceiro, cada uma com um papel.
_Evitar_: Staff, funcionários

**Proprietário**:
Papel com todas as permissões de um Local Parceiro, inclusive equipe e plano. Todo Local Parceiro tem pelo menos um.
_Evitar_: Dono, admin, master

**Gerente**:
Papel que opera e configura o Local Parceiro, sem acesso à equipe nem ao plano.
_Evitar_: Supervisor, administrador do local

**Atendente**:
Papel que cuida apenas de horários e reservas, dentro dos preços e regras definidos.
_Evitar_: Funcionário, recepcionista, operador

**Quadra**:
Espaço reservável de um Local Parceiro, com modalidades, piso e preços próprios.
_Evitar_: Campo, espaço, recurso

**Reserva**:
Uso de uma Quadra em data e horário definidos, com estado e origem registrados.
_Evitar_: Agendamento, locação, booking

**Solicitação de Reserva**:
Reserva pedida pelo app que segura o horário até o local confirmar, recusar ou o prazo vencer.
_Evitar_: Pedido, pré-reserva

**Bloqueio**:
Período em que a Quadra não pode ser reservada, com motivo registrado.
_Evitar_: Interdição, fechamento

**Horário Livre**:
Horário vago que o Local Parceiro publica no app para atrair jogadores, com preço promocional opcional.
_Evitar_: Promoção, oferta, slot

**Evento do Local**:
Evento Esportivo criado pela Equipe do Local num Horário Livre, com vagas abertas a jogadores do COMPY.
_Evitar_: Jogo aberto, partida do local

**Falta**:
Reserva confirmada em que o cliente não compareceu nem avisou.
_Evitar_: No-show, bolo

**Mensalista**:
Cliente com Reserva fixa semanal na mesma Quadra e no mesmo horário.
_Evitar_: Fixo, assinante

**Tema do Local**:
Conjunto de cores e desenho de quadra usado na moldura do Painel do Local.
_Evitar_: Skin, layout
```

## 16. Decisões dos pontos em aberto

Decididas em 18/11/2026, antes da primeira validação das telas com um local.

- [x] Nome do produto: “COMPY para Locais”. “Painel do Local” continua sendo o nome da interface, como no glossário.
- [x] O Gerente entra só na v2; no MVP, há Proprietário e Atendente.
- [x] O Gerente não convida Atendentes: a equipe fica nas mãos do Proprietário.
- [x] Jogadores de 16 e 17 anos podem solicitar reserva, e o local decide se confirma.
- [ ] O prazo de 30 min para responder serve ao L01? Fica como padrão e é perguntado na validação das telas.
- [x] O repositório `MVP_COMPY` passa a ser privado quando o painel começar, e o `gestor/` fica nele.
- [x] A produção continua no `compy-tcc` até o CNPJ; o projeto novo da empresa entra junto com a fase 5.
- [x] Até comprar o domínio, o painel fica em `compy-tcc-gestor.web.app`; `painel.<domínio>` entra quando o domínio for comprado.
- [ ] Segundo local do teste gratuito: escolher entre L02 e L08 um sem sistema de reservas e, se possível, de outra modalidade (society ou padel), para testar a agenda completa e a ociosidade fora da areia.
- [x] As telas são validadas com um local em 18/11/2026, logo depois de prontas, no lugar da revisão no Figma.

## Fontes

- Entrevista L01 (29/10/2026), seção 9.7 do TCC e caderno de campo do mesmo dia.
- Plano de negócios do COMPY (2026) e plano de etapas, fase B6.
- Repositório `MVP_COMPY`: `docs/admin/painel-administrativo.md`, `admin/lib/core/theme/`, `CONTEXT.md`, `lib/shared/models/sport.dart` e a tarefa 14.
- [Flutter 3.50: WebAssembly no Safari e no Firefox e hash de conteúdo](https://startdebugging.net/2026/11/flutter-3-50-wasm-on-safari-and-firefox-and-web-content-hash/)
- [Flutter: inicialização de apps web e fim do service worker padrão](https://docs.flutter.dev/docs/development/platform-integration/web/initialization)
- [WebKit: Web Push para web apps no iOS e no iPadOS](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)
