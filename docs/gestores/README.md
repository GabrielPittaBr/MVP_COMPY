# Painel do Local (plataforma dos gestores)

Esta pasta junta tudo o que foi definido para o Painel do Local: a plataforma web em que a equipe de um local esportivo privado parceiro publica horários livres, recebe as reservas que vêm do app COMPY e organiza a agenda das quadras. Esta pasta é o ponto de partida para construí-lo. Já existe um protótipo só visual, com dados fictícios e sem Firebase, em `gestor/` (no ar em https://compy-tcc-gestor.web.app); o `gestor/README.md` diz o que ele mudou em relação às telas.

## O que ler, e em que ordem

| Arquivo | O que tem |
|---|---|
| `resumo-e-decisoes.md` | Resumo de uma página: decisões de tecnologia, hospedagem, perfis, dados e cronograma, issues abertas e pontos em aberto. Comece por aqui. |
| `requisitos-painel-do-local.md` | Documento completo, feito a partir da entrevista L01: problema, perfis e permissões, requisitos funcionais (RF-P…) e não funcionais, regras de negócio, modelo de dados, integração com o app e o painel admin, temas e roteiro. É a fonte mais detalhada. |
| `documento-de-requisitos.md` (e `.pdf`) | Versão resumida no formato do documento de requisitos do app: RF01–RF24, RNF01–RNF14, RN-01–RN-10. É a versão entregue para a banca e para os gestores. |
| `issues.md` | Texto das issues #56–#70 do GitHub (label `painel-do-local`): mudanças no app (#56–#65) e no painel admin (#66–#70) para o painel funcionar. |
| `telas/` | As telas desenhadas para validar com os gestores (veja abaixo). |

Se dois arquivos discordarem, vale nesta ordem: `requisitos-painel-do-local.md`, depois `documento-de-requisitos.md` e por último as telas. As telas mostram o visual e o fluxo, não as regras.

## As telas

São arquivos `.dc.html` do Claude Design. O canvas original está em https://claude.ai/artifact/9S7qpEow752Ed9AsFK1ykN, e `telas/canvas.json` diz o título, o tamanho e a página de cada tela. Os arquivos não abrem sozinhos no navegador, mas o HTML e os estilos inline são legíveis e servem de referência exata de layout, textos, cores e espaçamentos:

- `{{t.piso}}`, `{{t.texto}}`, `{{t.texto2}}`, `{{t.destaque}}` e `{{t.sel}}` são as cores do tema do local. Os valores de cada tema estão no script no fim de cada arquivo e na tabela de temas de `requisitos-painel-do-local.md`.
- Cada `<sc-if value="{{is.areia}}">` (e os outros temas) desenha a quadra daquele tema no fundo do menu e do cabeçalho.
- `/_blob/9440076738c6388a2ca6761a29c3236c` é o ícone do COMPY, salvo aqui como `telas/compy-icon-64.png` (no app, `assets/images/compy-icon.png`).
- Todos os dados são fictícios: local "Arena Exemplo", 5 quadras de areia, quinta, 19/11, às 18:40.

| Página do canvas | Arquivos |
|---|---|
| Celular · Atendente | `Login`, `Main` (Hoje), `Solicitacao`, `NovaReserva`, `PublicarLivre`, `Bloquear`, `EventoLocal` |
| Computador · Atendente | Os mesmos sete com o sufixo `Web`. No computador, os formulários abrem num painel lateral ao lado da agenda. |
| Computador · Proprietário | `HojeComputador`, `Resultados`, `Quadras`, `Perfil`, `Equipe` |
| Temas e divulgação | `Temas` (os seis temas), `Stories` (imagem para o Instagram) |

As telas com "(v2)" no título (`EventoLocal`, `Resultados`, `Stories`) são da segunda versão. O resto é MVP.

## Decisões que valem para a implementação

- Flutter Web como PWA, numa pasta nova `gestor/` deste repositório, com `pubspec` próprio, como o `admin/`. Ver `docs/admin/painel-administrativo.md` para o padrão já usado no painel admin.
- Hospedagem num terceiro site do Firebase Hosting no projeto `compy-tcc`.
- Visual baseado no painel admin (`admin/lib/core/theme/`), com Barlow e Barlow Condensed. O tema do local muda só a moldura (menu, cabeçalho, login e imagens de divulgação). Agenda, formulários e cores de estado são iguais em todos os temas.
- Perfis Proprietário, Gerente (v2) e Atendente, com a tabela de permissões em `requisitos-painel-do-local.md` (e resumida na tela `Equipe`).
- Coleções novas, sem mexer em `places`, e reservas gravadas só por Cloud Functions, com transação na grade do dia.
- Seguir o `AGENTS.md` da raiz: arquitetura por feature, textos em PT-BR, testes das regras em `tools/firestore-rules-tests/` e caderno de campo.

## Por onde começar

1. Abrir a issue base das coleções e das Cloud Functions do painel, que as issues #56–#70 citam em "Bloqueado por" e que ainda não existe.
2. Criar o esqueleto de `gestor/`: login por convite, menu com tema e a tela Hoje.
3. Seguir a ordem do roteiro do MVP em `requisitos-painel-do-local.md`.
