-- Sistema de desmaiado:
--  - ao morrer o jogador NÃO renasce sozinho nem troca de boneco;
--  - aparece a tela "DESMAIADO" com um timer de 5 minutos;
--  - quando o tempo acaba, o botão DESISTIR habilita o respawn:
--    teleporta para o ponto inicial do mapa, com vida cheia e sem itens;
--  - o /god (admin) continua revivendo no local e mantendo os itens.
--
-- O respawn é feito com um ponto SEM o campo 'model' — assim o spawnmanager
-- só reposiciona o ped e nunca chega a trocar o modelo do personagem.

local FAINT_SECONDS = 5 * 60 -- tempo que o jogador fica desmaiado

local lockedModel -- hash do modelo que o jogador deve ter sempre
local firstSpawn  -- ponto do mapa usado ao entrar (fallback de respawn)

local faintDeadline -- horizonte do timer de desmaiado (nil = tela fechada)
local faintToken = 0 -- invalida timers antigos
local respawning = false -- respawn em andamento (não reabre a tela)

-- Lê o modelo salvo neste cliente (persiste entre conexões)
local saved = tonumber(GetResourceKvpString('characterModel') or '')

if saved and IsModelInCdimage(saved) and IsModelAPed(saved) then
    lockedModel = saved
end

--------------------------------------------------------------------------
-- Tela de desmaiado (NUI)
--------------------------------------------------------------------------

local function stopFaint()
    if not faintDeadline then
        return
    end

    faintDeadline = nil
    faintToken = faintToken + 1 -- cancela o timer pendente
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

local function startFaint()
    if faintDeadline then
        return
    end

    local deadline = GetGameTimer() + FAINT_SECONDS * 1000
    faintDeadline = deadline
    faintToken = faintToken + 1
    local token = faintToken

    SendNUIMessage({ action = 'faint', seconds = FAINT_SECONDS })

    CreateThread(function()
        -- conta os 5 minutos (sai se o jogador for revivido antes)
        while GetGameTimer() < deadline do
            if faintToken ~= token then
                return
            end

            Wait(200)
        end

        if faintToken == token then
            -- tempo esgotado: libera o botão DESISTIR (com o mouse)
            SendNUIMessage({ action = 'ready' })
            SetNuiFocus(true, true)
        end
    end)
end

-- A NUI pede o estado quando a página carrega (garante que a tela aparece
-- mesmo se o recurso for reiniciado com o jogador já desmaiado)
RegisterNUICallback('state', function(_, cb)
    if not faintDeadline then
        cb({ action = 'hide' })
        return
    end

    local left = faintDeadline - GetGameTimer()

    if left <= 0 then
        cb({ action = 'ready' })
    else
        cb({ action = 'faint', seconds = math.ceil(left / 1000) })
    end
end)

--------------------------------------------------------------------------
-- Modelo travado (sempre o mesmo boneco)
--------------------------------------------------------------------------

local function applyLockedModel()
    if not lockedModel then
        return
    end

    local ped = PlayerPedId()

    if ped == -1 or GetEntityModel(ped) == lockedModel then
        return
    end

    if not HasModelLoaded(lockedModel) then
        RequestModel(lockedModel)

        -- espera o modelo carregar (máx. 5s)
        local timeout = GetGameTimer() + 5000

        while not HasModelLoaded(lockedModel) do
            if GetGameTimer() > timeout then
                return
            end

            Wait(0)
        end
    end

    SetPlayerModel(PlayerId(), lockedModel)
    SetModelAsNoLongerNeeded(lockedModel)
end

--------------------------------------------------------------------------
-- Ponto de respawn
--------------------------------------------------------------------------

local function spawnAt(point)
    -- sem o campo 'model' no ponto, o spawnmanager não mexe no modelo do ped
    if point then
        exports.spawnmanager:spawnPlayer(point)
    else
        exports.spawnmanager:spawnPlayer()
    end
end

