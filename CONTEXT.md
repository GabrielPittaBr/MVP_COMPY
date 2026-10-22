# COMPY

O COMPY conecta pessoas interessadas em praticar esportes e mantém as informações necessárias para organizar essa experiência.

## Linguagem

**Administrador**:
Usuário autorizado a operar as ferramentas internas de gestão do COMPY. Na primeira versão, todos os administradores possuem as mesmas permissões.
_Evitar_: Moderador, superadministrador, operador

**Painel Administrativo**:
Interface interna usada por Administradores para gerenciar Locais Esportivos e consultar Usuários.
_Evitar_: Backoffice, painel de moderação

**Usuário**:
Pessoa registrada no COMPY para participar das experiências esportivas oferecidas pelo aplicativo.
_Evitar_: Cliente, membro

**Conta de Usuário**:
Identidade de acesso associada a um Usuário, cujo estado determina se novas sessões podem ser iniciadas. Pode existir sem um Perfil de Usuário correspondente.
_Evitar_: Perfil, cadastro

**Perfil de Usuário**:
Conjunto de informações de apresentação de um Usuário, como nome, identificador público, avatar e modalidades favoritas. É independente das credenciais e do estado, ou mesmo da existência, de sua Conta de Usuário.
_Evitar_: Conta, credencial

**Suspensão Administrativa**:
Restrição reversível aplicada a uma Conta de Usuário que impede novos acessos e futuras renovações de sessão, sem garantir o encerramento instantâneo de uma sessão já autorizada.
_Evitar_: Banimento, exclusão, bloqueio instantâneo

**Local Esportivo**:
Espaço físico cadastrado no COMPY onde uma ou mais modalidades esportivas podem ser praticadas.
_Evitar_: Ponto, estabelecimento, venue

**Local Esportivo Inativo**:
Local Esportivo indisponível para descoberta e novos usos, mas preservado para manter válidas referências históricas.
_Evitar_: Local excluído, local apagado

**Evento Esportivo**:
Encontro organizado no COMPY para a prática de uma modalidade em data, horário e Local Esportivo definidos. O evento preserva o contexto do local existente no momento de sua criação.
_Evitar_: Partida, atividade

**Organizador**:
Usuário que criou um Evento Esportivo. É o único que pode encerrá-lo e também conta como Participante.
_Evitar_: Dono, anfitrião, host

**Participante**:
Usuário que entrou em um Evento Esportivo, incluindo o Organizador. Entrar não distingue quem só se inscreveu de quem compareceu.
_Evitar_: Inscrito, jogador, membro

**Evento em Andamento**:
Evento Esportivo que já começou e ainda não teve Encerramento.
_Evitar_: Evento ativo, partida em curso

**Encerramento**:
Fim registrado de um Evento Esportivo. Depois dele, o evento sai das listas, ninguém mais entra e os Participantes podem avaliar.
_Evitar_: Finalização, término, cancelamento

**Encerramento Automático**:
Encerramento feito pelo COMPY quando o Organizador não encerra o evento até 1h depois do fim previsto. O Organizador recebe um aviso único sobre ele.
_Evitar_: Expiração, encerramento forçado

**Avaliação**:
Nota de 1 a 5 estrelas, com comentário opcional, dada por um Participante depois do Encerramento a um Evento Esportivo, a um Local Esportivo ou a outro Participante. O Organizador não avalia o próprio evento, e o comentário nunca é público.
_Evitar_: Review, feedback, reputação

**Média de Avaliações**:
Resumo público das Avaliações recebidas por um Evento Esportivo, Local Esportivo ou Usuário. É a única parte das Avaliações que aparece para outras pessoas.
_Evitar_: Score, ranking, nota geral

**Notificação**:
Aviso que o COMPY entrega a um Usuário dentro do aplicativo, na central de notificações. Hoje avisa o fim de um evento e convida a avaliar.
_Evitar_: Push, alerta, mensagem

**Mensagem de Local**:
Mensagem de conversa que compartilha um Local Esportivo e preserva uma representação mínima para continuar compreensível quando os dados atuais do local não estiverem disponíveis.
_Evitar_: Anúncio de local, cadastro de local
