# Plano de resposta a incidentes de segurança — COMPY

LGPD, art. 48; [Resolução CD/ANPD nº 15/2024](https://bibliotecadigital.mj.gov.br/bitstream/1/12879/2/RES_ANPD_2024_15.html).

**Incidente** é qualquer evento confirmado que comprometa a
confidencialidade, a integridade, a disponibilidade ou a autenticidade de
dados pessoais: vazamento, acesso indevido, perda ou alteração não
autorizada (art. 3º, XII).

## Quem faz o quê

| Papel | Pessoa |
|---|---|
| Decide e comunica | Gabriel Fernandes Pitta (encarregado) |
| Substitui | Bernardo Pedroso Finkler |
| Canal | contato.compy@gmail.com |

## Passo a passo

1. **Conter (na hora).** Revogar o acesso indevido: trocar senhas das contas
   Google com acesso ao projeto `compy-tcc`, tirar a claim `admin` de quem
   não devia ter, suspender contas pelo painel, publicar regras mais
   restritivas se a falha for de regra.
2. **Registrar (no mesmo dia).** Abrir uma linha na planilha de incidentes
   (modelo abaixo), mesmo que pareça pequeno.
3. **Avaliar o risco (até 1 dia útil).** O incidente precisa ser comunicado
   quando puder afetar significativamente interesses e direitos dos
   titulares **e** envolver pelo menos um destes (art. 5º):
   - dados de crianças, adolescentes ou idosos — **no COMPY, contas de 16 e
     17 anos**;
   - dados de autenticação (senhas, tokens);
   - dados sensíveis, financeiros ou sigilosos;
   - larga escala.
4. **Comunicar à ANPD em até 3 dias úteis** depois de saber que dados
   pessoais foram afetados, pelo
   [formulário da ANPD](https://www.gov.br/anpd/pt-br/canais_atendimento/agente-de-tratamento/comunicado-de-incidente-de-seguranca-cis/comunicacao-de-incidentes-de-seguranca)
   (art. 6º). O complemento pode vir em até 20 dias úteis. Não contamos com o
   prazo em dobro de pequeno porte.
5. **Comunicar os titulares em até 3 dias úteis**, de forma direta (e-mail ou
   aviso no app), em linguagem simples (art. 9º). Se não der para avisar um a
   um, aviso público no app e no site por 3 meses.
6. **Corrigir e aprender.** Corrigir a causa, adicionar um teste (regras,
   Functions ou app) que pegaria a falha e anotar no caderno de campo.

## O que a comunicação à ANPD precisa ter (art. 6º, §2º)

Natureza e categoria dos dados; número de titulares, **separando os
adolescentes**; medidas de segurança antes e depois; riscos; motivo de
eventual demora; medidas de mitigação; datas; encarregado; identificação dos
controladores; operador (Google); descrição e causa; total de titulares do
app.

## Modelo de aviso aos titulares

> Assunto: Aviso de segurança do COMPY
>
> Olá. No dia [data], identificamos [o que aconteceu, em uma frase]. Os dados
> envolvidos foram [quais]. Já [o que fizemos]. Recomendamos que você [o que a
> pessoa deve fazer, como trocar a senha]. Se tiver dúvidas, responda este
> e-mail ou escreva para contato.compy@gmail.com.
>
> Gabriel Fernandes Pitta, encarregado de dados do COMPY

## Planilha de registro (guardar por 5 anos — art. 10)

| Data da ciência | O que aconteceu | Dados e nº de titulares (adolescentes?) | Risco avaliado | Comunicado à ANPD? Quando? | Titulares avisados? Quando? | Medidas | Motivo de não comunicar |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
