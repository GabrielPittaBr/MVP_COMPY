# Exclusões administrativas por Callables

O Painel Administrativo passou a excluir Eventos Esportivos e Contas de Usuário. As duas exclusões passam por Callables (`deleteEvent` e `deleteUserAccount`) que exigem a claim `admin: true` e rodam com o Admin SDK. As Security Rules continuam negando `delete` em `events`, e o painel não ganhou permissão de escrita nova no Firestore. Excluir um evento também apaga dados de outras pessoas (a Notificação de fim de evento de cada Participante), e excluir uma conta mexe no Auth e no Storage. Nenhuma das duas cabe numa regra. Seguimos a [ADR-0001](0001-separar-operacoes-de-locais-e-contas.md): leituras de eventos vão direto ao Firestore, e o que precisa de ambiente confiável fica nas Callables.

Cada exclusão grava um registro em `adminOperations/{operationId}`, com quem excluiu, o quê e o motivo (10 a 500 caracteres). É o mesmo protocolo idempotente da suspensão: `pending`, depois `succeeded` ou `failed`. Se a resposta se perde, o painel repete com o mesmo `operationId`, e cada passo tolera o que já foi apagado.

## O que sai e o que fica

- **Evento:** saem a Notificação de fim de evento de cada Participante, as Avaliações do próprio evento e a Média dele. O documento do evento sai por último, então uma falha no meio deixa o evento visível e a repetição refaz tudo. As Avaliações do Local Esportivo e dos Participantes ficam, para não alterar as médias deles.
- **Conta:** sai o mesmo que na exclusão feita pelo próprio app: fotos no Storage, reserva do username, o perfil com `private` e `notifications`, e a conta do Auth. Eventos organizados, participações, mensagens e Avaliações ficam, como no app. A conta é desabilitada antes de tudo e só some do Auth no fim, então uma falha no meio deixa a conta desabilitada, que é o estado seguro. Um perfil sem conta no Auth (registro órfão) também pode ser excluído.

## Considered Options

- **Regra `allow delete: if isAdmin()` em `events`.** É mais simples, mas deixaria as Notificações apontando para um evento que não existe. Também não registraria o motivo.
- **Excluir junto os eventos organizados pela conta.** Descartada para manter a exclusão de conta igual à do app. O painel mostra os eventos organizados no detalhe do Usuário, para o Administrador excluir um por um, se quiser.

## Consequences

- Um ID token já emitido continua aceito por até cerca de 1h depois da exclusão da conta, o mesmo limite da Suspensão Administrativa.
- Se o evento for encerrado segundos antes da exclusão, o gatilho `onEventEnded` ainda pode criar Notificações depois dela. O app trata esse caso como "Evento não encontrado".
- A lista de eventos do painel precisa de três índices compostos novos: `sport + dateTime desc`, `sport + titleLower` e `creator.id + dateTime desc`. Eles precisam estar `READY` antes do deploy do Hosting.
