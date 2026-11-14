# Tabela de retenção — COMPY

LGPD, arts. 15 e 16; Decreto 8.771/2016, art. 13, §2º. É a mesma tabela da
seção 6 da [Política de Privacidade](../../site/privacidade.html). Mudou aqui,
muda lá, e vice-versa.

| Dado | Prazo | Como é apagado |
|---|---|---|
| Conta, perfil, eventos, mensagens, amizades, bloqueios, avaliações | Enquanto a conta existir | Exclusão da conta (app, painel ou e-mail) e o gatilho `onProfileDeletedCleanup` |
| Fotos de perfil substituídas | Até a troca | Gatilho `onProfileAvatarChanged` |
| Notificações | 90 dias | TTL em `notifications.expiresAt` |
| Denúncias abertas | Até a análise | — |
| Denúncias fechadas | 12 meses depois do fechamento | TTL em `reports.expiresAt`, gravado pelo painel ao fechar |
| Denúncias de abuso sexual de criança ou adolescente | Pelo menos 6 meses (ECA Digital, art. 27, §2º), mais se a autoridade pedir | Fechar com a nota "preservar a pedido da autoridade" e só depois de 6 meses |
| Registros de moderação (`adminOperations`) | 5 anos | TTL em `adminOperations.expiresAt` |
| Registro de incidentes (`plano-de-incidentes.md`) | 5 anos (Res. CD/ANPD nº 15/2024, art. 10) | Planilha do encarregado |
| Firebase Authentication depois da exclusão | Até 180 dias nos backups do Google | Pelo Google |
| Posição do GPS | Não é guardada | — |

## O que acontece na exclusão da conta

Ver `functions/src/account_cleanup.ts` e a página
[Excluir conta](../../site/excluir-conta.html):

- **Apagado:** conta, perfil, foto, e-mail, aceite e data de nascimento,
  notificações, amizades, bloqueios, mensagens enviadas, inscrições em eventos
  futuros, eventos futuros criados (com aviso aos participantes), comentários
  das avaliações feitas, avaliações e média recebidas.
- **Anonimizado:** nome e foto nos eventos passados e nas conversas viram
  "Conta excluída"; as notas dadas ficam só nas médias.
- **Guardado pelo prazo da tabela:** denúncias e registros de moderação.

## Documentos antigos

As notificações e os registros de moderação criados **antes** da
`chore/lgpd` não tinham `expiresAt`. O backfill abaixo já foi rodado em
14/11/2026; repetir não muda nada, porque ele só completa quem não tem o
campo:

```powershell
npm run backfill-retention-expiry --prefix tools/firebase-admin -- --dry-run
npm run backfill-retention-expiry --prefix tools/firebase-admin
```

Precisa de credencial do Admin SDK (`gcloud auth application-default login`).
