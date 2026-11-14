# Registro das operações de tratamento (ROPA) — COMPY

LGPD, art. 37. Segue os campos do [modelo da ANPD para agentes de pequeno
porte](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/modelo_de_ropa_para_atpp.pdf/@@display-file/file),
mas está completo: com adolescentes de 16 e 17 anos no app, não contamos com o
regime de pequeno porte (ver `docs/lgpd.md`, seção 2.3).

Versão de 14/11/2026. Revisar sempre que um dado novo entrar no app.

## Identificação

| Campo | Valor |
|---|---|
| Controladores | Gabriel Fernandes Pitta e Bernardo Pedroso Finkler (pessoas físicas, controladoria conjunta) |
| Encarregado | Gabriel Fernandes Pitta (substituto: Bernardo Pedroso Finkler) |
| Contato | contato.compy@gmail.com |
| Operador | Google (Firebase: Authentication, Cloud Firestore, Cloud Storage, Cloud Functions, App Check, Hosting) |
| Categorias de titulares | Usuários do app com 16 anos ou mais, **incluindo adolescentes de 16 e 17 anos** |
| Transferência internacional | Sim: Firebase Authentication e Cloud Storage (bucket `compy-tcc.firebasestorage.app`, região `us-east1`) nos EUA (cláusulas-padrão da ANPD no Cloud Data Processing Addendum do Google) |

## Operações

| # | Processo | Finalidade | Dados | Base legal | Onde fica | Quem acessa | Retenção | Segurança |
|---|---|---|---|---|---|---|---|---|
| 1 | Conta e login | Criar a conta e autenticar | Nome, e-mail, senha (hash), conta Google, uid, datas de criação e último acesso, IP | Execução de contrato (art. 7º, V) | Firebase Auth (EUA) | Titular; admins veem e-mail, provedores, datas e status | Enquanto a conta existir; backups do Google até 180 dias | Senha não legível; App Check; admins com claim |
| 2 | Aceite e idade | Provar o aceite dos Termos; idade mínima de 16; proteções de 16–17 | Versão e hora do aceite, data de nascimento, 18º aniversário, faixa etária da Google Play | Obrigação legal (art. 7º, II; ECA Digital arts. 12–14) e contrato | `users/{uid}/private/consent` | Só o titular; as regras leem para aplicar a proteção | Enquanto a conta existir | Regra valida idade e impede troca da data |
| 3 | Perfil público | Identificar o usuário para os outros | Nome, @username, foto, esportes, bio | Contrato | `users/{uid}`, Storage `users/{uid}/` (EUA, `us-east1`) | Usuários logados | Enquanto a conta existir; fotos antigas apagadas na troca | EXIF removido; escrita só do dono |
| 4 | Contato | Exportação de dados e contato pelo encarregado | E-mail | Contrato | `users/{uid}/private/contact` | Só o titular | Enquanto a conta existir | Fora do perfil público |
| 5 | Eventos | Organizar partidas | Evento (esporte, local, data, vagas), criador e participantes (nome, @, foto copiados) | Contrato | `events` | Usuários logados | Enquanto a conta existir; na exclusão: futuros cancelados, passados anonimizados | Regras de criação, join e encerramento |
| 6 | Chat | Conversas 1:1 | Texto, remetente, horário, locais compartilhados | Contrato | `conversations`, `messages` | Só os dois membros | Enquanto a conta existir; na exclusão, mensagens enviadas apagadas | Regras por membro; `canTalk` (bloqueio e 16–17) |
| 7 | Amizades | Lista de amigos | Pares de uids, status, datas | Contrato | `friendships` | Os dois membros | Apagadas na exclusão | Regras por membro |
| 8 | Avaliações | Médias de eventos, locais e participantes | Nota, comentário, autor, alvo | Legítimo interesse (art. 7º, IX) — ver `testes-de-balanceamento.md` | `ratings`, `ratingSummaries` | Comentários: ninguém pelo app; médias: logados | Enquanto a conta existir; na exclusão, comentário apagado e avaliações recebidas apagadas | Só a callable grava |
| 9 | Denúncias e moderação | Segurança da comunidade e deveres do ECA Digital | Denunciante, alvo, motivo, relato, cópia da mensagem; decisões dos admins | Legítimo interesse (art. 7º, IX) e obrigação legal (art. 7º, II) | `reports`, `adminOperations` | Só admins | Denúncias: 12 meses após o fechamento (TTL); moderação: 5 anos (TTL) | Cópia da mensagem conferida pelas regras; leitura só de admin |
| 10 | Bloqueios | Impedir contato indesejado | Lista de uids bloqueados | Contrato e legítimo interesse | `users/{uid}/blocks` | Só o titular | Enquanto a conta existir | Regras de conversa e amizade consultam |
| 11 | Notificações | Avisar fim ou cancelamento de evento | Tipo, evento, datas | Contrato | `users/{uid}/notifications` | Só o titular | 90 dias (TTL) | Criadas só pelo servidor |
| 12 | Localização | Ordenar eventos por distância | Coordenadas do aparelho | Consentimento (art. 7º, I) | **Só no aparelho** | Ninguém | Não é gravada | Aviso antes do pedido; opcional |
| 13 | Segurança técnica | Prevenção de fraude e abuso | IP, aparelho, atestado do App Check | Legítimo interesse | Google | Google | Pela política do Google (IPs por semanas) | — |
| 14 | Exportação | Direito de acesso e portabilidade | Tudo dos itens 1–11 do titular | Obrigação legal (art. 18) | Gerada na hora pela callable `exportMyData` | Só o titular | Não fica guardada | Exige login |

## Terceiros que recebem dados por conta própria

- **Google Sign-In e Google Play** (contas do próprio usuário).
- **OpenStreetMap Foundation**: IP, User-Agent `br.com.compy.app` e área do mapa ao baixar os tiles.
- **Google Fonts**: IP ao baixar a fonte do app.

## Documentos ligados

`retencao.md`, `plano-de-incidentes.md`, `politica-de-seguranca.md`,
`testes-de-balanceamento.md`, `avaliacao-de-impacto.md` e
`designacao-encarregado.md`, nesta pasta.
