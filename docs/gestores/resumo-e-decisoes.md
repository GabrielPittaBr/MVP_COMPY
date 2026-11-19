# COMPY — Painel do Local (plataforma dos gestores): requisitos

Documento completo, com requisitos, diagramas e prévia dos temas: https://claude.ai/artifact/GGm1nv4aAUokgkPmjqhjdz (criado em 18/11/2026, com base na entrevista L01)

Documento de requisitos no estilo do documento do app (Google Docs, baixa em PDF): https://docs.google.com/document/d/12zKOiNlDgvg_A6W3nkwO0upa7WvhAyLVIx5Dk_7o1e8/edit — perfis, RF01–RF24, RNF01–RNF14, RN-01–RN-10, integração com o app e o painel admin, fluxo.

Telas para validação com gestores (Claude Design): https://claude.ai/artifact/9S7qpEow752Ed9AsFK1ykN — 7 telas de celular (Atendente), 7 de computador (Atendente), 5 de computador (Proprietário), os seis temas e a imagem para stories. Local fictício "Arena Exemplo" (5 quadras de areia, tema Areia, sem logo). As telas marcadas com (v2) são da segunda versão.

## Decisões propostas
- Foco do MVP: horários livres publicados, solicitações vindas do app e agenda mínima sem conflito; convive com o sistema que o local já usa (o L01 usa um sistema pago).
- Perfis: Proprietário (tudo), Gerente (opera e configura, v2) e Atendente (só horários e reservas); conta individual, convite por link/QR, remoção com efeito imediato.
- Tecnologia: Flutter Web como PWA, pasta `gestor/` no mesmo repositório (MVP_COMPY), separada de `admin/` e do app; pacote `packages/compy_courts` para os temas.
- Hospedagem: Firebase Hosting, terceiro site do projeto `compy-tcc` (ex.: compy-tcc-gestor.web.app); depois, domínio próprio.
- Visual: base do painel admin; temas Areia, Padel, Campo, Saibro, Ginásio e Quadra (padrão), escolhidos pela modalidade principal; logo do local ou monograma.
- Dados: coleções novas (`partners`, `courts`, `days`, `bookings`, `slotOffers`, `members`), sem mexer em `places`; reservas só por Cloud Functions, com transação na grade do dia.
- MVP: 38 de 64 requisitos; roteiro MVP jan.–fev. 2027 → teste gratuito mar.–abr. (B8) → v2 abr.–jun. → piloto comercial jul.–set. 2027.

## Issues no GitHub (label `painel-do-local`, abertas em 18/11/2026)
- App: #56–#65 (RF-A01 a RF-A10). Painel admin: #66–#70 (RF-AD01 a RF-AD05).
- MVP = "prioridade: média" (#56–#61, #66–#68); v2 = "prioridade: baixa" (#62–#65, #69, #70).
- A seção "Bloqueado por" das issues cita uma issue base (coleções e Cloud Functions do Painel do Local) que ainda não foi aberta.

## Pontos em aberto
Nome do produto; Gerente no MVP; reservas por 16–17 anos; prazo de 30 min de resposta; repositório público ou privado; projeto Firebase de produção; domínio; segundo local do teste gratuito.
