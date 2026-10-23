Config = {}

Config.Framework = 'standalone' 

Config.Database = {
    table = 'characters',
    identifier_column = 'identifier',
    firstname_column = 'firstname',
    lastname_column = 'lastname',
    age_column = 'age',
    sex_column = 'sex',
    skin_column = 'skin',
    position_column = 'position',
    money_column = 'money',
    bank_column = 'bank',
    job_column = 'job',
    last_location_column = 'last_location',
    slot_column = 'slot'
}

Config.MaxCharacters = 3

Config.DefaultSpawn = {
    coords = vector4(-1037.71, -2737.41, 20.17, 245.0),
    model = 'mp_m_freemode_01'
}

Config.CameraLocations = {
    characterSelection = {
        coords = vector3(-1037.71, -2737.41, 20.17),
        rotation = vector3(0.0, 0.0, 245.0),
        fov = 50.0
    },
    creation = {
        coords = vector3(402.87, -998.65, -98.5),
        rotation = vector3(0.0, 0.0, 180.0),
        fov = 40.0
    },
    customization = {
        face = {
            coords = vector3(402.87, -996.5, -98.5),
            rotation = vector3(0.0, 0.0, 180.0),
            fov = 20.0
        },
        body = {
            coords = vector3(402.87, -998.0, -98.5),
            rotation = vector3(0.0, 0.0, 180.0),
            fov = 45.0
        },
        feet = {
            coords = vector3(402.87, -999.5, -99.5),
            rotation = vector3(-15.0, 0.0, 180.0),
            fov = 45.0
        }
    }
}

Config.StartingClothes = {
    male = {
        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
        ['torso_1'] = 15, ['torso_2'] = 0,
        ['decals_1'] = 0, ['decals_2'] = 0,
        ['arms'] = 15, ['arms_2'] = 0,
        ['pants_1'] = 61, ['pants_2'] = 0,
        ['shoes_1'] = 34, ['shoes_2'] = 0,
        ['helmet_1'] = -1, ['helmet_2'] = 0,
        ['glasses_1'] = -1, ['glasses_2'] = 0,
        ['ears_1'] = -1, ['ears_2'] = 0,
        ['mask_1'] = 0, ['mask_2'] = 0,
        ['bags_1'] = 0, ['bags_2'] = 0,
        ['chain_1'] = 0, ['chain_2'] = 0,
        ['bracelets_1'] = -1, ['bracelets_2'] = 0
    },
    female = {
        ['tshirt_1'] = 15, ['tshirt_2'] = 0,
        ['torso_1'] = 15, ['torso_2'] = 0,
        ['decals_1'] = 0, ['decals_2'] = 0,
        ['arms'] = 15, ['arms_2'] = 0,
        ['pants_1'] = 57, ['pants_2'] = 0,
        ['shoes_1'] = 35, ['shoes_2'] = 0,
        ['helmet_1'] = -1, ['helmet_2'] = 0,
        ['glasses_1'] = -1, ['glasses_2'] = 0,
        ['ears_1'] = -1, ['ears_2'] = 0,
        ['mask_1'] = 0, ['mask_2'] = 0,
        ['bags_1'] = 0, ['bags_2'] = 0,
        ['chain_1'] = 0, ['chain_2'] = 0,
        ['bracelets_1'] = -1, ['bracelets_2'] = 0
    }
}

Config.Theme = {
    primary = '#FF6B00',
    primaryLight = '#FF8C00',
    primaryDark = '#E85D00',
    background = '#121214',
    backgroundLight = '#1E1E22',
    surface = 'rgba(18, 18, 20, 0.85)',
    surfaceHover = 'rgba(30, 30, 34, 0.9)',
    border = 'rgba(255, 107, 0, 0.3)',
    borderActive = '#FF6B00',
    textPrimary = '#FFFFFF',
    textSecondary = '#B8B8C0',
    textMuted = '#7A7A88',
    success = '#4ADE80',
    error = '#F87171',
    warning = '#FBBF24',
    shadow = 'rgba(255, 107, 0, 0.4)',
    shadowSoft = 'rgba(255, 107, 0, 0.15)'
}

Config.AnimationDurations = {
    fadeIn = 300,
    fadeOut = 200,
    slideIn = 400,
    slideOut = 300,
    cameraTransition = 1500
}

Config.DefaultSkin = {
    male = {
        model = 'mp_m_freemode_01',
        face = {
            mom = 21, dad = 23, shapeMix = 0.5, skinMix = 0.5,
            eyes = 0, eyebrows = 0, nose = 0, mouth = 0
        },
        hair = { style = 0, color = 0, highlight = 0 },
        facialHair = { style = 0, opacity = 0.0, color = 0 },
        eyebrows = { style = 0, opacity = 1.0, color = 0 },
        makeup = { blush = 0, lipstick = 0, eyeshadow = 0 },
        age = 0, blemishes = 0, complexion = 0, sunDamage = 0
    },
    female = {
        model = 'mp_f_freemode_01',
        face = {
            mom = 21, dad = 23, shapeMix = 0.5, skinMix = 0.5,
            eyes = 0, eyebrows = 0, nose = 0, mouth = 0
        },
        hair = { style = 0, color = 0, highlight = 0 },
        facialHair = { style = 0, opacity = 0.0, color = 0 },
        eyebrows = { style = 0, opacity = 1.0, color = 0 },
        makeup = { blush = 0, lipstick = 0, eyeshadow = 0 },
        age = 0, blemishes = 0, complexion = 0, sunDamage = 0
    }
}

Config.Validation = {
    minNameLength = 2,
    maxNameLength = 20,
    minAge = 18,
    maxAge = 100,
    allowedChars = '^[A-Za-zÀ-ÿ\\s\\-]+$'
}

Config.Keybinds = {
    rotateLeft = 'LEFT',
    rotateRight = 'RIGHT',
    zoomIn = 'UP',
    zoomOut = 'DOWN'
}

Config.Debug = true

function Config.Log(msg)
    if Config.Debug then
        print('[MULTICHARACTER] ' .. msg)
    end
end