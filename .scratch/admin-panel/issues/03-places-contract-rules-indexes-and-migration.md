# 03: Introduzir contrato de Local Esportivo, Rules transitórias e migração

Status: resolved

Blocked by: 02 — Preparar tooling confiável Firebase e fundação de Functions

Spec: §§ 5, 7, 8, 9, 13, 24 e Testing Decisions / Firestore Rules e Scripts.

**What to build:** O contrato Firestore completo de Local Esportivo, os sete índices necessários, Rules transitórias e um script idempotente para preparar `parque_do_trabalhador`. O resultado é verificável no emulador e não muda ainda o escritor mobile de produção.

## Acceptance criteria

- [x] `places` possui schema com whitelist, endereço estruturado, normalizações, modalidades permitidas, coordenadas, imagem HTTPS, status e timestamps de servidor.
- [x] Create administrativo aceita somente documento completo com status inicial `inactive`; update preserva `createdAt`, atualiza `updatedAt` e delete é negado.
- [x] Usuário autenticado lista apenas ativos e pode resolver por ID o contexto histórico; Administrador lista ativos e inativos e é o único escritor direto.
- [x] O arquivo de índices preserva os seis existentes e enumera os sete índices de `places` aprovados.
- [x] As Rules são expand–contract: não quebram leitores/escritores legados de eventos e mensagens nesta etapa.
- [x] Script de migração possui dry-run, cria `parque_do_trabalhador` somente se ausente, é no-op se equivalente e aborta em divergência.
- [x] O script usa valores aprovados, timestamps de servidor e credencial externa; não faz deploy nem cria segredo.
- [x] Testes do emulador cobrem papéis, queries, schema inválido, timestamps, status, acesso histórico e negações.

## Verification

- [x] Executar suíte real de Rules no Emulator; script de execução manual preparado em `tools/scripts/run-firestore-rules-tests.ps1`.
- [x] Executar testes do script, incluindo create/no-op/divergência/dry-run.
- [x] Validar sintaxe do arquivo de índices e compilar/executar as Rules pelo Emulator.

## Answer

Implementados o contrato de `places`, Rules transitórias, sete índices, seed
aprovado, migração idempotente e testes unitários. Eventos e mensagens não
foram alterados, preservando o escritor legado durante o expand–contract.

O tooling passou typecheck, lint e 30 testes, incluindo dry-run, criação,
no-op equivalente e abortamento por divergência. Os índices foram validados
como JSON com 13 entradas no total, sendo sete para `places`.

Bloqueio externo de ambiente: o Firebase CLI atual exige JDK 21+. O Temurin
21.0.12.1 LTS foi instalado localmente e confirmado como o `java.exe` usado
pelo processo do emulador, mas o Windows recusou o socket de loopback interno
do Java (`Unable to establish loopback connection`, `Invalid argument:
connect`) antes de a suíte carregar as Rules. A mesma falha ocorreu ao
executar `npm.cmd` como processo nativo separado. O TCP normal em
`127.0.0.1` foi confirmado, não havia processo/porta do Emulator em conflito,
e as tentativas seguras com selector alternativo e host explícito
`127.0.0.1` falharam do mesmo modo; a configuração foi revertida. É necessário
executar a suíte em um terminal Windows com loopback Java permitido antes de
marcar o ticket como resolvido. Nenhum deploy, credencial ou operação remota
foi feita.

Confirmação adicional no executor Codex (2026-09-28): um reproducer mínimo em
`tools/scripts/java-loopback-reproducer.java`, executado com Temurin
21.0.12.1, falhou em `Selector.open()` com o mesmo `Unable to establish
loopback connection` / `Invalid argument: connect`, antes do teste de bind TCP.
Isso confirma que repetir a suíte neste executor não é útil e aponta para uma
limitação de loopback Java do ambiente do agente; não prova que um PowerShell
Windows normal da máquina tenha a mesma restrição.

Para validar fora do executor, abra PowerShell no Windows e rode:

```powershell
& 'C:\Users\Bernardo Finkler\StudioProjects\MVP_COMPY\tools\scripts\run-firestore-rules-tests.ps1'
```

O script seleciona o JDK 21 somente durante sua execução, valida `java
-version`, roda a suíte real e devolve o exit code do `npm test`. Até esse
resultado ser fornecido, o critério real do Emulator permanece pendente.

Evidência de execução manual fornecida em 2026-09-28: com JDK 21 fora do
executor, o Emulator iniciou e a suíte chegou a 96 testes; 93 passaram, nenhum
falhou por assertion e três foram cancelados porque o fixture tentou criar
`GeoPoint(-91, 0)` antes de chamar as Rules. O teste foi corrigido para verificar
separadamente a rejeição local do SDK e enviar às Rules um valor possível com
tipo inválido. A suíte completa precisa ser repetida fora do executor com essa
correção; o ticket permanece bloqueado até o exit code final ser 0.

Diagnóstico da execução manual seguinte (108 testes, 106 pass, 2 fail): o
contrato `places` já tipava `coordinates is latlng`, mas `validCoordinates()`
acessava `.latitude` e `.longitude` como se o LatLng fosse um map. Nas Rules,
esses valores são métodos: `latitude()` e `longitude()`. A regra foi corrigida
para usar os métodos e mantém os limites inclusivos de latitude e longitude.
Os testes não foram alterados nesta correção.

Tentativa no executor Codex após a correção (2026-09-30): JDK 21 foi confirmado,
mas o Emulator terminou antes de carregar as Rules com `Unable to establish
loopback connection` / `Invalid argument: connect`; exit code do runner: 1.
O ticket segue bloqueado até a suíte corrigida passar integralmente fora do
Codex.

Validação final manual fornecida em 2026-09-30: a suíte completa foi executada
fora do Codex com Java 21 e o Firestore Emulator iniciou corretamente. Resultado:
108 testes em 17 suítes; 108 passaram, zero falharam, foram cancelados,
ignorados ou ficaram pendentes; exit code 0 (`Script exited successfully
(code 0)`). O erro de loopback era específico do executor Codex. A correção
de GeoPoint em `firestore.rules` foi validada pelo Emulator; nenhuma Rule foi
alterada em resposta ao bloqueio ambiental. Ticket concluído.
