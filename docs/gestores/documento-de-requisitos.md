# **Documento de Requisitos: COMPY para Locais**

**Objetivo:** Desenvolver uma plataforma web, ligada ao aplicativo COMPY, em que proprietários e funcionários de locais esportivos privados de Taquara/RS publiquem horários livres, recebam reservas de jogadores do COMPY e organizem a agenda das quadras, transformando horário vazio em receita.

### **1\. Visão Geral do Produto**

O Painel do Local é o lado da oferta do COMPY. Enquanto o aplicativo ajuda o jogador a encontrar onde e com quem jogar, o painel permite que o local parceiro mostre seus horários vagos a quem procura jogo, confirme reservas e acompanhe quantos clientes novos o COMPY trouxe.

A primeira entrevista com gestores (L01, 29/10/2026), feita numa arena coberta de esportes de areia com 5 quadras, orientou o escopo: o atendimento é feito pelo celular, o local já paga um sistema de agenda e sobram ao menos 4 horas de quadra vazias por semana, cerca de R\$ 1.440 por mês. Por isso, o painel funciona ao lado do sistema que o local já usa e se concentra no que esses sistemas não fazem: trazer jogador novo para o horário vazio.

O painel é um aplicativo web instalável no celular (PWA), desenvolvido em Flutter Web, separado do aplicativo e do painel administrativo e hospedado no Firebase Hosting do projeto compy-tcc. O visual segue o painel administrativo, com a navegação sobre uma quadra desenhada que muda conforme a modalidade principal do local (areia, padel, campo, saibro, ginásio ou quadra), e mostra a logo do local ou, sem logo, as iniciais do nome.

### **2\. Perfis de Acesso**

Quem usa o painel e o que cada perfil pode fazer. Cada pessoa entra com a própria conta, por convite.

| Perfil | Quem é | O que pode fazer |
| :---- | :---- | :---- |
| **Proprietário** | Dono ou sócio do local. Todo local tem pelo menos um. | Tudo: agenda, reservas, horários livres, perfil, quadras, preços, relatórios, equipe e plano. |
| **Gerente** | Quem administra o local no dia a dia (opcional, na segunda versão). | Opera e configura o local e vê os relatórios, mas não mexe na equipe nem no plano. |
| **Atendente** | Funcionário da recepção. | Só horários e reservas: agenda, reservas manuais, bloqueios, solicitações e horários livres, dentro dos preços e do limite de desconto. |
| **Administrador COMPY** | Equipe do COMPY, pelo painel administrativo. | Cria o local parceiro, convida o primeiro Proprietário e suspende o acesso, mas não mexe nas reservas. |

### **3\. Requisitos Funcionais (RF):**

O que o sistema deve fazer (ações e funcionalidades).

