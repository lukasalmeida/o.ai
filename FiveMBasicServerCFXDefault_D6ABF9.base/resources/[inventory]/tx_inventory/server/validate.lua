-- ==========================================================
--  TX_INVENTORY | AUTO-CHECK DE SINTAXE LUA
--  ----------------------------------------------------------
--  Compila TODOS os arquivos .lua do recurso usando o parser
--  real do runtime do FiveM (load) e imprime OK / ERRO no
--  console do servidor.
--
--  Por que existe: um erro de sintaxe em UM arquivo derruba
--  o script inteiro (inclusive o registro das teclas e a NUI),
--  e o log do servidor não mostra esse tipo de erro (que
--  acontece no cliente). Este check roda a cada start.
-- ==========================================================

local CHECK_FILES = {
    'config.lua',
    'shared/items.lua',
    'client/animations.lua',
    'client/effects.lua',
    'client/main.lua',
    'server/database.lua',
    'server/framework.lua',
    'server/main.lua',
}

CreateThread(function()
    Wait(1500)

    if type(load) ~= 'function' then
        print('^3[tx_inventory]^7 auto-check indisponível neste runtime (load ausente).')
        return
    end

    local res = GetCurrentResourceName()
    local errors = 0

    print('[tx_inventory] auto-check de sintaxe:')
    for _, path in ipairs(CHECK_FILES) do
        local code = LoadResourceFile(res, path)
        if not code or code == '' then
            errors = errors + 1
            print(('^3[tx_inventory]^7   AVISO  -> %s (arquivo nao encontrado)'):format(path))
        else
            local fn, err = load(code, '@' .. path)
            if fn then
                print(('  [tx_inventory]   OK    -> %s'):format(path))
            else
                errors = errors + 1
                print(('^1[tx_inventory]^7   ERRO  -> %s  ::  %s'):format(path, tostring(err)))
            end
        end
    end

    if errors == 0 then
        print('[tx_inventory] auto-check: nenhum erro de sintaxe.')
    else
        print(('^1[tx_inventory]^7 auto-check: %d arquivo(s) com problema!'):format(errors))
    end
end)
