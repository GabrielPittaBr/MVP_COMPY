# Ícones das modalidades (CompySportIcons)

Gera a fonte `assets/fonts/CompySportIcons.otf` e um SVG por ícone em `svg/`.
A fonte deixa `Sport.icon` continuar sendo `IconData`, então os widgets que
desenham o ícone do esporte (pin do mapa, cards, detalhe, notificações…) não
mudam.

Isto **não** faz parte do app: só roda quando um ícone é criado ou alterado. A
fonte gerada é versionada.

## Rodar

Precisa de Python 3.10+ e do `flutter` no PATH, porque as bolas de futebol e de
vôlei saem da `MaterialIcons` que vem com o SDK.

```bash
python -m venv .venv-icons
.venv-icons/Scripts/python -m pip install -r tools/sport-icons/requirements.txt   # Windows
# .venv-icons/bin/python -m pip install -r tools/sport-icons/requirements.txt     # macOS/Linux
.venv-icons/Scripts/python tools/sport-icons/build_font.py
```

A saída é determinística: rodar de novo sem mudar o desenho gera a mesma fonte,
byte a byte.

## Ícones

| Modalidade | Glifo | Code point | Desenho |
|---|---|---|---|
| Beach tennis | `beach_tennis` | `0xE800` | Raquete furada + bola + onda de areia |
| Futevôlei | `futevolei` | `0xE801` | Bola de futebol sobre a rede + onda de areia |
| Vôlei de praia | `volei_de_praia` | `0xE802` | Bola de vôlei + onda de areia |
| Futebol de areia | `futebol_de_areia` | `0xE803` | Bola de futebol + onda de areia |
| Padel | `padel` | `0xE804` | Duas raquetes furadas cruzadas + bola |
| Tênis | `tenis` | `0xE805` | Bola de tênis com as duas costuras |

Handebol e skate não estão na fonte: usam `Icons.sports_handball` e
`Icons.skateboarding`, que já existem nos Material Icons e não eram usados por
nenhum outro esporte.

Regras do desenho:

- Grade 24×24 e preenchimento sólido, como os Material Icons do app.
- **A onda embaixo marca os esportes de areia.** O símbolo de cima fica num
  círculo de raio 7, para sobrar espaço para a onda.
- Nenhum ícone repete os que já estão em uso: `sports_soccer` (futebol e
  futsal), `sports_volleyball`, `sports_basketball`, `sports_tennis` (tênis de
  mesa), `directions_run`, `directions_bike` e `directions_walk`.
- O padel usa duas raquetes porque uma raquete com a bola embaixo ficava com a
  mesma silhueta do `sports_tennis` no pin do mapa.
- Os ícones foram conferidos nos tamanhos do app: 13–14 px (chips e card do
  chat), 18–24 px (cards e notificações), 40–60 px (detalhe e card do chat) e
  dentro do pin do mapa.

## Code points

Os code points de `ICONS` em `build_font.py` são fixos: a classe
`CompySportIcons` (`lib/core/theme/compy_sport_icons.dart`) aponta para eles.
Um ícone novo ganha o próximo code point livre e uma constante nessa classe.

## Licença

As bolas de futebol e de vôlei são derivadas dos glifos `sports_soccer` e
`sports_volleyball` dos [Material Icons](https://github.com/google/material-design-icons),
do Google, sob a [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
O aviso também vai gravado na tabela `name` da fonte. O resto do desenho é
original do COMPY.
