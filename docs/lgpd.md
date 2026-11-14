# LGPD no COMPY — diagnóstico e plano de adequação

Levantamento de 04/11/2026, feito a pedido da banca: o que a LGPD (Lei
13.709/2018) e as normas ligadas a ela exigem do COMPY, o que o app já cumpre
e o que falta. Juntamos duas coisas: a leitura das fontes primárias (lei no
Planalto, resoluções e guias da ANPD, políticas do Google Play, termos do
Firebase e da OpenStreetMap Foundation) e a leitura do código do app, do
painel e das regras do Firebase.

> **Não é parecer jurídico.** Onde o texto diz *interpretação*, a conclusão é
> nossa a partir das fontes, e não uma frase da norma. Todas as páginas
> citadas foram abertas em 04/11/2026.

> **Decisão de 14/11/2026: idade mínima de 16 anos.** O COMPY aceita contas
> a partir dos 16. As contas de 16 e 17 anos são de adolescentes, então as
> proteções do ECA Digital (seção 5.13) deixaram de ser condicionais e
> entraram no plano obrigatório.

---

## 0. O que foi implementado (`chore/lgpd`, 14/11/2026)

O plano das seções 5 a 8 foi aplicado no app, no painel, nas regras e nas
Functions. Os documentos de governança estão em [`docs/lgpd/`](lgpd/).

| Item | Situação | Onde |
|---|---|---|
| 5.1 Idade mínima 16 e sinal de idade da Play | Feito | `lib/core/utils/age_rules.dart`, `MainActivity.kt`, `validConsent` nas regras |
| 5.2 Política e Termos em página pública | Feito | `site/`, publicado em https://compy-tcc.web.app |
| 5.3 Link do login e aceite registrado | Feito | `login_page.dart`, `legal_consent_fields.dart`, `/consentimento` |
| 5.4 Canal e encarregado | Feito; falta assinar a designação | `docs/lgpd/designacao-encarregado.md` |
| 5.5 Exclusão completa e pela web | Feito | `functions/src/account_cleanup.ts`, `site/excluir-conta.html`, Configurações |
| 5.6 Aviso antes da localização | Feito | `lib/shared/widgets/location_disclosure.dart` |
| 5.7 Denunciar e bloquear | Feito | `lib/features/safety/`, fila "Denúncias" no painel |
| 5.8 Segurança dos dados da Play | Respostas prontas; falta preencher no Console | `docs/lgpd/guia-play-console.md` |
| 5.9 Configurações → Privacidade e "Baixar meus dados" | Feito | `lib/features/settings/`, `functions/src/data_export.ts` |
| 5.10 Retenção | Feito para o que nasce agora; falta o backfill dos documentos antigos | `firestore.indexes.json` (TTL), `docs/lgpd/retencao.md` |
| 5.11 Transferência internacional na política | Feito | `site/privacidade.html`, seção 5 |
| 5.12 Segurança e incidentes | Feito; imposição do App Check fica para depois da Play | `docs/lgpd/politica-de-seguranca.md`, `plano-de-incidentes.md` |
| 5.13 Proteções de 16–17 (nível Essencial) | Feito: chat só com amigos, localização desligada por padrão | `canTalk` em `firestore.rules` |
| 5.14 OSM, logs e fotos antigas | Feito | `lib/shared/widgets/osm_map.dart`, `lib/main.dart`, `functions/src/avatar_cleanup.ts` |
| Seção 7 — documentos | Feito | `docs/lgpd/` |

Ficaram de fora, por decisão: esconder o perfil de 16–17 da busca (nível
"Completo", seção 5.13), a troca do `usernames` público por uma callable e o
`allowBackup` do Android (seção 5.14).

---

## 1. Resumo em 10 pontos

1. **A LGPD se aplica ao COMPY por inteiro.** A exceção de "fins
   exclusivamente particulares" (art. 4º, I) não serve, porque o app trata
   dados de outras pessoas e é aberto ao público. A exceção acadêmica
   (art. 4º, II, "b") é parcial e restrita à liberdade acadêmica, segundo a
   ANPD. Operar um app com contas, chat e localização é prestar um serviço.
2. **Os controladores somos nós, os estudantes** (pessoas naturais). O
   Google/Firebase é o **operador**. Como pessoas naturais, cabemos no regime
   de **agente de tratamento de pequeno porte** (Res. CD/ANPD nº 2/2022). Como
   o app aceita adolescentes de 16 e 17 anos, e dados de adolescentes contam
   como critério de alto risco, não contamos com esse benefício.
3. **O app já tem uma base boa:** exclusão de conta dentro do app, e-mail fora
   do perfil público, chat visível só aos membros, comentários de avaliação
   privados, EXIF removido da foto, localização que não sai do aparelho,
   nenhum Analytics ou anúncio e regras do Firestore testadas.
4. **Falta o básico de transparência:** não existem Política de Privacidade
   nem Termos de Uso. O link "Política de Privacidade" da tela de login é um
   `TODO` e não abre nada.
5. **A exclusão de conta é incompleta.** Nome, @username e foto continuam
   copiados nos eventos e nas conversas. As mensagens enviadas e as
   avaliações feitas também ficam.