| ID | Nome do Requisito | Descrição | Prioridade |
| :---- | :---- | :---- | :---- |
| **RF01** | **Acesso por Convite** | O sistema deve permitir a entrada com Google ou com e-mail e senha verificado, apenas por convite: um link ou QR Code com o perfil definido, válido por 7 dias e de uso único. | Essencial |
| **RF02** | **Perfis e Permissões** | O sistema deve liberar as funções conforme o perfil (Proprietário, Gerente ou Atendente), conferindo o perfil a cada acesso. | Essencial (Gerente: Importante) |
| **RF03** | **Gestão da Equipe** | O Proprietário deve poder convidar membros, mudar o perfil, remover com efeito imediato e transferir a propriedade, mantendo sempre pelo menos um Proprietário. | Essencial |
| **RF04** | **Primeiro Acesso Guiado** | O sistema deve guiar o Proprietário na configuração do local (dados, logo, tema, quadras, preços e horário de funcionamento) em até 15 minutos. | Essencial |
| **RF05** | **Tela Hoje** | O sistema deve mostrar a grade do dia com cada quadra livre, solicitada, reservada ou bloqueada, as solicitações pendentes no topo, com o tempo restante, e as horas recuperadas pelo COMPY no mês. | Essencial |
| **RF06** | **Agenda e Reserva Manual** | O sistema deve exibir a agenda do dia e da semana e permitir registrar, em até 30 segundos, reservas feitas por WhatsApp, telefone ou balcão, além de editar, mover e cancelar com motivo. | Essencial |
| **RF07** | **Bloqueios e Horário Ocupado** | O sistema deve permitir bloquear horários com motivo (manutenção, chuva, aula ou evento interno) e marcar um horário como ocupado em um toque, para locais que usam outro sistema. | Essencial |
| **RF08** | **Prevenção de Conflitos** | O sistema deve impedir, no servidor, que duas reservas ou bloqueios ocupem a mesma quadra no mesmo horário. | Essencial |
| **RF09** | **Solicitações do Aplicativo** | O sistema deve receber as reservas pedidas pelo app e permitir confirmar ou recusar em um toque, com prazo de resposta configurável (30 minutos por padrão) e confirmação manual ou automática. | Essencial |
| **RF10** | **Publicação de Horários Livres** | O sistema deve permitir publicar horários vagos no app, com preço promocional opcional dentro do limite de desconto do Proprietário, e retirar a publicação quando o horário é reservado, bloqueado ou começa. | Essencial |
| **RF11** | **Horários Livres Recorrentes** | O sistema deve permitir publicar um horário livre que se repete toda semana (ex.: quintas, das 22h às 23h), com data de fim. | Importante |
| **RF12** | **Evento do Local** | O sistema deve permitir criar, num horário livre, um evento com vagas abertas a jogadores do COMPY, valor por pessoa e mínimo de participantes para confirmar. | Importante |
| **RF13** | **Divulgação no Instagram** | O sistema deve gerar imagens para stories e feed com os horários livres, a logo do local e o link ou QR Code do COMPY. | Importante |
| **RF14** | **Perfil do Local** | O sistema deve permitir editar nome de exibição, descrição, até 8 fotos, contatos, comodidades (na segunda versão) e políticas de cancelamento e de faltas. Endereço e modalidades do catálogo ficam só para leitura, com pedido de alteração ao COMPY. | Essencial |
| **RF15** | **Logo e Tema Visual** | O sistema deve exibir a logo do local, ou as iniciais do nome quando não houver logo, e aplicar o tema da modalidade principal, que o Proprietário pode trocar entre os temas disponíveis. | Essencial |
| **RF16** | **Quadras, Preços e Funcionamento** | O sistema deve permitir cadastrar quadras (modalidades, piso, cobertura, iluminação e estado), horário de funcionamento, duração do horário e tabela de preços por dia e faixa de horário. | Essencial |
| **RF17** | **Faltas e Histórico do Cliente** | O sistema deve permitir marcar falta ou reserva concluída e mostrar o histórico de reservas, faltas e cancelamentos de cada cliente no local. | Essencial (histórico: Importante) |
| **RF18** | **Mensalistas** | O sistema deve permitir reservas fixas semanais, com data de fim e exceções. | Importante |
| **RF19** | **Relatórios de Ocupação** | O sistema deve mostrar a ocupação por quadra, dia e hora, as reservas por origem e as horas e o valor recuperados pelo COMPY, e gerar um relatório mensal em PDF. | Importante |
| **RF20** | **Notificações** | O sistema deve avisar a equipe sobre novas solicitações e cancelamentos pela central do painel e por notificação push no celular ou no computador. | Essencial |
| **RF21** | **Histórico de Atividades** | O sistema deve registrar quem criou, alterou ou cancelou cada reserva e configuração, com acesso para Proprietário e Gerente. | Importante |
| **RF22** | **Plano e Período Gratuito** | O sistema deve mostrar ao Proprietário o plano atual, a faixa de preço pelo número de quadras e o fim do período gratuito, com aviso 15 dias antes. | Essencial |
| **RF23** | **Ajuda e Suporte** | O sistema deve oferecer contato com a equipe do COMPY pelo WhatsApp, perguntas frequentes e um canal para reportar problemas. | Essencial |
| **RF24** | **Pagamento Online** | O sistema deve permitir, depois da formalização da empresa (CNPJ), cobrar sinal de reserva por Pix e a mensalidade do plano dentro do painel. | Baixa Prioridade |

### **4\. Requisitos Não Funcionais (RNF)**

Como o sistema deve ser (qualidade, desempenho e restrições).

