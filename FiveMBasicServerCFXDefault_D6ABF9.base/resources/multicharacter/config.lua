Config = {}

Config.MaxSlots = 3
Config.MinAge = 18

-- Routing bucket usado no lobby (dimensao privada)
Config.LobbyBucket = 9999

-- Coordenadas do lobby (ped + camera). Ajuste para seu mapa/studio.
Config.Lobby = {
    ped = vector4(0.0, 0.0, 70.0, 180.0),
    cam = nil, -- calculado dinamicamente
    fov = 38.0
}

-- Spawn inicial apos criacao/selecao (aeroporto)
Config.DefaultSpawn = vector4(-1037.0, -2738.0, 20.17, 320.0)

-- Modelos padrao
Config.Models = {
    male = 'mp_m_freemode_01',
    female = 'mp_f_freemode_01'
}

-- Dinheiro inicial
Config.StartMoney = 500
Config.StartBank = 5000
Config.StartJob = 'unemployed'