ESX = exports['es_extended']:getSharedObject()

-- Variables globales
local spawnedVehicles = {}
local vehicleStates = {}

-- Initialisation de la base de données
MySQL.ready(function()
    -- Table pour les véhicules en garage
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `garage_vehicles` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `owner` varchar(46) NOT NULL,
            `plate` varchar(12) NOT NULL,
            `vehicle` longtext NOT NULL,
            `state` int(11) NOT NULL DEFAULT 1,
            `garage` varchar(60) NOT NULL DEFAULT 'legion',
            `impound` int(11) NOT NULL DEFAULT 0,
            `impound_data` longtext DEFAULT NULL,
            `stored` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            UNIQUE KEY `plate` (`plate`),
            KEY `owner` (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    -- Table pour l'historique des garages
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `garage_history` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `identifier` varchar(46) NOT NULL,
            `plate` varchar(12) NOT NULL,
            `action` varchar(20) NOT NULL,
            `garage` varchar(60) NOT NULL,
            `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
            PRIMARY KEY (`id`),
            KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    
    print('^2[Advanced Garage] ^7Base de données initialisée avec succès')
end)

-- Fonction pour obtenir les véhicules d'un joueur
local function getPlayerVehicles(source, garage)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    
    local garageConfig = Config.Garages[garage]
    if not garageConfig then return {} end
    
    -- Vérifier les permissions pour les garages de job
    if garageConfig.type == 'job' and xPlayer.job.name ~= garageConfig.job then
        return {}
    end
    
    local vehicles = MySQL.query.await('SELECT * FROM garage_vehicles WHERE owner = ? AND garage = ? AND impound = 0', {
        xPlayer.identifier, garage
    })
    
    local result = {}
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local vehicleData = json.decode(vehicle.vehicle)
        
        -- Vérifier si le véhicule est déjà spawné
        local isOut = spawnedVehicles[vehicle.plate] ~= nil
        
        table.insert(result, {
            id = vehicle.id,
            plate = vehicle.plate,
            model = vehicleData.model,
            name = vehicleData.name or GetDisplayNameFromVehicleModel(vehicleData.model),
            state = vehicle.state,
            isOut = isOut,
            stored = vehicle.stored,
            props = vehicleData.props or {},
            damage = vehicleData.damage or {},
            fuel = vehicleData.fuel or 100
        })
    end
    
    return result
end

-- Fonction pour stocker un véhicule
local function storeVehicle(source, plate, garage)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local garageConfig = Config.Garages[garage]
    if not garageConfig then return false end
    
    -- Vérifier les permissions
    if garageConfig.type == 'job' and xPlayer.job.name ~= garageConfig.job then
        return false
    end
    
    -- Vérifier si le véhicule existe et appartient au joueur
    local vehicle = MySQL.query.await('SELECT * FROM owned_vehicles WHERE owner = ? AND plate = ?', {
        xPlayer.identifier, plate
    })
    
    if not vehicle[1] then return false end
    
    -- Supprimer le véhicule spawné
    if spawnedVehicles[plate] then
        DeleteEntity(spawnedVehicles[plate])
        spawnedVehicles[plate] = nil
    end
    
    -- Obtenir les données du véhicule
    local vehicleData = json.decode(vehicle[1].vehicle)
    
    -- Stocker dans la base de données
    MySQL.query('INSERT INTO garage_vehicles (owner, plate, vehicle, garage, state) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE garage = ?, state = 1', {
        xPlayer.identifier, plate, json.encode(vehicleData), garage, 1, garage
    })
    
    -- Historique
    MySQL.insert('INSERT INTO garage_history (identifier, plate, action, garage) VALUES (?, ?, ?, ?)', {
        xPlayer.identifier, plate, 'store', garage
    })
    
    -- Webhook
    if Config.Webhooks then
        TriggerEvent('garage:webhook', {
            action = 'store',
            player = xPlayer.getName(),
            identifier = xPlayer.identifier,
            plate = plate,
            garage = garage
        })
    end
    
    return true
end

-- Fonction pour sortir un véhicule
local function spawnVehicle(source, plate, garage, coords, heading, repair)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    local garageConfig = Config.Garages[garage]
    if not garageConfig then return false end
    
    -- Vérifier les permissions
    if garageConfig.type == 'job' and xPlayer.job.name ~= garageConfig.job then
        return false
    end
    
    -- Vérifier si le véhicule est déjà sorti
    if spawnedVehicles[plate] then
        return false, 'already_out'
    end
    
    -- Obtenir les données du véhicule
    local vehicle = MySQL.query.await('SELECT * FROM garage_vehicles WHERE owner = ? AND plate = ? AND garage = ?', {
        xPlayer.identifier, plate, garage
    })
    
    if not vehicle[1] then return false end
    
    local vehicleData = json.decode(vehicle[1].vehicle)
    
    -- Calculer le coût de réparation
    local repairCost = 0
    if repair and Config.UseRepair then
        repairCost = garageConfig.repairCost or 0
        if repairCost > 0 and xPlayer.getMoney() < repairCost then
            return false, 'no_money'
        end
    end
    
    -- Spawner le véhicule
    local model = vehicleData.model
    local vehicleProps = vehicleData.props or {}
    
    -- Créer le véhicule côté client
    TriggerClientEvent('garage:spawnVehicle', source, {
        model = model,
        coords = coords,
        heading = heading,
        plate = plate,
        props = vehicleProps,
        repair = repair,
        fuel = vehicleData.fuel or 100,
        damage = repair and {} or (vehicleData.damage or {})
    })
    
    -- Marquer comme sorti
    spawnedVehicles[plate] = true
    
    -- Déduire le coût de réparation
    if repairCost > 0 then
        xPlayer.removeMoney(repairCost)
    end
    
    -- Mettre à jour l'état
    MySQL.query('UPDATE garage_vehicles SET state = 0 WHERE plate = ?', {plate})
    
    -- Historique
    MySQL.insert('INSERT INTO garage_history (identifier, plate, action, garage) VALUES (?, ?, ?, ?)', {
        xPlayer.identifier, plate, 'spawn', garage
    })
    
    -- Webhook
    if Config.Webhooks then
        TriggerEvent('garage:webhook', {
            action = 'spawn',
            player = xPlayer.getName(),
            identifier = xPlayer.identifier,
            plate = plate,
            garage = garage,
            repair = repair,
            cost = repairCost
        })
    end
    
    return true
end

-- Fonction pour obtenir les véhicules en fourrière
local function getImpoundedVehicles(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end
    
    local vehicles = MySQL.query.await('SELECT * FROM garage_vehicles WHERE owner = ? AND impound = 1', {
        xPlayer.identifier
    })
    
    local result = {}
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local vehicleData = json.decode(vehicle.vehicle)
        local impoundData = json.decode(vehicle.impound_data or '{}')
        
        -- Calculer le coût total
        local daysSince = math.floor((os.time() - (impoundData.timestamp or 0)) / 86400)
        local totalCost = (impoundData.baseCost or Config.Impound.baseCost) + (daysSince * Config.Impound.dailyCost)
        
        table.insert(result, {
            id = vehicle.id,
            plate = vehicle.plate,
            model = vehicleData.model,
            name = vehicleData.name or GetDisplayNameFromVehicleModel(vehicleData.model),
            reason = impoundData.reason or 'Non spécifié',
            cost = totalCost,
            days = daysSince,
            impoundedBy = impoundData.officer or 'Système'
        })
    end
    
    return result
end

-- Events
RegisterNetEvent('garage:getVehicles', function(garage)
    local source = source
    local vehicles = getPlayerVehicles(source, garage)
    TriggerClientEvent('garage:receiveVehicles', source, vehicles)
end)

RegisterNetEvent('garage:spawnVehicle', function(plate, garage, coords, heading, repair)
    local source = source
    local success, error = spawnVehicle(source, plate, garage, coords, heading, repair)
    TriggerClientEvent('garage:spawnResult', source, success, error)
end)

RegisterNetEvent('garage:storeVehicle', function(plate, garage)
    local source = source
    local success = storeVehicle(source, plate, garage)
    TriggerClientEvent('garage:storeResult', source, success)
end)

RegisterNetEvent('garage:getImpoundedVehicles', function()
    local source = source
    local vehicles = getImpoundedVehicles(source)
    TriggerClientEvent('garage:receiveImpoundedVehicles', source, vehicles)
end)

RegisterNetEvent('garage:retrieveFromImpound', function(plate)
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local vehicle = MySQL.query.await('SELECT * FROM garage_vehicles WHERE owner = ? AND plate = ? AND impound = 1', {
        xPlayer.identifier, plate
    })
    
    if not vehicle[1] then return end
    
    local impoundData = json.decode(vehicle[1].impound_data or '{}')
    local daysSince = math.floor((os.time() - (impoundData.timestamp or 0)) / 86400)
    local totalCost = (impoundData.baseCost or Config.Impound.baseCost) + (daysSince * Config.Impound.dailyCost)
    
    if xPlayer.getMoney() < totalCost then
        TriggerClientEvent('garage:notify', source, Config.Messages['no_money'], 'error')
        return
    end
    
    -- Déduire l'argent
    xPlayer.removeMoney(totalCost)
    
    -- Remettre le véhicule dans le garage par défaut
    MySQL.query('UPDATE garage_vehicles SET impound = 0, impound_data = NULL, garage = ? WHERE plate = ?', {
        'legion', plate
    })
    
    -- Historique
    MySQL.insert('INSERT INTO garage_history (identifier, plate, action, garage) VALUES (?, ?, ?, ?)', {
        xPlayer.identifier, plate, 'retrieve_impound', 'impound'
    })
    
    TriggerClientEvent('garage:notify', source, Config.Messages['vehicle_retrieved'], 'success')
    
    -- Webhook
    if Config.Webhooks then
        TriggerEvent('garage:webhook', {
            action = 'retrieve_impound',
            player = xPlayer.getName(),
            identifier = xPlayer.identifier,
            plate = plate,
            cost = totalCost
        })
    end
end)

-- Callback pour vérifier si un véhicule est spawné
ESX.RegisterServerCallback('garage:isVehicleOut', function(source, cb, plate)
    cb(spawnedVehicles[plate] ~= nil)
end)

-- Event quand un véhicule est détruit
RegisterNetEvent('garage:vehicleDestroyed', function(plate)
    spawnedVehicles[plate] = nil
end)

-- Event quand un véhicule est créé
RegisterNetEvent('garage:vehicleCreated', function(plate, netId)
    spawnedVehicles[plate] = netId
end)

-- Nettoyage périodique des véhicules
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        
        for plate, netId in pairs(spawnedVehicles) do
            if not DoesEntityExist(netId) then
                spawnedVehicles[plate] = nil
            end
        end
    end
end)

print('^2[Advanced Garage] ^7Serveur initialisé avec succès')