| ID | Nome do Requisito | Descrição |
| :---- | :---- | :---- |
| **RNF01** | **Tecnológico** | O painel deve ser desenvolvido em Flutter Web (linguagem Dart), como aplicativo separado na pasta gestor/ do repositório do COMPY, com Firebase Auth, Firestore, Cloud Functions, Storage e Cloud Messaging. |
| **RNF02** | **Hospedagem** | O painel deve ser publicado no Firebase Hosting do projeto compy-tcc, em site próprio, e depois num domínio próprio do COMPY. |
| **RNF03** | **Celular Primeiro** | A interface deve funcionar a partir de telas de 360 px, com alvos de toque de 48 px e uso com uma mão, e ganhar barra lateral em telas a partir de 840 px. |
| **RNF04** | **Instalável** | O painel deve poder ser instalado na tela inicial do celular (PWA). No iPhone, as notificações exigem iOS 16.4 ou mais novo e o painel instalado. |
| **RNF05** | **Desempenho** | A primeira abertura deve levar até 6 segundos num Android intermediário em 4G, as seguintes até 2 segundos, e as ações de reserva devem responder em até 2 segundos. |
| **RNF06** | **Tempo Real** | Uma solicitação nova deve aparecer no painel, e um horário publicado deve aparecer no app, em até 5 segundos. |
| **RNF07** | **Segurança** | As regras do Firestore devem conferir o perfil a cada acesso, as escritas de reserva devem passar apenas por Cloud Functions e as chamadas devem ser protegidas pelo App Check. |
| **RNF08** | **Confiabilidade** | O sistema não deve gravar reservas duplicadas, mesmo com dois atendentes agindo ao mesmo tempo na mesma quadra. |
| **RNF09** | **Conformidade com a LGPD** | O local deve ver apenas os dados necessários do jogador, e o telefone só aparece com autorização. Os dados pessoais das reservas devem ser apagados após 24 meses, e o termo do parceiro deve definir o local como controlador dos clientes que ele cadastra. |
| **RNF10** | **Acessibilidade Visual** | Todos os temas devem ter contraste AA (texto 4,5:1 e componentes 3:1), com suporte a leitores de tela e a texto ampliado em 200%. |
| **RNF11** | **Funcionamento sem Internet** | Sem conexão, o painel deve mostrar a última agenda salva com um aviso e bloquear alterações até a conexão voltar. |
| **RNF12** | **Fuso e Formatos** | Datas e horários devem seguir o fuso America/Sao\_Paulo, com hora de 24 h e valores em reais. |
| **RNF13** | **Navegadores** | O painel deve funcionar no Chrome e no Edge (Android e Windows), no Safari 16.4 ou mais novo e no Firefox, nas duas últimas versões. |
| **RNF14** | **Qualidade** | O código deve ter testes de unidade e de widget, testes das regras do Firestore e das Cloud Functions, e passar na integração contínua antes de cada publicação. |

### **5\. Regras de Negócio (RN)**

As diretrizes e restrições que regem o funcionamento do painel.

| ID | Regra de Negócio | Descrição |
| :---- | :---- | :---- |
| **RN-01** | **Locais Verificados** | Somente locais esportivos privados verificados pela equipe do COMPY podem virar parceiros. O primeiro Proprietário é convidado pelo painel administrativo, depois da visita ao local. |
| **RN-02** | **Proprietário Obrigatório** | Todo local parceiro deve ter pelo menos um Proprietário. O último só sai depois de transferir a propriedade. |
| **RN-03** | **Prazo das Solicitações** | A solicitação segura o horário até a resposta do local e vence no prazo definido (30 minutos por padrão, entre 10 e 120 minutos, nunca depois do início), liberando o horário. |
| **RN-04** | **Antecedência** | O jogador pode solicitar com no mínimo 1 hora e no máximo 14 dias de antecedência, ou conforme o local definir. |
| **RN-05** | **Limite de Solicitações** | Cada jogador pode ter no máximo 3 solicitações pendentes ao mesmo tempo. |
| **RN-06** | **Preço e Desconto** | O preço vem da tabela da quadra pelo dia e pela faixa de horário. O desconto respeita o limite definido pelo Proprietário, e o valor fica gravado na reserva. |
| **RN-07** | **Faltas** | A falta é marcada pelo local em até 24 horas depois do horário e aparece apenas no histórico daquele local. |
| **RN-08** | **Origem das Reservas** | Toda reserva grava a origem (app, horário livre, Evento do Local, manual ou sistema externo) e se o jogador é novo no local. Esses dados sustentam os relatórios e a futura comissão de 10% sobre as reservas geradas pelo COMPY. |
| **RN-09** | **Planos** | A Vitrine (perfil do local no app) é gratuita. O plano Pro custa R\$ 49 para 1 quadra, R\$ 99 para 2 a 3, R\$ 149 para 4 a 5 e mais R\$ 20 por quadra acima de 5, com no máximo 3 meses grátis na fase piloto. |
| **RN-10** | **Suspensão** | Com o painel suspenso, os horários livres saem do app e as solicitações pendentes são recusadas com aviso ao jogador; as reservas confirmadas continuam válidas. |

