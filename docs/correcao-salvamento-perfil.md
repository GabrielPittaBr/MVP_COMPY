# Correção do salvamento de perfil — 28/10/2026

## Causa e evidências

A release ativa do Firestore de `compy-tcc` ainda não permite o campo `bio`.
A leitura foi feita pela API de Rules usando a sessão existente do Firebase
CLI, somente com operações de consulta; não lemos perfis de produção.

- Release: `projects/compy-tcc/releases/cloud.firestore`.
- Ruleset: `projects/compy-tcc/rulesets/9dfdcfde-729e-4e79-a012-8eaab57086a9`.
- Última atualização: `2026-10-22T21:31:09.650697Z`.
- SHA-256 do arquivo retornado: `3C68F6F015499FC5689DEFB94E6FA0B02E4240CD106314393240B8C8393FA409`.
- A comparação com `firestore.rules` local mostrou apenas a inclusão de `bio`
  no `hasOnly` e sua validação como texto opcional de até 160 caracteres.

O teste `profile-save.test.js` carrega um recorte literal do contrato publicado
no emulador e envia o payload do app com um usuário autenticado pelo emulador
Auth. O resultado técnico capturado foi **`FirebaseError code=permission-denied`**
(SDK JavaScript; gRPC `7 PERMISSION_DENIED`). Ocorre com bio preenchida e
também vazia. A leitura posterior confirma que o documento não foi alterado.
Com a regra local, o mesmo fluxo grava os dados, sincroniza o Auth e permite
que outro usuário leia o perfil atualizado.

Isso comprova a incompatibilidade de contrato publicada que bloqueia a
operação. Não é uma captura do Android real: `adb devices` não encontrou
aparelho conectado. A versão instalada e seu log permanecem pendentes.

## Fluxo rastreado antes da alteração

1. `EditProfilePage._saveDetails()` valida nome e biografia, resolve o UID
   autenticado e chama `profileDetailsControllerProvider`.
2. O controller chama `UpdateProfileDetails`, que delega para
   `ProfileRepositoryImpl.updateDetails()`.
3. O repository valida nome não vazio e os limites 60/160.
4. `ProfileRemoteDataSource` compara o UID com `FirebaseAuth.currentUser.uid`
   e faz `set(..., merge: true)` em `users/{uid}` com **name, nameLower e bio**.
5. As regras avaliam o documento completo após o merge. A regra publicada
   recusa `bio` antes de a operação chegar à sincronização no Auth. O
   normalizador pt-BR de `nameLower` é usado normalmente; a rejeição
   reproduzida não depende de erro de UID, sessão ou nome inválido.
6. Depois da gravação, o nome alterado é sincronizado com
   `User.updateDisplayName()`. Não há transação entre os dois serviços.
7. Perfil próprio, perfil público e busca são invalidados para nova leitura.

O payload contém `bio` mesmo quando só o nome foi editado. Portanto, omitir
somente a biografia vazia não resolveria a funcionalidade. As regras locais
já têm o contrato correto e não precisaram de alteração nem ampliação de
permissões nesta correção.

## Correção no aplicativo

A branch foi criada sobre `origin/develop` atualizado (`59bace5`), com árvore
limpa. Reaproveitamos, sem criar um commit intermediário, a correção existente
`28287a4`, ainda ausente de develop. A branch original
`fix/mapa-nivel-eventos` e seus commits foram preservados.

- Somente bio não solicita sincronização quando o nome já está consistente; somente nome e ambos
  continuam suportados. Nome é aparado, bio pode ser vazia, limites 60/160
  permanecem. Username, esportes e o fluxo de foto são preservados.
- Falha do Firestore impede a chamada ao Auth. Falha posterior do Auth gera
  `ProfileAuthSyncException`, preservando a causa técnica e o stack trace.
  A UI informa que o perfil foi gravado, mas a sincronização ficou pendente.
- A tentativa parcial guarda como base os dados efetivamente gravados e
  mantém o botão disponível. Voltar aos textos anteriores não esconde mais
  uma alteração já persistida. Reabrir a página na mesma sessão mantém a
  sincronização pendente por UID no controller. Após reiniciar o app, a
  comparação do perfil com o nome da sessão autenticada permite concluir
  uma sincronização que ficou pendente, sem armazenamento local adicional.
