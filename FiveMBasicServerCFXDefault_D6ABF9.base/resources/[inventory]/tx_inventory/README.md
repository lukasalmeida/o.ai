# tx_inventory

Inventário completo para FiveM (GTA V RP) com **mochila**, **hotbar (1-5)**, **drag & drop**,
**itens no chão em 3D**, **dar item**, **usar/equipar**, **peso e limite de slots** e
**persistência em MySQL** (oxmysql / ghmattimysql).

Interface NUI em dark mode, responsiva, no estilo `ox_inventory` / `qs-inventory`.
Funciona **standalone** (sem framework) ou com **ESX / QBCore / vRP** (detecção automática).

---

## 1. Requisitos

| Item | Observação |
|---|---|
| FiveM server build 3751+ | Usado apenas o `game 'gta5'` padrão |
| `oxmysql` (recomendado) ou `ghmattimysql` | Necessário para persistir os itens |
| OneSync | Para criar os props dos itens no chão (há fallback client-side) |
| Framework | Opcional — `Config.Framework = 'auto'` detecta ESX/QBCore/vRP |

---

## 2. Instalação

1. **Copie a pasta** `tx_inventory` para `resources/[inventory]/tx_inventory` do seu servidor.

2. **Banco de dados** — duas opções:

   *Automática:* as tabelas `player_items` e `ground_items` são criadas sozinhas no
   primeiro start (o recurso roda `CREATE TABLE IF NOT EXISTS`).

   *Manual:* importe `sql/inventory.sql` no seu phpMyAdmin/HeidiSQL.

   ```sql
   -- conteúdo de sql/inventory.sql
   ```

3. **`server.cfg`** — adicione:

   ```cfg
   set mysql_connection_string "mysql://root@127.0.0.1:3306/fivem"
   ensure oxmysql          # (ou ghmattimysql)
   ensure tx_inventory
   ```

   > O `tx_inventory` já deve ser **depois** do `oxmysql` na ordem de start.
   > Se o `oxmysql` não for iniciado antes, o recurso espera a conexão ficar pronta
   > (thread `EnsureInventory`) e só então carrega o inventário do jogador.

   Neste servidor o `oxmysql` (v2.14.3) já está instalado em
   `resources/[managers]/oxmysql` e a string de conexão já está no `server.cfg`.

4. **Keybind** — o padrão é a tecla `'` (apostrophe). Para trocar, edite
   `Config.InventoryKey` em `config.lua` ou remapeie em
   *Configurações → Mapeamento de teclas → tx_inventory*.

   > **Atenção ao layout do teclado.** O mapper `keyboard` do FiveM resolve o
   > parâmetro para um **código VK do Windows**, e o VK da tecla `'` muda
   > conforme o layout:
   >
   > | Layout | VK da tecla `'` | Parâmetro CFX |
   > |---|---|---|
   > | PT-BR (00000416) | `0xC0` | `OEM_3` **(padrão)** |
   > | US (00000409) | `0xDE` | `OEM_7` / `APOSTROPHE` |
   >
   > No teclado brasileiro o VK `0xDE` é a tecla do `~`, por isso usar
   > `APOSTROPHE` no Brasil simplesmente não dispara. O `Config.InventoryKeyAlt`
   > (`OEM_7`) fica registrado como fallback para jogadores em layout US.

5. Reinicie o servidor (`restart tx_inventory`).

---

## 3. Controles

