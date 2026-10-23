# Multicharacter Laranja - FiveM

Sistema completo de Multicharacter + Criação de Personagem com tema Laranja.

## Instalação
1. Coloque a pasta `multicharacter` em `resources/`.
2. Importe `install.sql` no banco MySQL.
3. Adicione ao `server.cfg`:
   ```
   ensure oxmysql
   ensure multicharacter
   ```
4. (Opcional) Ajuste `config.lua` (coordenadas, slots, dinheiro inicial).

## Dependências
- oxmysql

## Estrutura
- `fxmanifest.lua`
- `config.lua`
- `client/main.lua`
- `server/main.lua`
- `web/` (ui.html, style.css, script.js)
- `install.sql`

## Observações
- O lobby usa routing bucket 9999.
- Aparência salva em JSON na coluna `skin`.
- Última posição salva automaticamente a cada 60s.