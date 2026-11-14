# Relatório de impacto à proteção de dados e avaliação de impacto do ECA Digital — COMPY

LGPD, arts. 5º, XVII, e 38; ECA Digital (Lei 15.211/2025), art. 16, parágrafo
único; [Decreto 12.880/2026, art. 47](https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2026/decreto/D12880.htm).
Versão de 14/11/2026. O resumo público está na página
[Segurança](https://compy-tcc.web.app/seguranca).

## 1. O tratamento

Ver `registro-de-operacoes.md`. Em resumo: contas de pessoas com 16 anos ou
mais, perfis públicos para usuários logados, eventos esportivos presenciais
com local e horário, chat 1:1, amizades, avaliações e denúncias. Localização
do aparelho só no aparelho.

## 2. Por que avaliar

- O app tem **adolescentes de 16 e 17 anos** (critério específico de alto
  risco da Res. CD/ANPD nº 2/2022, art. 4º, II, "d").
- Junta **local e horário de encontros presenciais** com **chat entre
  desconhecidos**.
- O ECA Digital pede a avaliação para serviços de acesso provável por
  adolescentes.

## 3. Riscos, probabilidade, gravidade e medidas

| Risco | Probabilidade | Gravidade | Medidas | Risco residual |
|---|---|---|---|---|
| Adulto desconhecido aborda adolescente pelo chat | Média | Alta | Contas de 16–17 só conversam com amigos aceitos (regra `canTalk`); bloqueio; denúncia com prioridade | Baixo |
| Adolescente encontra desconhecido em evento | Média | Alta | Eventos são públicos e em locais esportivos cadastrados pelo admin; dicas de segurança e página para pais; denúncia de evento | Médio |
| Exposição da localização do aparelho | Baixa | Média | Localização opcional, pedida só depois do aviso, nunca sai do aparelho | Baixo |
| Assédio ou ofensa nas mensagens e avaliações | Média | Média | Denúncia de mensagem e de perfil; bloqueio; comentários de avaliação não são públicos | Baixo |
| Conteúdo de abuso sexual infantil | Baixa | Muito alta | Proibido nos Termos; denúncia com motivo próprio e prioridade; remoção imediata; comunicação à Polícia Federal; preservação por 6 meses | Baixo |
| Menor de 16 cria conta mentindo a idade | Média | Média | Data de nascimento com corte no cadastro; faixa etária da Google Play (vale a mais protetiva); exclusão ao descobrir | Médio |
| Vazamento de dados | Baixa | Alta | Regras testadas, dados privados em subcoleções, App Check, 2FA na equipe, plano de incidentes | Baixo |
| Uso compulsivo | Baixa | Baixa | Sem rolagem infinita de conteúdo, sem recompensas por tempo de uso; notificações só de eventos | Baixo |
| Perfilamento ou publicidade para adolescentes | — | — | O app não tem anúncios nem analytics | Inexistente |

## 4. Configurações padrão para adolescentes (ECA Digital, arts. 7º e 17)

- Chat só com amigos aceitos, aplicado no servidor.
- Localização desligada até a pessoa ligar.
- Sem anúncios, sem perfilamento, sem venda de dados.
- Os padrões não podem ser afrouxados pelo próprio adolescente.

## 5. Acompanhamento

Revisar a cada semestre e sempre que entrar uma funcionalidade nova que
toque adolescentes (por exemplo, notificações push). Medir pela fila de
denúncias do painel: número de denúncias por motivo e tempo até o
fechamento.

## 6. Resumo público

Publicado em https://compy-tcc.web.app/seguranca, seção "Para pais e
responsáveis" e "Padrões contra abuso e exploração sexual infantil".