- Falhas preservam o texto e permitem repetir. O UID resolvido precisa
  corresponder ao perfil que preencheu o formulário; a guarda no datasource
  também verifica a conta efetivamente autenticada antes de escrever.
- Logs identificam resolução de sessão, identidade, Firestore ou Auth,
  incluindo plugin/código de `FirebaseException`, sem imprimir payload,
  mensagem bruta da exceção, UID, nome, bio, e-mail ou tokens na interface ou
  no diagnóstico. A UI usa as mensagens de `AppStrings`.

## Arquivos alterados

- Aplicativo: `lib/core/constants/app_strings.dart`,
  `lib/core/utils/firebase_errors.dart`,
  `lib/features/profile/data/datasources/profile_remote_datasource.dart`,
  `lib/features/profile/data/repositories/profile_repository_impl.dart`,
  `lib/features/profile/domain/repositories/profile_repository.dart`,
  `lib/features/profile/domain/usecases/update_profile_details.dart`,
  `lib/features/profile/presentation/pages/edit_profile_page.dart` e
  `lib/features/profile/presentation/providers/profile_providers.dart`.
- Flutter: `test/core/utils/firebase_errors_test.dart` e
  `test/features/profile/{edit_profile_page_test,update_profile_details_test,profile_remote_datasource_test}.dart`.
- Emuladores: `tools/firestore-rules-tests/{package.json,users.test.js,profile-save.test.js,README.md}`
  e `tools/firestore-rules-tests/fixtures/users-before-bio.rules` (fixture
  histórica, nunca publicar).
- Documentação: este relatório, `docs/autenticacao.md`, `docs/roadmap.md`,
  `docs/caderno_de_campo/Anotacoes10282026.md` e a nota original da correção
  reaproveitada, `docs/caderno_de_campo/Anotacoes10252026.md`.

## Validação

- `flutter test`: **404 testes passaram** na suíte completa final, incluindo
  sessão ausente/trocada e recuperação da sincronização após reiniciar o app.
  A execução específica de
  `flutter test test/features/profile/edit_profile_page_test.dart` também
  passou com **25 testes**.
- `dart analyze lib test`: **exit code 0**, sem erros ou warnings;
  10 informações preexistentes (`const` e `withOpacity`) em arquivos fora
  desta alteração.
- `npm test --prefix tools/firestore-rules-tests`: **200 testes passaram**,
  sem falhas/cancelamentos/ignorados, com Auth, Firestore e Storage sob
  `demo-compy`. Inclui perfis novos e legados sem `nameLower`, bio ausente e
  vazia, somente nome/bio/ambos, limites, leitura pública e negações de acesso.
- Os testes Dart do datasource verificam o payload real, merge, normalização,
  UID, ausência de sessão, códigos de exceção e chamada idempotente ao Auth.
  Repository/controller/widget cobrem falhas de cada etapa, estado parcial,
  preservação de texto e repetição, e atualização dos providers.

O Flutter exigiu o alias 8.3 já existente do SDK
(`C:/Users/BERNAR~1/develop/flutter`) para contornar o hook `objective_c`
que falha com espaços no caminho. O emulador iniciou com Java 25 e
`JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:/jtmp`, somente no processo
de teste, contornando o erro local de socket de loopback. Nenhuma configuração
do aplicativo, de autenticação, de assinatura ou de produção foi alterada.

## Pendências para concluir a correção no ambiente real

1. Publicar **as regras locais já validadas**, em etapa separada e autorizada,
   e conferir o novo ruleset ativo. Sem isso, o Firebase publicado continuará
   rejeitando `bio`, independentemente de instalar um APK novo.
2. Conferir qual APK está instalado, seu commit de origem e a configuração
   de Firebase usada. `version: 0.1.0+1` sozinho não identifica o código,
   pois o número não foi atualizado nas correções locais anteriores.
3. No Android real, testar somente bio, somente nome, ambos e apagar bio;
   sair/reentrar e conferir o perfil pela conta de outro usuário. Em falha,
   capturar o log `ProfileDetails` para distinguir escrita de sincronização.
4. Testar perda de conexão e repetição após falha parcial, inclusive reabrindo
   o editor e reiniciando o app. O Firestore preserva os dados já gravados;
   a sessão autenticada permite detectar a divergência de nome ao reabrir.

Não houve merge, push, deploy nem escrita em dados reais de produção.
