# Política de segurança da informação — COMPY

LGPD, arts. 46–49; Decreto 8.771/2016, art. 13; segue o
[Guia de segurança da ANPD para agentes de pequeno porte](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-orientativo-sobre-seguranca-da-informacao-para-agentes-de-tratamento-de-pequeno-porte).

## Regras para a equipe

1. **Contas Google com acesso ao `compy-tcc` usam verificação em duas
   etapas.** Hoje: Gabriel e Bernardo. Revisar o IAM do projeto a cada
   semestre e remover quem saiu.
2. **Claim `admin` só para quem modera.** É dada pelo
   `npm run bootstrap-admin` (ver `tools/firebase-admin/README.md`) e exige
   conta com e-mail verificado.
3. **Nenhum segredo no repositório**: nada de service account, `.env`,
   `key.properties` ou keystore. O `key.properties` e o
   `compy-release-v2.jks` ficam só nas máquinas da equipe.
4. **Administradores não leem conversas.** O painel não tem tela de chat; a
   moderação vê só a cópia da mensagem denunciada.
5. **Dados de usuários não saem do Firebase** para planilhas, prints ou
   grupos de mensagem. Para a monografia, usar só números agregados ou dados
   anonimizados.
6. **Exportar ou apagar dados a pedido** é feito pelo app ou pelo painel,
   nunca editando o banco à mão, salvo correção de data de nascimento
   (registrar no caderno de campo).

## Controles técnicos que já existem

| Controle | Onde |
|---|---|
| Regras do Firestore e do Storage por papel, testadas (244 casos) | `firestore.rules`, `storage.rules`, `tools/firestore-rules-tests/` |
| E-mail e data de nascimento fora do perfil público | `users/{uid}/private/*` |
| Comentários de avaliação só pela callable, ninguém lê pelo app | `ratings` |
| Denúncias só o Administrador lê; cópia da mensagem conferida | `reports` |
| Callables do painel com App Check obrigatório | `functions/src/admin_auth_read.ts` |
| App Check no app (Play Integrity no release) | `lib/core/services/firebase_service.dart` |
| EXIF removido das fotos | `lib/core/utils/avatar_image.dart` |
| Logs do app mudos no release | `lib/main.dart` |
| Conexões HTTPS; criptografia em repouso pelo Google | Firebase |
| Registro do motivo de cada suspensão e exclusão | `adminOperations` |

## Pendências conhecidas

- **Imposição do App Check** no Firestore, Storage e Functions do app: só
  depois de o app estar distribuído pela Play (senão derruba quem instalou
  pelo APK do GitHub). Ver `docs/checklist-publicacao.md`.
- `submitEventRatings` e `exportMyData` rodam com `enforceAppCheck: false`
  pelo mesmo motivo.