| Ação | Como fazer |
|---|---|
| Abrir / fechar inventário | Tecla `'` (cursor do mouse é travado enquanto aberto) — layout BR: `OEM_3`; layout US: `OEM_7` |
| Abrir pelo chat | `/inv` ou `/inventario` (mesma função da tecla) |
| Usar item | **Duplo clique** no item ou **botão direito → Usar / Equipar** |
| Equipar arma | Duplo clique / botão direito → *Usar / Equipar* (aparece o indicador "equipped") |
| Mover item | **Arrastar** de um slot para outro (mochila ⇄ hotbar ⇄ mochila) |
| Jogar no chão | **Arrastar para fora do painel** (ou botão direito → *Jogar no chão*) |
| Pegar do chão | Arrastar o item da lista **CHÃO** para um slot, ou tecla `E` no mundo 3D |
| Destruir item | Arrastar para a área **DESCARTAR (LIXO)** ou botão direito → *Destruir* |
| Dividir stack | Botão direito → *Dividir stack* (abre o modal de quantidade) |
| Dar item a alguém | Botão direito → *Dar a um jogador* (vai para o jogador mais próximo) |
| Hotbar | Teclas `1` a `5` — usa o item sem abrir o inventário |
| Fechar menus | `ESC` |

---

## 4. Estrutura de arquivos

```
tx_inventory/
├── fxmanifest.lua          # manifest do recurso
├── config.lua              # TODAS as configurações (peso, slots, distâncias, teclas...)
├── README.md
├── shared/
│   └── items.lua           # catálogo de itens (TXINV.Items) + ordem de exibição
├── client/
│   ├── main.lua            # NUI, keybinds, drop/pickup/give, props no chão
│   ├── animations.lua      # animações de drop / pickup / give
│   └── effects.lua         # efeitos de consumíveis (vida, colete, fome, sede)
├── server/
│   ├── main.lua            # núcleo autoritativo: slots, peso, give/drop/use, exports
│   ├── database.lua        # driver MySQL (oxmysql / ghmattimysql) + criação de tabelas
│   ├── framework.lua       # adapter ESX / QBCore / vRP / standalone
│   └── validate.lua        # auto-check de sintaxe Lua (roda a cada start)
├── html/
│   ├── index.html          # NUI
│   ├── style.css           # dark mode, responsivo
│   ├── script.js           # drag & drop, context menu, tooltip, hotbar HUD
│   └── img/                # ícones SVG dos itens
└── sql/
    └── inventory.sql       # script de importação das tabelas
```

---

## 5. Configuração (`config.lua`)

```lua
Config.MaxWeight      = 30.0   -- kg padrão (soma dos pesos dos itens)
Config.BackpackSlots = 30     -- slots base da mochila
Config.HotbarSlots   = 5      -- teclas 1-5
Config.Framework     = 'auto' -- 'auto' | 'esx' | 'qb' | 'vrp' | 'standalone'
Config.Database      = 'auto' -- 'auto' | 'oxmysql' | 'ghmattimysql'
```

Distâncias (metros):

```lua
Config.DropDistance       = 4.0   -- distância máxima do drop
Config.GiveDistance       = 3.0   -- distância máxima no "dar item"
Config.PickupDistance     = 2.5   -- distância para pegar do chão
Config.GroundItemDistance = 8.0   -- alcance da lista de itens no chão
```

Comportamento:

```lua
Config.AllowDelete      = true  -- permite arrastar para o LIXO
Config.AllowSplit       = true  -- permite dividir stacks
Config.AllowGive        = true  -- permite dar item
Config.StartingItems    = { { name = 'water', amount = 2, slot = 1 }, ... }
Config.EnableHotbarHud  = true  -- hotbar visível com o inventário fechado
```

### Capacidade extra com mochilas

Itens do tipo `backpack` somam capacidade automaticamente enquanto estão no inventário:

| Item | Slots extras | Peso extra |
|---|---|---|
| `backpack` | +10 | +10 kg |
| `duffelbag` | +20 | +25 kg |

---

## 6. Criando itens

Tudo em `shared/items.lua`:

```lua
['water'] = {
    label = 'Água', type = 'consumable', weight = 0.5, maxStack = 10,
    desc = 'Um copo de água. Mata a sede.', image = 'water.svg', glyph = '💧',
    effects = { thirst = 25.0 }, prop = 'prop_cs_water_bottle',
},
```

Campos disponíveis:

