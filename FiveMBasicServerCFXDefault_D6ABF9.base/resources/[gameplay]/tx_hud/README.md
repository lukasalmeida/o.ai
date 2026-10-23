# tx_hud

HUD completo para servidores **FiveM / RageMP / AltV** no estilo GTA V RP, com tema **dark glassmorphism** e **acento laranja** (`#FF6B00` / `#FF8C00`).

![hud](html/index.html)

---

## Componentes

| Bloco | Posição | Descrição |
|---|---|---|
| **Arma equipada** | inf. esquerdo | Nome da arma + munição (`30 / 120`) em pílula translúcida |
| **Vitais** | inf. esquerdo | Vida / Colete / Fôlego com micro-barras e ícones |
| **Minimapa** | inf. esquerdo | Mapa retangular, zona de segurança pulsante, seta do jogador, local e coordenadas |
| **Carteira / Banco** | inf. esquerdo | Dois chips com ícone e valor formatado (`$ 12.500`) |
| **Nível + XP** | inf. esquerdo | Badge `NV 24`, barra de progresso laranja com brilho animado |
| **Velocímetro** | inf. direito | Arco semi-circular digital com KM/H, marcha, arcos laterais de combustível (F/E) e RPM |
| **Flags do veículo** | inf. direito | Motor, farol, tranca e cinto (acendem em laranja) |
| **Quickbar** | inf. central | Slots `1`–`6` + voz (`V`), slot ativo com brilho laranja |
| **Missões / Tasks** | direita | Cards claros flutuantes, ícone de checkpoint laranja e tecla de atalho |
| **Info do servidor** | sup. direito | Logo, nome, versão, players online, ID, hora e data |
| **Alerta** | centro inferior | Avisos temporários (cinto, missões, etc.) |

---

## Estrutura

```
tx_hud/
├── fxmanifest.lua
├── client/main.lua      # coleta de status e envio para a NUI
├── server/main.lua      # contador de players + exports
└── html/
    ├── index.html       # marcação semântica
    ├── style.css        # CSS puro (tokens, glass, acento laranja)
    └── script.js        # ponte NUI <-> Lua + modo demo no navegador
```

> **Sem dependências externas**: CSS puro, fontes via Google Fonts (com fallback no sistema) e ícones em sprite SVG inline.

---

## Instalação

1. Copie a pasta `tx_hud` para `resources/[gameplay]/tx_hud`.
2. No `server.cfg`: `ensure tx_hud`.

---

## Integração

### Eventos do client (dispare de qualquer script do cliente)

```lua
TriggerServerEvent('txhud:setMoney', 12500, 148320)
TriggerServerEvent('txhud:setXp', 24, 1240, 2000)
TriggerServerEvent('txhud:setSlots', {
    { icon = 'i-food',   label = 'Frango',        count = 3 },
    { icon = 'i-medkit', label = 'Bandagem',      count = 5 },
    { icon = 'i-can',    label = 'Refrigerante',  count = 12 },
    { icon = 'i-battery',label = 'Celular',       count = 1 },
    { icon = 'i-key',    label = 'Chave',         count = 2 },
    { icon = 'i-flame',  label = 'Molotov',       count = 4 },
})
TriggerServerEvent('txhud:setTasks', {
    { title = 'Rota do contrabando', desc = '...', key = 'F', dist = '1.8 km', reward = '$ 5.000', progress = 40 },
})
TriggerServerEvent('txhud:alert', 'Veiculo trancado com o motor ligado', true)
```

### Eventos do server (dispare de qualquer script do server)

```lua
TriggerEvent('txhud:setMoney', source, 12500, 148320)
TriggerEvent('txhud:setXp', source, 24, 1240, 2000)
TriggerEvent('txhud:setSlots', source, slots)
TriggerEvent('txhud:setTasks', source, tasks)
TriggerEvent('txhud:alert', source, 'mensagem', false)
```

### Exports do server

```lua
exports['tx_hud']:GetPlayerHudData(serverId)
exports['tx_hud']:SetPlayerHudData(serverId, { name = 'Carlos', level = 24, xp = { current = 1240, needed = 2000 } })
exports['tx_hud']:BroadcastHudTasks(tasks)
exports['tx_hud']:BroadcastHudAlert('texto', false)
```

### NUI (dentro do `html/`)

```js
window.postMessage({ action: 'hud', money: { cash: 100, bank: 200 }, vehicle: { active: true, speed: 80 } }, '*');
window.txhud.setTasks([...]);
window.txhud.showAlert('aviso');
```

Ações aceitas pelo `message` listener: `hud`, `money`, `xp`, `slot`, `slots`, `alert`, `talking`, `taskProgress`, `tasks`, `visibility`.

---

## Teclas

| Tecla | Ação |
|---|---|
| `1` … `6` | Seleciona o item da quickbar |
| `V` | Canal de voz (segurar) |
| `B` | Coloca / remove o cinto de segurança |
| `F7` | Alterna a visibilidade do HUD |
| `/hud` | Alterna a visibilidade do HUD |

---

## Zonas seguras

Edite `safeZones` em `client/main.lua` (x, y e raio em metros) para casar com os pontos de respawn/loja do seu servidor.

---

## Preview no navegador

Abra `html/index.html` no navegador: sem FiveM a NUI entra em **modo demo** com dados simulados (velocidade, combustível, XP, players, etc.) para facilitar o ajuste visual.
