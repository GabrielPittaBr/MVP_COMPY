# Guia do Play Console para a LGPD — COMPY

O que preencher no Play Console para a privacidade, na ordem de **Conteúdo do
app** (Painel → Política → Conteúdo do app). O resto da publicação (conta de
desenvolvedor, AAB, Play App Signing e SHA-1 no Firebase) está em
`docs/checklist-publicacao.md`.

## Links

| Campo | Valor |
|---|---|
| Política de privacidade | https://compy-tcc.web.app/privacidade |
| Exclusão de conta (Segurança dos dados) | https://compy-tcc.web.app/excluir-conta |
| E-mail de contato do desenvolvedor | contato.compy@gmail.com |
| Padrões de segurança infantil (se a categoria for "Social") | https://compy-tcc.web.app/seguranca |

## Acesso ao app

O app exige login. Crie uma conta de teste **adulta** pelo próprio app (data
de nascimento com 18+, aceite marcado) e informe e-mail e senha em "Acesso ao
app". Não use conta pessoal.

## Anúncios

"Não, meu app não contém anúncios."

## Público-alvo e conteúdo

- **Faixas etárias:** marcar só **16–17** e **18 anos ou mais**. Não marcar
  13–15 nem menores: o app recusa quem tem menos de 16, e assim a política de
  Famílias não se aplica.
- "O app pode atrair crianças?" **Não**.
- A Play não deixa usar a restrição de menores (só vale para público 18+); a
  proteção de 16–17 está no próprio app.

## Classificação de conteúdo (questionário IARC → ClassInd)

- Categoria: **Esportes** (ou "Social"; nesse caso preencha também os Padrões
  de segurança infantil com o link acima).
- Usuários interagem ou trocam conteúdo: **Sim** (chat 1:1, eventos,
  avaliações).
- Compartilha a localização do usuário com outros usuários: **Não** (a
  posição fica no aparelho; o que é público é o local do evento).
- Compras digitais, jogos de azar, violência, conteúdo sexual: **Não**.

## Segurança dos dados

Os dados enviados ao Google como prestador (Firebase) contam como
**coletados**, não como **compartilhados**.

- O app coleta ou compartilha dados? **Sim, coleta.**
- Compartilha com terceiros? **Não.**
- Todos os dados são criptografados em trânsito? **Sim.**
- Os usuários podem pedir a exclusão dos dados? **Sim** (no app e pelo link
  acima).

| Categoria → tipo | Coletado | Obrigatório? | Finalidades |
|---|---|---|---|
| Informações pessoais → Nome | Sim | Obrigatório | Funcionalidade do app; Gerenciamento da conta |
| Informações pessoais → Endereço de e-mail | Sim | Obrigatório | Gerenciamento da conta |
| Informações pessoais → IDs do usuário | Sim | Obrigatório | Funcionalidade do app; Gerenciamento da conta; Prevenção de fraudes, segurança e conformidade |
| Informações pessoais → Outras informações (data de nascimento, @username, bio, esportes) | Sim | Obrigatório (bio e esportes opcionais) | Funcionalidade do app; Prevenção de fraudes, segurança e conformidade |
| Fotos e vídeos → Fotos | Sim | Opcional | Funcionalidade do app |
| Mensagens → Outras mensagens no app | Sim | Opcional | Funcionalidade do app |
| Atividade no app → Outro conteúdo gerado pelo usuário (eventos, avaliações, denúncias) | Sim | Opcional | Funcionalidade do app; Prevenção de fraudes, segurança e conformidade |
| IDs do dispositivo ou outros IDs (ID de instalação do Firebase, token do FCM que o SDK de Functions envia, token do Play Integrity) | Sim | Obrigatório | Funcionalidade do app; Prevenção de fraudes, segurança e conformidade |
| Localização | **Não** | — | Processada só no aparelho, não precisa ser declarada |

Fonte dos tipos coletados pelos SDKs:
[Firebase — divulgação para a Segurança dos dados](https://firebase.google.com/docs/android/play-data-disclosure).

## Sinal de idade (ECA Digital)

- O app já chama a Play Age Signals API (`MainActivity.kt`). Ela só responde
  para quem instalou pela Play.
- Em **Painel → Sinais de idade**, não precisa configurar faixas próprias:
  as faixas padrão (0–12, 13–15, 16–17, 18+) já servem ao corte de 16.

## Antes de enviar a versão

1. Publicar regras, índices, Functions e as páginas (feito em 14/11/2026 —
   ver `docs/lgpd.md`).
2. Subir a versão no `pubspec.yaml` (o `+N` precisa crescer) e gerar o AAB com
   `flutter build appbundle`.
3. Conferir que a política abre pelo link do login e pelas Configurações.