| Campo | Descrição |
|---|---|
| `label` | nome exibido na UI |
| `desc` | descrição (tooltip) |
| `type` | `consumable` \| `weapon` \| `tool` \| `phone` \| `backpack` \| `ammo` \| `key` \| `doc` |
| `weight` | peso em kg **por unidade** |
| `maxStack` | quantidade máxima por slot |
| `stackable` | `false` para itens que não empilham (armas) |
| `image` | arquivo dentro de `html/img` (fallback automático para o `glyph`) |
| `glyph` | emoji usado quando a imagem não existe |
| `effects` | `heal`, `armor`, `hunger`, `thirst` (consumíveis) |
| `weapon` | nome da arma (`WEAPON_PISTOL`) |
| `ammoType` | tipo de munição |
| `prop` | modelo spawnado no chão ao dropar |
| `slotsBonus` / `weightBonus` | bônus de mochila |

> Ao adicionar um item novo, coloque o ícone em `html/img/` (PNG ou SVG) ou use só o `glyph`.

---

## 7. API (exports)

Disponíveis no **servidor**:

```lua
-- adiciona um item (procura slot livre se slot == nil)
exports['tx_inventory']:AddItem(source, 'water', 3)          -- 3 unidades
exports['tx_inventory']:AddItem(source, 'pistol', 1, 12)     -- no slot 12

-- remove itens (retorna quantas unidades foram removidas)
local removed = exports['tx_inventory']:RemoveItem(source, 'water', 2)

-- conta itens (todas as stacks)
local total = exports['tx_inventory']:GetItemCount(source, 'ammo_pistol')

-- inventário completo
local inv = exports['tx_inventory']:GetInventory(source)
-- inv = { identifier = ..., items = { [id] = { id, name, slot, amount, metadata, equipped } }, slots = { [slot] = id }, weight = 0 }
```

Exemplo em um script de estoque (server):

```lua
RegisterNetEvent('loja:comprar', function(item)
    if exports['tx_inventory']:GetItemCount(source, item) >= 10 then return end
    exports['tx_inventory']:AddItem(source, item, 1)
end)
```

---

## 8. Eventos

**Servidor → Cliente**

| Evento | Dados |
|---|---|
| `txinv:client:open` | estado completo do inventário |
| `txinv:client:refresh` | estado completo (após qualquer mudança) |
| `txinv:client:useEffect` | `heal`, `armor`, `hunger`, `thirst` |
| `txinv:client:equipWeapon` | `name`, `weapon`, `ammo` |
| `txinv:client:unequipWeapon` | — |
| `txinv:client:giveEffect` | — |
| `txinv:client:droppedItem` | — |
| `txinv:client:spawnGroundProp` | `instance`, `name`, `prop`, `coords` |
| `txinv:client:removeGroundProp` | `instance` |
| `txinv:notify` | `key`, `kind` (mensagens prontas) |

**Cliente → Servidor**

`txinv:server:requestState`, `:open`, `:move`, `:drop`, `:pickup`, `:give`, `:use`,
`:unequip`, `:split`, `:delete`, `:hotbar`, `:position`

**Notificações**

```lua
TriggerClientEvent('txinv:notify', source, 'inventory_full', 'error')
-- keys: item_added, item_removed, inventory_full, too_heavy, no_space,
--        dropped, picked, given, received, invalid, denied
```

---

## 9. Banco de dados

`sql/inventory.sql`:

* **`player_items`** — `id`, `identifier`, `item_name`, `slot`, `amount`, `metadata`, `equipped`
* **`ground_items`** — `instance`, `item_name`, `amount`, `metadata`, `x`, `y`, `z`, `created_at`

O `identifier` é montado pelo `server/framework.lua` (prioridade: `license` → `steam`).

> Os itens do chão expiram em `Config.GroundItemExpire` minutos (padrão 30, `0` = nunca).

---

## 10. Segurança / anti-cheat