### **6\. Integração com o Aplicativo e o Painel Administrativo**

Mudanças necessárias fora do painel, já abertas como issues no repositório do projeto.

| ID | Mudança | Issue | Prioridade |
| :---- | :---- | :---- | :---- |
| **RF-A01** | Página do local parceiro com selo, logo, fotos, comodidades, quadras e preços | [\#56](https://github.com/GabrielPittaBr/MVP_COMPY/issues/56) | Essencial |
| **RF-A02** | Disponibilidade dos próximos 7 dias por quadra | [\#57](https://github.com/GabrielPittaBr/MVP_COMPY/issues/57) | Essencial |
| **RF-A03** | Horários livres na ficha do local, no mapa e num filtro | [\#58](https://github.com/GabrielPittaBr/MVP_COMPY/issues/58) | Essencial |
| **RF-A04** | Solicitar reserva de quadra | [\#59](https://github.com/GabrielPittaBr/MVP_COMPY/issues/59) | Essencial |
| **RF-A05** | Minhas reservas, com cancelamento | [\#60](https://github.com/GabrielPittaBr/MVP_COMPY/issues/60) | Essencial |
| **RF-A06** | Notificações de reserva na central | [\#61](https://github.com/GabrielPittaBr/MVP_COMPY/issues/61) | Essencial |
| **RF-A07** | Evento do Local nas listas e no mapa | [\#62](https://github.com/GabrielPittaBr/MVP_COMPY/issues/62) | Importante |
| **RF-A08** | Pedir a quadra ao criar um evento num local parceiro | [\#63](https://github.com/GabrielPittaBr/MVP_COMPY/issues/63) | Importante |
| **RF-A09** | Lembrete por push antes do horário da reserva | [\#64](https://github.com/GabrielPittaBr/MVP_COMPY/issues/64) | Importante |
| **RF-A10** | Avaliar o local depois de uma reserva concluída | [\#65](https://github.com/GabrielPittaBr/MVP_COMPY/issues/65) | Importante |
| **RF-AD01** | Tornar um local privado em parceiro e convidar o primeiro Proprietário | [\#66](https://github.com/GabrielPittaBr/MVP_COMPY/issues/66) | Essencial |
| **RF-AD02** | Lista de locais parceiros com plano, período gratuito e membros | [\#67](https://github.com/GabrielPittaBr/MVP_COMPY/issues/67) | Essencial |
| **RF-AD03** | Suspender e reativar o painel de um parceiro | [\#68](https://github.com/GabrielPittaBr/MVP_COMPY/issues/68) | Essencial |
| **RF-AD04** | Fila de pedidos de alteração vindos do painel | [\#69](https://github.com/GabrielPittaBr/MVP_COMPY/issues/69) | Importante |
| **RF-AD05** | Métricas dos parceiros | [\#70](https://github.com/GabrielPittaBr/MVP_COMPY/issues/70) | Importante |

### **7\. Diagrama de Fluxo (Visualização)**

1. **INÍCIO:** a equipe do COMPY verifica o local, cria o parceiro no painel administrativo e envia o convite ao Proprietário.  
2. **CONFIGURAÇÃO:** o Proprietário entra pelo convite, confere os dados, envia a logo, escolhe o tema, cadastra quadras, preços e horários e convida os atendentes.  
3. **DIA A DIA:** o Atendente abre a tela Hoje, vê a grade das quadras, registra as reservas que chegam pelo WhatsApp e bloqueia horários de manutenção.  
4. **HORÁRIO LIVRE:** com quadra vazia, o Atendente publica o horário livre, com ou sem desconto, e ele aparece no app em até 5 segundos. Também pode criar um Evento do Local ou compartilhar a imagem no Instagram.  
5. **SOLICITAÇÃO:** o jogador solicita a reserva pelo app, e a equipe recebe a notificação e confirma ou recusa. Sem resposta no prazo, a solicitação vence e o horário volta a ficar livre.  
6. **DEPOIS DO HORÁRIO:** a reserva fica concluída ou é marcada como falta, e o jogador avalia o local no app.  
7. **RESULTADO:** o Proprietário acompanha nos relatórios a ocupação e as horas recuperadas pelo COMPY no mês.