# 10: Proteger acesso e entregar shell do Painel Administrativo

Status: resolved

Blocked by: 01 — Criar a fundação Flutter Web do Painel Administrativo

Spec: §§ 3, 4, 21 e Testing Decisions / Painel Flutter Web.

**What to build:** O Painel Administrativo passa a oferecer login por e-mail e senha, sessão por navegador, guard de claim e shell responsivo. O resultado demonstrável é que somente Administradores qualificados chegam a rotas administrativas, inclusive por deep link.

## Acceptance criteria

- [x] `/login` autentica somente com e-mail e senha e não oferece cadastro ou Google Sign-In.
- [x] Inicialização permanece em loading integral até resolver Firebase Auth, atualização de token, provider password, e-mail verificado e claim `admin`.
- [x] Ausência de requisito administrativo encerra a sessão, limpa estado e direciona para `/unauthorized` com retorno ao login.
- [x] `/login` e `/unauthorized` são públicas; dashboard, locais e usuários exigem o mesmo guard inclusive em deep link.
- [x] Persistência Auth é `SESSION`.
- [x] Shell usa Material 3, sidebar desktop/recolhível, cabeçalho e logout acessível, sem bottom navigation.
- [x] Guard, login, logout, unauthorized, loading, deep links, teclado e foco possuem cobertura de testes.

## Verification

- [x] Executar análise e testes do painel.
- [x] Validar o comportamento de breakpoint, foco e rotas por testes de widget e unidade; a revisão visual humana permanece recomendada antes do deploy.

## Answer

O painel agora usa Firebase Auth por e-mail/senha com persistência Web `SESSION`.
Antes de construir qualquer rota administrativa, o controlador atualiza o ID
token, valida o provider `password`, e-mail verificado e claim `admin ===
true`. Falhas de qualificação limpam a sessão e levam à rota pública
`/unauthorized`, que permite retornar ao login.

Foi criado um guard puro para todas as rotas, incluindo deep links, e um shell
Material 3 desktop-first: sidebar permanente a partir de 840 px, Drawer em
larguras menores, cabeçalho com conta atual e logout acessível, sem bottom
navigation. As páginas administrativas são placeholders deliberados para os
próximos tickets, sem carregar dados administrativos neste ticket.

Validação: `flutter analyze` e `flutter test` em `admin/` aprovados (7
testes); `flutter build web` foi iniciado e concluiu os artefatos locais de
Web sem erro reportado. Os testes cobrem loading, sessão, login, guard/deep
link, logout/unauthorized, foco por teclado e breakpoint.