6. **Faltam os direitos do titular na prática:** um canal de contato
   (encarregado ou e-mail de privacidade), a exportação dos dados ("Baixar
   meus dados") e uma tela de Configurações com a parte de privacidade.
7. **Idade mínima: 16 anos** (decidida em 14/11/2026). O ECA Digital
   (Lei 15.211/2025) está em vigor desde 17/03/2026. Como o app aceita
   adolescentes de 16 e 17 anos, valem as proteções dele: configurações
   protetivas por padrão, aferição de idade, canal de denúncia e avaliação
   de impacto.
8. **A Play Store exige, antes de publicar:**
   - política em URL pública;
   - formulário "Segurança dos dados";
   - exclusão de conta também por link web;
   - aviso antes do pedido de localização;
   - **denúncia e bloqueio** no chat.
9. **Há transferência internacional:** o Firebase Authentication roda só nos
   EUA. O contrato do Google Cloud já incorpora as cláusulas-padrão aprovadas
   pela ANPD. Isso precisa constar na política.
10. **Faltam os documentos de governança.** São eles que provam a boa-fé e
    viram atenuantes numa fiscalização:
    - registro das operações (ROPA);
    - tabela de retenção;
    - plano de resposta a incidentes;
    - política simples de segurança.

---

## 2. A LGPD se aplica? Quem é quem

### 2.1 Aplicação

- A LGPD vale para tratamento feito "por pessoa natural ou por pessoa
  jurídica" com dados coletados no Brasil ([arts. 1º e 3º][lgpd]).
- **Art. 4º, I:** fica fora da lei o tratamento "realizado por pessoa natural
  para fins exclusivamente particulares e não econômicos". Os dois requisitos
  são cumulativos, e um app aberto ao público não é uso particular.
- **Art. 4º, II, "b":** os fins acadêmicos afastam só parte da lei, e os
  arts. 7º e 11 (bases legais) continuam valendo. O [Guia da ANPD sobre fins
  acadêmicos (jun/2023)][guia-academico] manda interpretar essa exceção de
  forma restritiva, "estritamente vinculado ao exercício da liberdade
  acadêmica". Pode ser acadêmica a **pesquisa do TCC** (um questionário com
  os usuários, por exemplo), mas não a operação do app.

### 2.2 Papéis

| Papel | Quem é no COMPY | Base |
|---|---|---|
| Controlador | Os estudantes que decidem o que o app coleta e para quê. Se decidimos juntos, é **controladoria conjunta** e respondemos solidariamente | [LGPD art. 5º, VI][lgpd]; [art. 42, §1º, II][lgpd]; [Guia de agentes de tratamento][guia-agentes] |
| Operador | Google (Firebase Auth, Firestore, Storage, Functions, Hosting) | [Firebase – Privacy and Security][firebase-privacy] |
| Terceiros por conta própria | Google no **Login com Google** e na Play Store; **OpenStreetMap Foundation**, que recebe IP e User-Agent quando o celular baixa os tiles do mapa | [Política de privacidade da OSMF][osmf-privacy] |
| Encarregado | Ainda não existe. O pequeno porte dispensa a indicação, mas **exige um canal de contato** com o titular | [LGPD art. 41][lgpd]; [Res. 2/2022, art. 11][res2]; [Res. 18/2024][res18] |
| Escola | Só é controladora se decidir sobre o tratamento (por exemplo, publicar o app na conta dela). Depende de como o projeto for formalizado | Interpretação |

### 2.3 Pequeno porte (Res. CD/ANPD nº 2/2022)

- O art. 2º inclui expressamente "pessoas naturais". Para quem se enquadra,
  a resolução dá:
  - registro de operações simplificado;
  - dispensa de encarregado, mantido o canal de contato;
  - prazos em dobro.
- **Ficam de fora** os agentes que fazem tratamento de **alto risco** (art.
  3º). Alto risco exige um critério geral **e** um específico (art. 4º), e
  "dados pessoais de crianças, de adolescentes e de idosos" é um dos
  específicos.