* O **servidor** é a fonte da verdade: o cliente só solicita ações, tudo é validado
  (propriedade do item, peso, slots livres, distância até o chão e até o jogador alvo).
* Heartbeat de posição a cada 2 s (`txinv:server:position`) para validar a distância
  do drop e do "dar item".
* Rate limit de `Config.AntiSpamMs` (250 ms) por jogador.
* Itens do chão têm identificador único (`instance`) — não é possível "clonar" um item.

---

## 11. Solução de problemas

| Sintoma | O que verificar |
|---|---|
| Inventário não abre | `ensure tx_inventory` no `server.cfg` + recurso `tx_inventory` na pasta `[inventory]` |
| "Aguardando banco de dados" | o `oxmysql` está iniciado **antes** do `tx_inventory` e com `set mysql_connection_string` correto |
| Erro em `exports.oxmysql` | instale o `oxmysql` (ou troque `Config.Database = 'ghmattimysql'`) |
| "falha ao conectar no banco de dados" | o MariaDB não está rodando: rode `E:\MariaDB\start-mariadb.bat` |
| Tecla `'` não funciona | **layout do teclado**: em PT-BR a `'` é o VK `0xC0` → o parâmetro tem de ser `OEM_3` (é o padrão do `config.lua`); `APOSTROPHE`/`OEM_7` é o VK `0xDE`, que no BR é a tecla do `~`. Confira em `%APPDATA%\CitizenFX\fivem.cfg` se existe `rbind tx_inventory KEYBOARD OEM_3 "+txinv"` (o cliente reescreve esse arquivo a cada start). Se o comando não estiver lá, o `RegisterKeyMapping` nem rodou: veja o log do cliente (`%LOCALAPPDATA%\FiveM\FiveM.app\logs\CitizenFX_log_*.log`) — se houver `Error parsing script`, o script do cliente nem carregou. Ainda assim use `/inv` no chat (sempre funciona) |
| Props não aparecem no chão | OneSync habilitado (o item continua funcionando, só o prop visual some) |
| Itens somem ao reconectar | confere `Config.Table` e o `identifier` gravado no banco |

### Auto-check de sintaxe (roda a cada start)

O `server/validate.lua` compila **todos** os `.lua` do recurso com o parser real do
runtime do FiveM e imprime o resultado no console do servidor:

```
[tx_inventory] auto-check de sintaxe:
  [tx_inventory]   OK    -> config.lua
  [tx_inventory]   OK    -> shared/items.lua
  ...
[tx_inventory] auto-check: nenhum erro de sintaxe.
```

Se aparecer `ERRO -> arquivo :: mensagem`, o arquivo está com erro de sintaxe.
**Lembre-se:** um erro de sintaxe em **um** arquivo derruba o script inteiro
(o cliente inteiro, no caso dos arquivos de `client/`), e por isso nada funciona
— nem hotbar, nem NUI, nem teclas. O erro aparece no **log do cliente**, não no
log do servidor.

### Banco de dados local (MariaDB portátil)

Instalado em `E:\MariaDB\mariadb-13.0.2-winx64` (versão portátil, não precisa de admin):

| Item | Valor |
|---|---|
| Porta | `3306` (bind `127.0.0.1`) |
| Usuário | `root` (sem senha) |
| Schema | `fivem` |
| String | `mysql://root@127.0.0.1:3306/fivem` |
| Iniciar | `E:\MariaDB\start-mariadb.bat` |
| Parar | `E:\MariaDB\stop-mariadb.bat` |
| Log | `E:\MariaDB\mariadb-13.0.2-winx64\data\error.log` |

O MariaDB também é iniciado automaticamente no login do Windows
(pasta *Inicialização* → `MariaDB Server.vbs`).

Para criar o schema do zero:

```sql
CREATE DATABASE IF NOT EXISTS `fivem` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

---

## 12. Créditos

Interface e ícones SVGs são próprios (line-art). Use livremente no seu servidor.
