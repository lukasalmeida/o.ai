# cpanel — Painel Admin in-game (inspirado no txAdmin)

Painel administrativo que abre **em jogo** com `/cpanel`, reunindo as funções
do txAdmin (lista de jogadores, ações rápidas, garagem, armas) e todos os
comandos admin clássicos: `/car`, `/god`, `/arma`, `/tp`, `/bring`, etc.

Feito para **base limpa** (standalone) — não depende de ESX/QBCore.

## Instalação

1. Copie a pasta `cpanel` para dentro da pasta `resources` do seu servidor.
2. Adicione no `server.cfg`:

```cfg
ensure cpanel

# Permissão para usar o painel/comandos
add_ace group.admin cpanel.use allow

# Dê a permissão à sua licença (substitua pelo seu identifier)
add_principal identifier.license:SUA_LICENCA group.admin
```

> **Dica:** o txAdmin já cria o grupo `group.admin` quando você se declara admin
> na interface — nesse caso basta o `add_ace group.admin cpanel.use allow`.

3. Reinicie o servidor (ou `refresh` + `ensure cpanel`).

## Como usar

| Como | O que faz |
| --- | --- |
| `/cpanel` | Abre/fecha o painel (ou `ESC` para fechar) |
| **Dashboard** | Stats, ações rápidas (god, noclip, invis, curar…) e anúncio ao servidor |
| **Jogadores** | Lista online com ping/distância + ações em cada jogador (ir até, trazer, god, freeze, curar, matar, spawnar carro, dar arma) |
| **Garagem & Armas** | Input + chips de modelos de veículo e armas populares |
| **Comandos** | Tabela com todos os comandos de chat |

## Comandos

```
/cpanel                  abrir o painel
/car <modelo>            spawnar veículo      ex: /car adder
/god                     godmode toggle
/arma <arma> [munição]   dar arma             ex: /arma ak 500 | /arma all
/hp                      curar (vida + colete)
/kill [id]               matar a si mesmo ou a outro jogador
/tp <id>                 teleportar até o jogador
/bring <id>              trazer o jogador até você
/freeze <id>             congelar/descongelar
/invis                   invisibilidade toggle
/noclip                  noclip (W/A/S/D · E sobe · Q desce · Shift acelera)
/fix                     consertar o veículo atual
/dv                      remover o veículo mais próximo (até 10m)
/dvall <raio>            remover todos os veículos num raio (ex: /dvall 100)
/anuncio <mensagem>      anúncio para todos
```

> `/god` também **revive** você no local se estiver desmaiado/morto.

## Estrutura

```
cpanel/
├── fxmanifest.lua
├── client/main.lua    # NUI, god, noclip, veículos, armas, teleportes
├── server/main.lua    # permissões (ace), lista de jogadores, comandos
└── html/              # interface do painel (index.html, style.css, script.js)
```

## Segurança

- Toda ação passa por **uma checagem no servidor** (`IsPlayerAceAllowed(src, 'cpanel.use')`)
  — quem não tiver o ace não abre o painel nem usa os comandos, mesmo editando a NUI.
- Quem tem o ace pode, em tese, usar qualquer comando — distribua com cuidado.
- As ações ficam logadas no console do servidor (`[cpanel] jogador (ID x) executou...`).

---
*cPanel v1.0.0 — criado para a série "Criando um Servidor de GTA 5 com IA"*
