# Ciclo de vida e avaliações do Evento Esportivo com Cloud Functions

O Encerramento Automático, as Notificações de fim de evento e a gravação das Avaliações ficam em Cloud Functions, e não em exceções das Security Rules. Uma Function agendada encerra o evento 1h depois do fim previsto. Um gatilho cria as Notificações nos dois tipos de Encerramento. Uma callable valida e grava, numa transação, as Avaliações, as Médias de Avaliações e a marcação de quem já avaliou. As regras não fazem laço, então não validariam N participantes num envio. Elas também não garantem que uma avaliação seja gravada uma vez só. E, sem leitura de `ratings`, o cliente não teria como recalcular a média. Com a Function, a coleção `ratings` fica totalmente fechada ao cliente, o que garante que os comentários não sejam públicos (D13). O encerramento manual continua sendo uma escrita do Organizador, validada pelas regras.

## Considered Options

- **Exceção na regra de `events` para qualquer Participante gravar o Encerramento Automático** (o antigo `TODO(tarefa 14)`). É grátis, mas seria a regra mais delicada do arquivo e deixaria o encerramento depender de alguém abrir o app.
- **Média gravada no próprio documento do alvo.** Foi descartada porque `places` e `users` têm contrato estrito (`hasOnly` nas regras e leitura que rejeita campo extra no app e no Painel Administrativo). As médias ficam em `ratingSummaries`, escritas só pelo Admin SDK.

## Consequences

- **Reabre o ticket 17 do Painel Administrativo**, que fixou "ratings só `user`/`event`, sem avaliação de Local Esportivo". A Avaliação de Local Esportivo agora é real. O documento `places/{id}` continua com os mesmos 11 campos, e a média fica fora dele.
- A callable usa `enforceAppCheck: false`, ao contrário das callables administrativas. O Firestore está sem imposição de App Check no MVP, a web do app não ativa App Check e o build debug do Android precisaria registrar token. Com imposição, o teste no navegador e o debug quebrariam.
- As Functions novas entram na codebase `administrative`, cada uma com região explícita. Renomear a codebase faria o CLI apagar e recriar as Functions do painel.
- **Riscos aceitos:**
  - `ratedBy` fica legível por qualquer Usuário logado e expõe *quem* avaliou um evento, nunca *o quê*;
  - as Avaliações e Médias de Avaliações de quem excluiu a conta continuam existindo, para manter as médias íntegras. As Notificações dessa pessoa são apagadas na exclusão;
  - se o relógio do celular divergir do servidor perto do fim da folga, a regra pode negar o encerramento manual. A Function encerra o evento em seguida.