- Com a idade mínima de 16, o app trata dados de adolescentes, e o critério
  específico já está preenchido. Somando local e horário de encontros
  presenciais e chat entre desconhecidos, o critério geral ("afetar
  significativamente interesses e direitos") também é provável. **Não
  contamos com o regime de pequeno porte.**
- **Por isso:** cumprir os prazos normais (sem o dobro), indicar um
  encarregado e manter o registro de operações completo, e não o
  simplificado.

---

## 3. Inventário: que dados o app trata hoje

Levantado no código. Este inventário é a base do ROPA (seção 7) e da
Política.

| Dado | Onde fica | Quem acessa | Para quê | O que acontece na exclusão da conta |
|---|---|---|---|---|
| E-mail, hash da senha, vínculo Google, datas de criação e último login, IPs | Firebase Auth (EUA) | O dono. O painel admin vê e-mail, verificação, provedores, datas e status (`functions/src/admin_auth_read.ts`) | Login e segurança | Conta apagada. O Google mantém backups por até 180 dias |
| Cópia do e-mail | `users/{uid}/private/contact` | Só o dono. **Nenhuma tela lê** | "Contato" | Apagada |
| Nome, @username, foto, esportes, bio, data de cadastro | `users/{uid}` | **Qualquer usuário logado** | Perfil público e busca | Apagado |
| Reserva do @username → uid | `usernames/{username}` | **Qualquer pessoa, mesmo sem login** (`read: if true`) | Checar disponibilidade no cadastro | Apagada |
| Foto de perfil (JPEG 512 px, sem EXIF) | Storage `users/{uid}/` | Qualquer logado. Cada troca cria um arquivo novo e **o antigo continua no bucket** | Perfil | Pasta inteira apagada |
| Criador e participantes do evento (id, nome, @, foto copiados) | `events/{id}` | Qualquer logado | Lista de participantes | **Ficam** |
| Membros, nome e foto copiados, última mensagem | `conversations/{id}` | Os 2 membros | Chat | **Ficam** |
| Mensagens (texto, remetente, horário) | `conversations/{id}/messages` | Os 2 membros. Não se editam nem se apagam | Chat | **Ficam** |
| Amizades | `friendships/{par}` | Os 2 | Amizades | Apagadas pelo gatilho `onProfileDeletedFriendships` |
| Avaliações (autor, alvo, nota, comentário) | `ratings` | Ninguém pelo app, só a callable | Médias | **Ficam, com o uid do autor** |
| Médias por alvo | `ratingSummaries` | Qualquer logado | Reputação | **Ficam** |
| Notificações | `users/{uid}/notifications` | O dono | Central de notificações | Apagadas |
| Registros administrativos (admin, alvo, motivo, status) | `adminOperations` | Ninguém pelo cliente | Auditoria de suspensões e exclusões | Ficam, **sem prazo definido** |
| Posição do GPS | Só na memória do app (`userPositionProvider`) | Ninguém | Ordenar eventos próximos | Não é gravada |
| IP, User-Agent e área do mapa vista | Servidores de tiles da OSMF | OSMF | Desenhar o mapa | Fora do nosso controle |
| IP para baixar fontes | Google Fonts (`google_fonts` baixa em tempo de execução) | Google | Tipografia | Fora do nosso controle |
| Atestado de integridade do aparelho | App Check / Play Integrity | Google | Antiabuso | Token de até 7 dias |

Nenhum dado é **sensível** no sentido do art. 5º, II, porque esportes
praticados não são dado de saúde. Isso muda se um dia entrar um campo de
saúde ou deficiência (paradesporto, por exemplo).

---

## 4. O que já está adequado

Vale mostrar isto à banca: o tratamento de dados já foi pensado no projeto,
só não estava documentado.

- **Exclusão de conta pelo próprio usuário** (`EditProfilePage` →
  `deleteAccount`):
  - reautentica antes de apagar;
  - apaga a foto, o perfil, o e-mail privado, as notificações e a reserva do
    @username;
  - o gatilho do servidor apaga as amizades;
  - o painel admin faz a mesma exclusão (`deleteUserAccount`), com motivo
    registrado.
- **Minimização do e-mail:** ele fica fora do perfil público
  (`users/{uid}/private/contact`, só o dono lê), por decisão registrada nas
  regras (RN-06).
- **Regras por papel no Firestore e no Storage:**
  - só o dono escreve o próprio perfil;
  - o chat é lido só pelos membros;
  - as avaliações só entram pela callable;
  - os registros administrativos não são acessíveis pelo cliente;
  - tudo coberto por testes nos emuladores (`tools/firestore-rules-tests/`).
- **Comentário de avaliação privado,** com aviso na tela
  (`RatingPrivacyNote`).
- **EXIF zerado** na foto de perfil (`lib/core/utils/avatar_image.dart`),
  então a localização da foto não vaza.
- **Localização só no aparelho:** o app usa o GPS para ordenar eventos e não
  grava a posição. Sem permissão, cai no centro de Taquara.
- **Sem Analytics, Crashlytics, anúncios ou venda de dados.**
- **Firestore e Functions em `southamerica-east1`** (São Paulo).
- **Texto de exclusão transparente:** o diálogo já avisa que eventos e
  mensagens continuam visíveis.

---

## 5. O que precisa mudar

Cada item traz o fundamento e onde mexer. **P0** é obrigatório para dizer que
o app está adequado e para publicar na Play Store. **P1** é obrigação da lei
que pode vir logo depois, incluindo as proteções para contas de 16 e 17
anos. **P2** é boa prática.

### P0 — obrigatório

#### 5.1 Idade mínima: 16 anos (decidido em 14/11/2026)

As opções avaliadas foram:

| Opção | Custo |
|---|---|
| 18+ | Menor. Afasta o critério "adolescentes" do alto risco, mas exclui boa parte do público do TCC |
| **16+ (escolhida)** | Médio. Contas de 16 e 17 anos são de adolescentes: valem as proteções do ECA Digital (seção 5.13) e o relatório de impacto |
| 12/13+ | Máximo: LGPD art. 14, supervisão parental e, se a ANPD considerar o app "rede social", vínculo da conta de menores de 16 com um responsável (ECA Digital art. 24) |

Por que 16 é um corte natural: menores de 16 são absolutamente incapazes
([Código Civil, art. 3º][cc]), e o aceite dos Termos por eles seria frágil
sem os pais (*interpretação*). O corte também afasta, na maior parte, o
vínculo com responsável do art. 24 do ECA Digital (ver a ressalva na seção
10).

**O que a decisão exige no cadastro (P0):**
- pedir a **data de nascimento** no cadastro por e-mail e no pós-Google, e
  recusar quem tiver menos de 16;
- integrar a **Play Age Signals API**. Se o sinal da loja divergir da data
  declarada, vale o mais protetivo ([Decreto 12.880, art. 25, §4º][dec12880]),
  e o usuário precisa de um meio de contestar a idade (art. 27);
- usar a idade **só para isso** ([ECA Digital art. 13][eca-digital];
  [Decreto 12.880, art. 24][dec12880]). Gravar a data num documento que só
  o dono lê, como `users/{uid}/private/age`, e nunca no perfil público. As
  regras podem consultá-lo com `get()` para aplicar os padrões protetivos sem
  revelar a idade a outros usuários;
- declarar na Play o público-alvo **16+** e responder o questionário de
  classificação (IARC/ClassInd). A faixa etária também vai nos Termos
  ([Decreto 12.880, art. 12, §4º][dec12880]).

Fontes:
- [LGPD art. 14][lgpd] e [Enunciado CD/ANPD nº 1/2023][enunciado1];
- [ECA Digital][eca-digital] e [Decreto 12.880/2026][dec12880];
- [Guia ANPD sobre o escopo do ECA Digital (out/2026)][guia-eca];
- [Play – público-alvo][play-target] e [Play Age Signals API][play-age].

#### 5.2 Política de Privacidade e Termos de Uso em página pública

- **Fundamento:**
  - [LGPD art. 9º][lgpd] (informação clara sobre finalidade, duração,
    controlador, contato, compartilhamento e direitos, com menção explícita
    ao art. 18);
  - [Marco Civil art. 7º, VI, VIII e XI][mci];
  - [Play – Dados do usuário][play-userdata]: URL pública, ativa, não PDF,
    com link no Console e dentro do app.
- **Onde:** uma página HTML no Firebase Hosting do projeto, que já serve o
  painel. Pode ser um segundo *target*, ou GitHub Pages.
- **Conteúdo mínimo:** seção 6.

#### 5.3 Ligar a política ao app e registrar o aceite

- `lib/features/auth/presentation/pages/login_page.dart:450` tem
  `// TODO: abrir URL da política de privacidade`. Ligar com `url_launcher`,
  que já é dependência.
- Trocar "Ao continuar, você concorda com nossa Política de Privacidade" por
  um **aceite destacado no cadastro**: uma caixa não marcada com "Li e aceito
  os Termos de Uso e a Política de Privacidade".
- **A base legal do app não é o consentimento,** e sim a execução do
  contrato, ou seja, dos Termos ([art. 7º, V][lgpd]). Por isso o texto não
  deve dizer "você consente com o tratamento". Basta registrar que a pessoa
  leu e aceitou.
- Gravar **data, hora e versão** aceitas, por exemplo em
  `users/{uid}/private/consent`. As regras de `private/{docId}` já deixam só
  o dono escrever ali. O ônus da prova é do controlador ([art. 8º, §2º][lgpd]
  e [art. 6º, X][lgpd]).
- Quando a política mudar, avisar e pedir novo aceite ([art. 8º, §6º, e
  art. 9º, §2º][lgpd]).

#### 5.4 Canal do titular e encarregado

- Criar um e-mail de privacidade do projeto.
- Designar por escrito (documento datado e assinado) um estudante como
  encarregado e outro como substituto
  ([Res. 18/2024, arts. 3º e 4º][res18]).
- Publicar o nome e o contato na política e na página web
  ([art. 41, §1º][lgpd]).

#### 5.5 Exclusão de conta completa, também pela web

- **Fundamento:**
  - [LGPD arts. 15 e 16][lgpd]: terminado o tratamento, os dados são
    eliminados, salvo obrigação legal, pesquisa, transferência ou uso
    exclusivo do controlador **anonimizado**;
  - [Marco Civil art. 7º, X][mci]: exclusão definitiva dos dados fornecidos;
  - [Play – exclusão de conta][play-deletion]: dentro do app **e** por link
    web que funcione sem reinstalar o app, apagando os dados associados.
- **O que mudar no código:**
  1. **Cascata no servidor.** Seguir o modelo de `onProfileDeletedFriendships`
     e criar um gatilho `onDocumentDeleted('users/{uid}')` que:
     - troque o `UserSummary` do usuário (nome, @ e foto) por "Conta
       excluída" em `events.creator`, `events.participants` e
       `conversations.memberSummaries`;
     - tire o usuário dos eventos **futuros**, devolvendo a vaga;
     - cancele os eventos futuros que ele criou, avisando os participantes;
     - apague as **mensagens que ele enviou**;
     - apague o comentário e o uid do autor nas avaliações, mantendo só a
       nota agregada;
     - apague o `ratingSummaries` dele.

     Sendo no servidor, a mesma limpeza vale para a exclusão pelo app e pelo
     painel.
  2. **Mensagens: a recomendação é apagar.** Só trocar o nome por "Conta
     excluída" não anonimiza, porque o texto pode identificar a pessoa, e o
     art. 16, IV, só permite guardar dado anonimizado e de uso exclusivo do
     controlador, enquanto aqui o outro membro continuaria lendo. Se a equipe
     preferir manter as mensagens para o outro lado, tem de **dizer isso na
     política** e justificar.
  3. **Página web "Excluir minha conta"** (formulário ou e-mail) e link no
     Play Console.
  4. **Atalho "Excluir conta" em Configurações** (`/home/configuracoes` hoje
     é `UnderConstructionPage`). A Play pede que o caminho seja fácil de
     achar, e o [Decreto 12.880, art. 10][dec12880] veda dificultar controles
     de privacidade.
  5. **Atualizar o texto `profileDeleteAccountBody`** quando o comportamento
     mudar.

#### 5.6 Aviso antes do pedido de localização

- **Fundamento:**
  - [Play – divulgação em destaque e permissões de localização][play-location];
  - [LGPD art. 9º][lgpd], que exige informação prévia.
- **O que fazer:**
  - mostrar uma tela curta antes do diálogo do Android, dizendo para que a
    localização serve, que é opcional e que **não sai do aparelho**. Fica no
    `userPositionProvider`, em `lib/core/providers/location_providers.dart`;
  - permitir usar o app sem a permissão (isso já acontece com o fallback).
- **Avaliar** se `ACCESS_COARSE_LOCATION` basta para "eventos próximos" em
  Taquara, pelo princípio da necessidade e pela regra da Play de pedir o
  escopo mínimo. Hoje o app pede a precisa (`LocationAccuracy.high`).

#### 5.7 Denunciar e bloquear

- **Fundamento:**
  - [Play – conteúdo gerado pelo usuário][play-ugc]: chat 1:1 exige
    **bloqueio**, e conteúdo visível aos outros (perfis, eventos) exige
    **denúncia**;
  - [ECA Digital arts. 27–30][eca-digital]: canal de denúncia, retirada sem
    ordem judicial e direito do autor de contestar. O art. 27 vale para
    qualquer fornecedor.
- **Situação atual:** o app não tem nenhuma das duas coisas.
- **O que fazer:**
  - "Denunciar" em perfil, mensagem, evento e avaliação;
  - "Bloquear usuário", que esconde e impede mensagens;
  - uma fila de denúncias no painel admin, com prazo de retenção definido;
  - nos Termos, dizer que os admins só veem conteúdo de chat a partir de uma
    denúncia ([Marco Civil art. 7º, II e III][mci], sigilo das
    comunicações).

#### 5.8 Formulário "Segurança dos dados" da Play

O formulário é obrigatório e inclui o que os SDKs enviam ([Data
safety][play-datasafety]). Os dados mandados ao Google como prestador contam
como **coleta**, não como compartilhamento. Rascunho:

| Categoria | Declarar? |
|---|---|
| Informações pessoais: nome, e-mail, IDs de usuário, outras (bio, esportes) | Sim, coletado |
| Fotos | Sim, coletado e opcional |
| Mensagens no app | Sim, coletado |
| Atividade no app (eventos, avaliações) | Sim, coletado |
| Localização | Não, enquanto a posição só for usada no aparelho. Reavaliar se um dia for enviada |
| IDs do dispositivo | Conferir o que o App Check / Play Integrity envia |
| Compartilhado com terceiros | Não |
| Criptografado em trânsito | Sim |
| Pode pedir exclusão | Sim, no app e na web |

### P1 — obrigação da lei, logo depois

#### 5.9 Direitos do titular dentro do app

- **Fundamento:** [LGPD arts. 18 e 19][lgpd]. A declaração completa tem prazo
  de 15 dias e o acesso simplificado é imediato. Os demais pedidos ainda não
  têm prazo regulamentado.
- **Configurações → Privacidade:**
  - Política e Termos;
  - "Baixar meus dados";
  - revogar a permissão de localização (levar às configurações do aparelho);
  - "Excluir conta";
  - contato do encarregado.
- **"Baixar meus dados":** uma callable que monte um JSON com perfil, e-mail,
  eventos criados e participados, mensagens enviadas, amizades, avaliações
  feitas e médias recebidas ([art. 18, II e V; art. 19, §3º][lgpd]).
  Decidir se entram os comentários recebidos, pesando a privacidade de quem
  avaliou.
- **Correção:** a edição de perfil já atende. O @username hoje não pode ser
  trocado, o que é aceitável enquanto o usuário puder pedir a correção pelo
  canal.
- **Planilha de pedidos** (data, titular, pedido, resposta), para provar o
  cumprimento.

#### 5.10 Tabela de retenção

- **Fundamento:**
  - [LGPD arts. 15 e 16][lgpd];
  - [Decreto 8.771/2016, art. 13, §2º][dec8771], que manda reter o mínimo.
- **Marco Civil:** a guarda de registros de acesso por 6 meses ([art.
  15][mci]) obriga só pessoa jurídica com fins econômicos, então **não nos
  obriga**. Não devemos criar logs próprios de IP.
- **Proposta, a decidir pela equipe:**

| Dado | Prazo |
|---|---|
| Conta e perfil | Enquanto a conta existir |
| Conta sem login há 24 meses | Aviso por e-mail e exclusão 30 dias depois |
| Notificações | 90 dias |
| Fotos de perfil substituídas | Apagar a antiga quando nenhum evento ou conversa futura apontar para ela (hoje ficam para sempre) |
| Denúncias encerradas | 12 meses |
| `adminOperations` | 5 anos (definir e documentar; hoje não tem prazo) |
| Denúncia de abuso sexual infantil | 6 meses, prorrogáveis a pedido da autoridade ([ECA Digital art. 27, §2º][eca-digital]) |
| Registro de incidentes | 5 anos ([Res. 15/2024, art. 10][res15]) |
| Firebase Auth após a exclusão | Até 180 dias nos backups do Google ([Firebase privacy][firebase-privacy]) |

#### 5.11 Transferência internacional na política

- **Fundamento:**
  - [LGPD art. 33][lgpd];
  - [Res. CD/ANPD nº 19/2024, art. 17][res19]: publicar, em português, o
    país de destino, a finalidade, o mecanismo e os direitos, e entregar a
    íntegra das cláusulas em 15 dias se pedirem.
- **Dados:** o Firebase Authentication roda só nos EUA, e os EUA não têm
  decisão de adequação. Auth, Firestore, Storage e Functions seguem o [Cloud
  Data Processing Addendum][cloud-dpa], cuja seção "Brazil" incorpora as
  [cláusulas-padrão brasileiras][br-sccs]. O Hosting segue os [termos do
  Firebase][firebase-dpst], ainda sem cláusula brasileira; ele só recebe IP
  de acesso.
- **Conferir no console** em que região está o bucket do Storage. As
  Functions já usam `southamerica-east1` via `setGlobalOptions` e
  `administrativeFunctionsRegion`.

#### 5.12 Segurança e incidentes

- **Fundamento:**
  - [LGPD arts. 46–49][lgpd];
  - [Decreto 8.771/2016, art. 13][dec8771];
  - [Res. CD/ANPD nº 15/2024][res15]: comunicar à ANPD e aos titulares em
    **3 dias úteis** (6 para pequeno porte) quando o incidente puder causar
    dano relevante. **Dados de autenticação e de adolescentes** entram nesse
    critério.
- **O que fazer:**
  - **Plano de incidentes de 1 página:** quem decide, como avaliar o risco,
    um modelo de mensagem aos usuários, o [formulário da
    ANPD][anpd-incidente] e uma planilha de registro guardada por 5 anos;
  - **Política de segurança simplificada**, seguindo o [Guia de segurança
    para pequeno porte][guia-seguranca];
  - **2FA** nas contas Google com acesso ao `compy-tcc` e revisão do IAM;
  - **App Check com imposição** depois da distribuição pela Play (ver
    `checklist-publicacao.md`). Hoje `submitEventRatings` roda com
    `enforceAppCheck: false`.

### P1 — contas de 16 e 17 anos

#### 5.13 Proteções do ECA Digital para adolescentes

Obrigatórias desde a decisão pelos 16+. A aferição de idade no cadastro já
está na seção 5.1.


- **Fundamento:** [Lei 15.211/2025, arts. 7º, 8º, 12–17 e 27–30][eca-digital]
  e [Decreto 12.880/2026, arts. 9º, 10, 24–27 e 47][dec12880]. Segundo o
  cronograma da [ANPD][anpd-eca], a fiscalização ampla começa em jan/2027.
  Sem faturamento, a multa vai de R$ 10 a R$ 1.000 **por usuário
  cadastrado** ([art. 35][eca-digital]).
- **Padrões protetivos** para contas de 16 e 17 anos ([ECA Digital arts. 7º
  e 17, §4º][eca-digital]), aplicados nas regras do Firestore e não só na
  tela:
  - perfil visível só para amigos e para quem está nos mesmos eventos;
  - chat só com amigos ou com quem está no mesmo evento;
  - lista de participantes menores escondida de desconhecidos;
  - localização desligada por padrão;
  - relaxar um padrão só por escolha informada do próprio usuário (art. 7º).
- **Quando fizer 18,** os padrões deixam de valer. Avisar o usuário e
  oferecer as opções, sem mudar a visibilidade sozinho.
- **Documentos e páginas:**
  - procedimento escrito para conteúdo de abuso sexual infantil e
    aliciamento: remover, preservar, comunicar à Polícia Federal e reter por
    6 meses;
  - página "Segurança e orientação para pais e responsáveis", com a faixa
    etária indicada;
  - avaliação de impacto de 2 a 4 páginas, que também serve como RIPD, com
    resumo público.

### P2 — boa prática

#### 5.14 Minimização e ajustes pequenos

- **`users/{uid}/private/contact`:** guarda o e-mail, mas nenhuma tela o lê,
  e o Auth já tem o dado. Ou se registra a finalidade, ou se deixa de gravar
  ([art. 6º, III][lgpd], necessidade).
- **`usernames` com `read: if true`:** qualquer pessoa, sem login, mapeia
  @username → uid. Uma callable `isUsernameAvailable` que devolva só
  verdadeiro ou falso reduz a exposição. Se ficar como está, registrar o
  motivo (a regra já comenta isso).
- **OpenStreetMap** ([política de tiles][osm-tiles];
  [atribuição][osm-attribution]):
  - `userAgentPackageName` está `br.com.compy.mvp` em quatro mapas, mas o
    pacote real é `br.com.compy.app`;
  - **o app não mostra "© OpenStreetMap contributors"** em nenhum mapa, e
    essa atribuição é obrigação da licença ODbL. O `flutter_map` tem o
    `RichAttributionWidget` para isso;
  - citar a OSMF na política.
- **`google_fonts`** baixa as fontes do Google em tempo de execução, o que
  envia o IP do usuário. Empacotar as fontes nos assets resolve e ainda
  funciona offline.
- **Backup do Android:** o `AndroidManifest.xml` não define
  `android:allowBackup`, que por padrão é `true`, então o cache local do
  Firestore pode ir para o backup do Google Drive do usuário. Avaliar
  `allowBackup="false"` ou regras de extração de dados.
- **Logs:** `debugPrint` com uid também sai no build de release, no logcat.
  Trocar por uma mensagem sem identificador, ou deixar só no modo debug.
- **Futuro push (FCM):** se entrar (roadmap, item D), o token do aparelho
  vira dado pessoal. Atualizar a política, o formulário da Play e o ROPA.

---

## 6. O que a Política de Privacidade precisa dizer

Fontes: [LGPD art. 9º][lgpd], [art. 18][lgpd], [Res. 19/2024, art.
17][res19], [Res. 18/2024, art. 9º][res18] e [Play – Dados do
usuário][play-userdata].

1. **Quem somos:** nomes dos controladores, a escola só como contexto,
   e-mail de privacidade e encarregado.
2. **Quais dados**, separados por função: conta, perfil, foto, eventos,
   chat, amizades, avaliações, denúncias e dados técnicos (IP, App Check).
   Dizer que a localização é usada só no aparelho e não é gravada, e que o
   EXIF da foto é removido.
3. **Para que serve cada dado e qual a base legal:**

   | Uso | Base legal |
   |---|---|
   | Conta, perfil, eventos, chat, amizades e avaliações | Execução dos Termos, [art. 7º, V][lgpd] |
   | Localização do aparelho | Consentimento, pela permissão do Android, [art. 7º, I][lgpd] |
   | Segurança, moderação e médias de avaliação | Legítimo interesse, [art. 7º, IX][lgpd], com teste de balanceamento documentado ([Guia de legítimo interesse][guia-li]) |
   | Abuso sexual infantil e respostas à ANPD | Obrigação legal, [art. 7º, II][lgpd] |

4. **O que os outros usuários veem:**
   - qualquer usuário logado vê o perfil, a participação em eventos e as
     médias;
   - a conversa é vista só pelos dois membros;
   - o comentário da avaliação não aparece para ninguém.
5. **Com quem os dados ficam:**
   - Google/Firebase, como operador;
   - Login com Google;
   - tiles da OSMF, com link para a política dela.
6. **Transferência internacional:** EUA (Firebase Auth), finalidade, as
   cláusulas-padrão da ANPD no contrato do Google e como pedir a íntegra.
7. **Retenção e exclusão:** a tabela da seção 5.10, o que a exclusão da conta
   apaga, o que fica anonimizado e os 180 dias de backup do Google.
8. **Segurança:** um resumo do que fazemos.
9. **Direitos do art. 18, um a um:** como pedir e em que prazo, mais o
   direito de reclamar à ANPD e aos órgãos de defesa do consumidor
   ([art. 18, §§1º e 8º][lgpd]).
10. **Idade mínima** e como ela é verificada.
11. **Moderação:** quando os admins podem ver conteúdo (só após denúncia) e
    como denunciar e bloquear.
12. **Mudanças na política:** como avisamos, e a **data da versão**.

---

## 7. Documentos de governança

Nenhum deles é código, e todos cabem como anexo do TCC. São o que a ANPD pede
numa fiscalização, e ter tudo documentado atenua sanções ([LGPD art. 52,
§1º][lgpd]; [Res. 4/2023][res4]).

| Documento | Base | Tamanho |
|---|---|---|
| Registro das operações (ROPA), pelo [modelo da ANPD para pequeno porte][ropa] | [LGPD art. 37][lgpd]; [Res. 2/2022, art. 9º][res2] | 1 linha por tratamento da seção 3 |
| Testes de balanceamento do legítimo interesse (moderação, médias, segurança) | [LGPD art. 10][lgpd]; [Guia de legítimo interesse][guia-li] | 1 página cada |
| Tabela de retenção | Seção 5.10 | 1 página |
| Plano de resposta a incidentes e planilha de registro | [Res. 15/2024][res15] | 1 página |
| Política de segurança simplificada | [Res. 2/2022, arts. 12–13][res2]; [Guia de segurança][guia-seguranca] | 1 a 2 páginas |
| Designação do encarregado e divisão de responsabilidades entre os estudantes | [Res. 18/2024][res18]; [LGPD art. 42][lgpd] | 1 página |
| RIPD + avaliação de impacto do ECA Digital (obrigatória com os 16+) | [LGPD art. 38][lgpd]; [ECA Digital art. 16][eca-digital]; [Decreto 12.880, art. 47][dec12880] | 2 a 4 páginas, com resumo público |

---

## 8. Ordem sugerida de trabalho

1. ~~Decidir a idade mínima~~: **16 anos**, decidido em 14/11/2026 (5.1).
2. **Política, Termos, e-mail de privacidade e encarregado** (5.2, 5.4, 6).
   Os Termos já saem com a idade mínima e a faixa etária.
3. **Cadastro:** link da política, aceite registrado, data de nascimento com
   bloqueio abaixo de 16 e Play Age Signals (5.1, 5.3).
4. **Tela de Configurações → Privacidade** (5.9).
5. **Cascata de exclusão no servidor e página web de exclusão** (5.5).
6. **Denunciar e bloquear, com fila no painel** (5.7).
7. **Padrões protetivos para contas de 16 e 17 anos nas regras** (5.13).
8. **Aviso de localização, atribuição e User-Agent do OSM** (5.6, 5.14).
9. **"Baixar meus dados"** (5.9).
10. **Documentos:** seção 7, avaliação de impacto, página para pais e
    procedimento de abuso infantil (5.13), e o formulário da Play (5.8).

---

## 9. Para responder à avaliadora

> O COMPY trata dados pessoais e está sujeito à LGPD: a exceção acadêmica não
> cobre a operação de um app com usuários reais. Nós, estudantes, somos os
> controladores, e o Google/Firebase é o operador.
>
> Desde o início adotamos privacidade por padrão:
> - o e-mail fica fora do perfil público;
> - o chat é visível só aos participantes;
> - o comentário das avaliações é privado;
> - a foto vai sem metadados de localização;
> - a localização do celular não é gravada;
> - não usamos rastreamento nem anúncios;
> - o usuário pode excluir a própria conta no app;
> - as regras de acesso do banco são testadas automaticamente.
>
> Fizemos um diagnóstico com base na lei e nas orientações da ANPD e temos um
> plano para o que falta:
> - política de privacidade e termos públicos;
> - canal com o encarregado;
> - exportação dos dados;
> - exclusão que também anonimiza o que fica em eventos e conversas;
> - denúncia e bloqueio;
> - idade mínima de 16 anos, com verificação no cadastro e configurações
>   mais protetivas para quem tem 16 e 17, por causa do ECA Digital;
> - registro das operações e plano de incidentes.

---

## 10. Pontos em aberto

- **Alto risco com adolescentes:** se um app pequeno com adolescentes, chat e
  encontros presenciais é de "alto risco" (Res. 2/2022, art. 4º) ainda não
  foi decidido pela ANPD. Com os 16+, tratamos como se fosse.
- **"Rede social" no ECA Digital:** se o COMPY é "rede social" (art. 2º, III,
  e art. 24) é incerto. O Guia de out/2026 pesa a favor de "não", porque a
  finalidade principal são os eventos, mas a ANPD pode decidir de outra
  forma. Se decidir que é, o corte nos 16 tem uma brecha: a lei fala em
  contas "de até 16 (dezesseis) anos", o que pode incluir quem tem 16,
  enquanto o FAQ da ANPD diz "menores de 16". Nesse caso, as contas de 16
  anos precisariam de vínculo com um responsável.
- **Modulação do ECA Digital:** ainda não há critério objetivo para modular
  as obrigações a um fornecedor minúsculo e sem fins lucrativos (art. 39,
  §3º).
- **Aferição de idade:** a ANPD ainda consolida o guia definitivo. A
  suficiência de "data de nascimento + Play Age Signals" é interpretação.
- **Prazos do art. 18:** além do acesso (art. 19), não há regulamento de
  prazos nem de portabilidade.
- **Papel da escola:** depende de como o projeto for formalizado.

---

[lgpd]: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
[mci]: https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2014/lei/l12965.htm
[dec8771]: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2016/decreto/d8771.htm
[cc]: https://www.planalto.gov.br/ccivil_03/leis/2002/l10406compilada.htm
[eca-digital]: https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/lei/L15211.htm
[dec12880]: https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2026/decreto/D12880.htm
[guia-academico]: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-orientativo-tratamento-de-dados-pessoais-para-fins-academicos-e-para-a-realizacao-de-estudos-e-pesquisas
[guia-agentes]: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-orientativo-para-definicoes-dos-agentes-de-tratamento-de-dados-pessoais-e-do-encarregado
[guia-li]: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia_orientativo_hipoteses_legais_tratamento_de_dados_pessoais_legitimo_interesse
[guia-seguranca]: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-orientativo-sobre-seguranca-da-informacao-para-agentes-de-tratamento-de-pequeno-porte
[guia-eca]: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-fornecedores-de-produtos-ou-servicos-de-tecnologia-da-informacao.pdf
[anpd-eca]: https://www.gov.br/anpd/pt-br/assuntos/eca-digital
[anpd-incidente]: https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis/comunicacao-de-incidentes-de-seguranca
[ropa]: https://www.gov.br/anpd/pt-br/centrais-de-conteudo/modelo_de_ropa_para_atpp.pdf/@@display-file/file
[res2]: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022
[res4]: https://bibliotecadigital.mj.gov.br/bitstream/1/9179/2/RES_ANPD_2023_4.html
[res15]: https://bibliotecadigital.mj.gov.br/bitstream/1/12879/2/RES_ANPD_2024_15.html
[res18]: https://bibliotecadigital.mj.gov.br/bitstream/1/13151/1/RES_ANPD_2024_18.html
[res19]: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024
[enunciado1]: https://bibliotecadigital.mj.gov.br/bitstream/1/10215/2/Enunciado_ANPD_2023_1.html
[firebase-privacy]: https://firebase.google.com/support/privacy
[firebase-dpst]: https://firebase.google.com/terms/data-processing-terms
[cloud-dpa]: https://cloud.google.com/terms/data-processing-addendum
[br-sccs]: https://cloud.google.com/sccs/br-c2p
[play-userdata]: https://support.google.com/googleplay/android-developer/answer/10144311
[play-deletion]: https://support.google.com/googleplay/android-developer/answer/13327111
[play-location]: https://support.google.com/googleplay/android-developer/answer/9799150
[play-datasafety]: https://support.google.com/googleplay/android-developer/answer/10787469
[play-ugc]: https://support.google.com/googleplay/android-developer/answer/9876937
[play-target]: https://support.google.com/googleplay/android-developer/answer/9867159
[play-age]: https://developer.android.com/google/play/age-signals/use-age-signals-api
[osm-tiles]: https://operations.osmfoundation.org/policies/tiles/
[osm-attribution]: https://osmfoundation.org/wiki/Licence/Attribution_Guidelines
[osmf-privacy]: https://osmfoundation.org/wiki/Privacy_Policy
