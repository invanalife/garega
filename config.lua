Config = {}

-- Configuration générale
Config.Locale = 'fr' -- Langue (fr/en)
Config.UseTarget = true -- Utilise ox_target (sinon interaction 3D)
Config.VehicleKeys = 'vehiclekeys' -- Script de clés (vehiclekeys, qs-vehiclekeys, cd_garage)
Config.UseImpound = true -- Système de fourrière
Config.UseRepair = true -- Réparation automatique
Config.Webhooks = true -- Logs Discord

-- Configuration des blips
Config.Blips = {
    sprite = 357,
    color = 3,
    scale = 0.8,
    name = "Garage"
}

-- Configuration des garages
Config.Garages = {
    -- Garage public principal
    ['legion'] = {
        name = "Garage Legion Square",
        type = 'public', -- public, private, job
        job = nil,
        coords = vector3(215.9499, -805.17, 30.84),
        spawnCoords = vector4(229.7, -800.1, 30.6, 160.0),
        blip = true,
        maxVehicles = 50,
        categories = {'car', 'motorcycle'},
        repairCost = 500,
        marker = {
            type = 36,
            size = vector3(1.0, 1.0, 1.0),
            color = {r = 0, g = 255, b = 0, a = 100}
        }
    },
    
    -- Garage aéroport
    ['airport'] = {
        name = "Garage Aéroport",
        type = 'public',
        job = nil,
        coords = vector3(-1267.5, -3013.2, -49.49),
        spawnCoords = vector4(-1276.0, -3016.5, -49.5, 330.0),
        blip = true,
        maxVehicles = 30,
        categories = {'plane', 'helicopter'},
        repairCost = 1000,
        marker = {
            type = 36,
            size = vector3(1.0, 1.0, 1.0),
            color = {r = 0, g = 255, b = 0, a = 100}
        }
    },
    
    -- Garage marina
    ['marina'] = {
        name = "Marina",
        type = 'public',
        job = nil,
        coords = vector3(-794.7, -1510.8, 1.6),
        spawnCoords = vector4(-798.5, -1518.2, 0.0, 111.0),
        blip = true,
        maxVehicles = 20,
        categories = {'boat'},
        repairCost = 750,
        marker = {
            type = 36,
            size = vector3(1.0, 1.0, 1.0),
            color = {r = 0, g = 150, b = 255, a = 100}
        }
    },
    
    -- Garage police
    ['police'] = {
        name = "Garage Police",
        type = 'job',
        job = 'police',
        coords = vector3(454.6, -1017.4, 28.4),
        spawnCoords = vector4(438.4, -1018.3, 27.7, 90.0),
        blip = false,
        maxVehicles = 100,
        categories = {'car', 'motorcycle'},
        repairCost = 0,
        marker = {
            type = 36,
            size = vector3(1.0, 1.0, 1.0),
            color = {r = 0, g = 0, b = 255, a = 100}
        }
    },
    
    -- Garage EMS
    ['ambulance'] = {
        name = "Garage EMS",
        type = 'job',
        job = 'ambulance',
        coords = vector3(307.7, -1433.5, 29.9),
        spawnCoords = vector4(294.5, -1429.5, 29.7, 230.0),
        blip = false,
        maxVehicles = 50,
        categories = {'car'},
        repairCost = 0,
        marker = {
            type = 36,
            size = vector3(1.0, 1.0, 1.0),
            color = {r = 255, g = 0, b = 0, a = 100}
        }
    }
}

-- Configuration de la fourrière
Config.Impound = {
    coords = vector3(401.7, -1630.5, 29.3),
    spawnCoords = vector4(391.2, -1619.0, 29.3, 230.0),
    blip = true,
    baseCost = 1000,
    dailyCost = 50,
    maxDays = 30,
    marker = {
        type = 36,
        size = vector3(1.0, 1.0, 1.0),
        color = {r = 255, g = 165, b = 0, a = 100}
    }
}

-- Configuration des catégories de véhicules
Config.VehicleCategories = {
    ['car'] = {
        label = 'Voitures',
        classes = {0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 17, 18, 19, 20}
    },
    ['motorcycle'] = {
        label = 'Motos',
        classes = {8}
    },
    ['boat'] = {
        label = 'Bateaux',
        classes = {14}
    },
    ['plane'] = {
        label = 'Avions',
        classes = {16}
    },
    ['helicopter'] = {
        label = 'Hélicoptères',
        classes = {15}
    }
}

-- Configuration des animations
Config.Animations = {
    garage = {
        duration = 3000,
        effect = 'garage_door'
    },
    spawn = {
        duration = 2000,
        fadeIn = true
    }
}

-- Configuration des webhooks Discord
Config.DiscordWebhooks = {
    garage = '', -- URL du webhook pour les actions de garage
    admin = '', -- URL du webhook pour les actions admin
    impound = '' -- URL du webhook pour la fourrière
}

-- Messages
Config.Messages = {
    ['vehicle_spawned'] = 'Véhicule sorti du garage',
    ['vehicle_stored'] = 'Véhicule rangé dans le garage',
    ['vehicle_already_out'] = 'Ce véhicule est déjà sorti',
    ['vehicle_not_owned'] = 'Ce véhicule ne vous appartient pas',
    ['garage_full'] = 'Le garage est plein',
    ['no_money'] = 'Vous n\'avez pas assez d\'argent',
    ['vehicle_repaired'] = 'Véhicule réparé',
    ['access_denied'] = 'Accès refusé',
    ['vehicle_impounded'] = 'Véhicule mis en fourrière',
    ['vehicle_retrieved'] = 'Véhicule récupéré de la fourrière',
    ['no_vehicles'] = 'Aucun véhicule dans ce garage'
}

-- Configuration des permissions admin
Config.AdminGroups = {
    'admin',
    'superadmin',
    'owner'
}