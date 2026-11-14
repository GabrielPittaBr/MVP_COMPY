# Testes de balanceamento do legítimo interesse — COMPY

LGPD, art. 10; [Guia da ANPD sobre legítimo interesse (fev/2024)](https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia_orientativo_hipoteses_legais_tratamento_de_dados_pessoais_legitimo_interesse).
Como o app tem adolescentes, cada teste mostra por que o melhor interesse
deles prevalece (Enunciado CD/ANPD nº 1/2023).

## 1. Avaliações de eventos, locais e participantes

| Etapa | Análise |
|---|---|
| Finalidade legítima | Dar confiança na comunidade: quem procura um jogo vê a média de eventos, locais e participantes. |
| Necessidade | Só a nota entra na média pública. O comentário não é mostrado a ninguém e só existe para o caso de denúncia. Não há ranking, perfilamento nem decisão automática (art. 20). |
| Expectativa do titular | A tela avisa que o comentário é privado e que só a média aparece; a Política explica. |
| Riscos | Nota injusta ou retaliação. Mitigação: só quem participou do evento avalia, uma vez; a média de cada pessoa é a soma de muitos. |
| Adolescentes | Recebem e dão notas como os outros; a nota não bloqueia nada e não leva a nenhuma decisão sobre eles. |
| Salvaguardas | Callable `submitEventRatings` confere participação; na exclusão da conta, o comentário sai e as avaliações recebidas são apagadas. |
| Conclusão | O interesse prevalece, com as salvaguardas acima. |

## 2. Denúncias, bloqueios e moderação

| Etapa | Análise |
|---|---|
| Finalidade legítima | Proteger os usuários de assédio, golpes e abuso, e cumprir a Play e o ECA Digital (arts. 27–30). |
| Necessidade | A denúncia guarda só o que é preciso para analisar: quem denunciou, o alvo, o motivo, o relato e a cópia da mensagem denunciada. Os administradores não leem as conversas. |
| Expectativa do titular | Os Termos e a Política explicam a moderação e a cópia da mensagem. Quem foi denunciado não sabe quem denunciou. |
| Riscos | Denúncia de má-fé. Mitigação: os Termos proíbem, a decisão é humana e cabe contestação por e-mail. |
| Adolescentes | É a principal proteção deles: as denúncias que envolvem criança ou adolescente são as primeiras da fila. |
| Salvaguardas | Só o Administrador lê `reports`; denúncia fechada sai em 12 meses (TTL); registros de moderação em 5 anos. |
| Conclusão | O interesse prevalece; para abuso sexual infantil a base é obrigação legal (art. 7º, II). |

## 3. Segurança técnica (IP, App Check)

| Etapa | Análise |
|---|---|
| Finalidade legítima | Evitar fraude, robôs e acesso de versões adulteradas do app. |
| Necessidade | O COMPY não grava IP nem cria logs próprios; os registros são os que o Google mantém para operar o Firebase. |
| Expectativa do titular | Comum a qualquer app on-line; descrito na Política. |
| Riscos | Baixos. |
| Conclusão | O interesse prevalece. |