-- Ponto do DESISTIR: o ponto inicial do mapa (onde o jogador entrou).
-- Fallback para o caso de o recurso ter sido iniciado no meio da sessão
-- (ainda não guardou o ponto): onde morreu, se tiver chão por perto.
local function giveUpPoint()
    if firstSpawn then
        return firstSpawn
    end

    local ped = PlayerPedId()

    if ped ~= -1 and IsEntityDead(ped) then
        local pos = GetEntityCoords(ped)
        local hasGround, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)

        -- só usa o local da morte se tiver chão pertinho — senão o jogador
        -- nasceria no ar (morreu caindo) ou no meio do oceano
        if hasGround and math.abs(pos.z - groundZ) <= 5.0 then
            return { x = pos.x, y = pos.y, z = pos.z, heading = GetEntityHeading(ped) }
        end
    end

    return nil
end

-- O spawnmanager chama isso no lugar do respawn aleatório dele
exports.spawnmanager:setAutoSpawnCallback(function()
    local ped = PlayerPedId()

    -- morto: NÃO renasce sozinho — fica desmaiado até clicar em DESISTIR
    if ped ~= -1 and IsEntityDead(ped) then
        return
    end

    -- vivo (primeiro spawn ao entrar / força de respawn): ponto do mapa
    spawnAt(firstSpawn)
end)

--------------------------------------------------------------------------
-- Botão DESISTIR (NUI → client)
--------------------------------------------------------------------------

RegisterNUICallback('giveup', function(_, cb)
    cb({ ok = true })

    local ped = PlayerPedId()

    if ped == -1 or not IsEntityDead(ped) then
        stopFaint()
        return
    end

    -- sai da tela e é teleportado para o ponto inicial do mapa com vida
    -- cheia (as armas são limpas pelo spawnmanager no respawn)
    stopFaint()
    respawning = true
    spawnAt(giveUpPoint())

    -- segurança: se o spawn falhar por algum motivo, a tela volta
    CreateThread(function()
        Wait(3000)
        respawning = false
    end)
end)

--------------------------------------------------------------------------
-- Respawn concluído
--------------------------------------------------------------------------

AddEventHandler('playerSpawned', function(spawn)
    -- vivo de novo: encerra o estado de desmaiado
    respawning = false
    stopFaint()

    -- guarda o ponto do mapa usado ao entrar (fallback de respawn)
    if not firstSpawn and spawn and spawn.x then
        firstSpawn = {
            x = spawn.x,
            y = spawn.y,
            z = spawn.z,
            heading = spawn.heading or 0.0
        }
    end

    -- primeiro spawn: trava o modelo atual e guarda pra sempre
    if not lockedModel then
        lockedModel = GetEntityModel(PlayerPedId())
        SetResourceKvp('characterModel', tostring(lockedModel))
    else
        applyLockedModel()
    end

    -- renasce com vida cheia e sem nada (o spawnmanager já limpou as armas)
    local ped = PlayerPedId()

    if ped ~= -1 then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        SetPedArmour(ped, 0)
    end
end)

--------------------------------------------------------------------------
-- Monitor: abre/fecha a tela de desmaiado e mantém o modelo no streaming
--------------------------------------------------------------------------

CreateThread(function()
    while true do
        local ped = PlayerPedId()

        if ped ~= -1 and IsEntityDead(ped) then
            -- abre a tela de desmaiado (uma única vez por morte)
            if not faintDeadline and not respawning then
                startFaint()
            end

            -- deixa o modelo travado carregado (troca na hora do respawn)
            if lockedModel and IsModelInCdimage(lockedModel) and not HasModelLoaded(lockedModel) then
                RequestModel(lockedModel)
            end

            Wait(100)
        else
            -- vivo de novo (DESISTIR, /god, etc.): tira a tela e o mouse
            if faintDeadline then
                stopFaint()
            end

            respawning = false

            if lockedModel and ped ~= -1 and IsModelInCdimage(lockedModel)
                and GetEntityModel(ped) ~= lockedModel then
                if not HasModelLoaded(lockedModel) then
                    RequestModel(lockedModel)
                end

                Wait(250)
            else
                Wait(500)
            end
        end
    end
end)
