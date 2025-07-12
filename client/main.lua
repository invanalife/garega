ESX = exports['es_extended']:getSharedObject()

-- Variables locales
local currentGarage = nil
local isInGarage = false
local garageBlips = {}
local vehicleSpawned = false

-- Fonction pour créer les blips
local function createBlips()
    for garageId, garageConfig in pairs(Config.Garages) do
        if garageConfig.blip then
            local blip = AddBlipForCoord(garageConfig.coords.x, garageConfig.coords.y, garageConfig.coords.z)
            SetBlipSprite(blip, Config.Blips.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blips.scale)
            SetBlipColour(blip, Config.Blips.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(garageConfig.name)
            EndTextCommandSetBlipName(blip)
            
            garageBlips[garageId] = blip
        end
    end
    
    -- Blip pour la fourrière
    if Config.UseImpound and Config.Impound.blip then
        local blip = AddBlipForCoord(Config.Impound.coords.x, Config.Impound.coords.y, Config.Impound.coords.z)
        SetBlipSprite(blip, 68)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 17)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Fourrière")
        EndTextCommandSetBlipName(blip)
        
        garageBlips['impound'] = blip
    end
end

-- Fonction pour créer les marqueurs
local function createMarkers()
    CreateThread(function()
        while true do
            local sleep = 1000
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            for garageId, garageConfig in pairs(Config.Garages) do
                local distance = #(playerCoords - garageConfig.coords)
                
                if distance <= 50.0 then
                    sleep = 0
                    
                    -- Dessiner le marqueur
                    DrawMarker(
                        garageConfig.marker.type,
                        garageConfig.coords.x, garageConfig.coords.y, garageConfig.coords.z - 1.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        garageConfig.marker.size.x, garageConfig.marker.size.y, garageConfig.marker.size.z,
                        garageConfig.marker.color.r, garageConfig.marker.color.g, garageConfig.marker.color.b, garageConfig.marker.color.a,
                        false, true, 2, false, nil, nil, false
                    )
                    
                    -- Interaction
                    if distance <= 3.0 then
                        if not Config.UseTarget then
                            ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le garage')
                            
                            if IsControlJustPressed(0, 38) then -- E
                                openGarage(garageId)
                            end
                        end
                    end
                end
            end
            
            -- Marqueur fourrière
            if Config.UseImpound then
                local distance = #(playerCoords - Config.Impound.coords)
                
                if distance <= 50.0 then
                    sleep = 0
                    
                    DrawMarker(
                        Config.Impound.marker.type,
                        Config.Impound.coords.x, Config.Impound.coords.y, Config.Impound.coords.z - 1.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        Config.Impound.marker.size.x, Config.Impound.marker.size.y, Config.Impound.marker.size.z,
                        Config.Impound.marker.color.r, Config.Impound.marker.color.g, Config.Impound.marker.color.b, Config.Impound.marker.color.a,
                        false, true, 2, false, nil, nil, false
                    )
                    
                    if distance <= 3.0 then
                        if not Config.UseTarget then
                            ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour ouvrir la fourrière')
                            
                            if IsControlJustPressed(0, 38) then -- E
                                openImpound()
                            end
                        end
                    end
                end
            end
            
            Wait(sleep)
        end
    end)
end

-- Fonction pour ouvrir le garage
function openGarage(garageId)
    local garageConfig = Config.Garages[garageId]
    if not garageConfig then return end
    
    -- Vérifier les permissions pour les jobs
    if garageConfig.type == 'job' then
        ESX.TriggerServerCallback('esx:getPlayerData', function(playerData)
            if playerData.job.name ~= garageConfig.job then
                ESX.ShowNotification('Vous n\'avez pas accès à ce garage', 'error')
                return
            end
            
            currentGarage = garageId
            isInGarage = true
            TriggerServerEvent('garage:getVehicles', garageId)
        end)
    else
        currentGarage = garageId
        isInGarage = true
        TriggerServerEvent('garage:getVehicles', garageId)
    end
end

-- Fonction pour ouvrir la fourrière
function openImpound()
    if not Config.UseImpound then return end
    
    currentGarage = 'impound'
    isInGarage = true
    TriggerServerEvent('garage:getImpoundedVehicles')
end

-- Fonction pour fermer le garage
function closeGarage()
    isInGarage = false
    currentGarage = nil
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

-- Fonction pour spawner un véhicule
local function spawnVehicle(vehicleData)
    if vehicleSpawned then return end
    vehicleSpawned = true
    
    local model = vehicleData.model
    local coords = vehicleData.coords
    local heading = vehicleData.heading
    local plate = vehicleData.plate
    local props = vehicleData.props
    local repair = vehicleData.repair
    local fuel = vehicleData.fuel
    local damage = vehicleData.damage
    
    -- Charger le modèle
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    
    -- Créer le véhicule
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
    
    -- Attendre que le véhicule soit créé
    while not DoesEntityExist(vehicle) do
        Wait(0)
    end
    
    -- Appliquer les propriétés
    if props then
        ESX.Game.SetVehicleProperties(vehicle, props)
    end
    
    -- Appliquer les dégâts si pas de réparation
    if not repair and damage then
        for component, dmg in pairs(damage) do
            if component == 'engine' then
                SetVehicleEngineHealth(vehicle, dmg)
            elseif component == 'body' then
                SetVehicleBodyHealth(vehicle, dmg)
            elseif component == 'petrol' then
                SetVehiclePetrolTankHealth(vehicle, dmg)
            end
        end
    end
    
    -- Définir le carburant
    if fuel then
        SetVehicleFuelLevel(vehicle, fuel + 0.0)
    end
    
    -- Définir la plaque
    SetVehicleNumberPlateText(vehicle, plate)
    
    -- Effet de spawn
    SetEntityAlpha(vehicle, 0)
    
    -- Animation de spawn
    CreateThread(function()
        local alpha = 0
        while alpha < 255 do
            alpha = alpha + 5
            SetEntityAlpha(vehicle, alpha)
            Wait(10)
        end
        SetEntityAlpha(vehicle, 255)
    end)
    
    -- Donner les clés
    if Config.VehicleKeys == 'vehiclekeys' then
        exports['vehiclekeys']:GiveKeys(plate)
    elseif Config.VehicleKeys == 'qs-vehiclekeys' then
        exports['qs-vehiclekeys']:GiveKeys(plate)
    elseif Config.VehicleKeys == 'cd_garage' then
        TriggerEvent('cd_garage:AddKeys', plate)
    end
    
    -- Notifier le serveur
    TriggerServerEvent('garage:vehicleCreated', plate, NetworkGetNetworkIdFromEntity(vehicle))
    
    -- Placer le joueur dans le véhicule
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    
    vehicleSpawned = false
end

-- Fonction pour ranger un véhicule
local function storeVehicle()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        ESX.ShowNotification('Vous devez être dans un véhicule', 'error')
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = string.gsub(plate, "%s+", "") -- Supprimer les espaces
    
    -- Sauvegarder les données du véhicule
    local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
    local fuel = GetVehicleFuelLevel(vehicle)
    local damage = {
        engine = GetVehicleEngineHealth(vehicle),
        body = GetVehicleBodyHealth(vehicle),
        petrol = GetVehiclePetrolTankHealth(vehicle)
    }
    
    -- Supprimer le véhicule avec animation
    local alpha = 255
    CreateThread(function()
        while alpha > 0 do
            alpha = alpha - 5
            SetEntityAlpha(vehicle, alpha)
            Wait(10)
        end
        DeleteEntity(vehicle)
    end)
    
    -- Notifier le serveur
    TriggerServerEvent('garage:storeVehicle', plate, currentGarage)
end

-- Configuration ox_target
if Config.UseTarget then
    CreateThread(function()
        for garageId, garageConfig in pairs(Config.Garages) do
            exports.ox_target:addSphereZone({
                coords = garageConfig.coords,
                radius = 3.0,
                options = {
                    {
                        name = 'garage_' .. garageId,
                        icon = 'fas fa-car',
                        label = 'Ouvrir le garage',
                        onSelect = function()
                            openGarage(garageId)
                        end
                    }
                }
            })
        end
        
        -- Zone pour la fourrière
        if Config.UseImpound then
            exports.ox_target:addSphereZone({
                coords = Config.Impound.coords,
                radius = 3.0,
                options = {
                    {
                        name = 'impound',
                        icon = 'fas fa-exclamation-triangle',
                        label = 'Fourrière',
                        onSelect = function()
                            openImpound()
                        end
                    }
                }
            })
        end
    end)
end

-- Events
RegisterNetEvent('garage:receiveVehicles', function(vehicles)
    SendNUIMessage({
        action = 'showVehicles',
        vehicles = vehicles,
        garage = currentGarage,
        garageConfig = Config.Garages[currentGarage]
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('garage:receiveImpoundedVehicles', function(vehicles)
    SendNUIMessage({
        action = 'showImpound',
        vehicles = vehicles
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('garage:spawnVehicle', function(data)
    spawnVehicle(data)
end)

RegisterNetEvent('garage:spawnResult', function(success, error)
    if success then
        ESX.ShowNotification(Config.Messages['vehicle_spawned'], 'success')
        closeGarage()
    else
        if error == 'already_out' then
            ESX.ShowNotification(Config.Messages['vehicle_already_out'], 'error')
        elseif error == 'no_money' then
            ESX.ShowNotification(Config.Messages['no_money'], 'error')
        end
    end
end)

RegisterNetEvent('garage:storeResult', function(success)
    if success then
        ESX.ShowNotification(Config.Messages['vehicle_stored'], 'success')
        closeGarage()
    else
        ESX.ShowNotification(Config.Messages['vehicle_not_owned'], 'error')
    end
end)

RegisterNetEvent('garage:notify', function(message, type)
    ESX.ShowNotification(message, type)
end)

-- Callbacks NUI
RegisterNUICallback('close', function(data, cb)
    closeGarage()
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local garageConfig = Config.Garages[currentGarage]
    if not garageConfig then
        cb('error')
        return
    end
    
    local coords = garageConfig.spawnCoords
    TriggerServerEvent('garage:spawnVehicle', data.plate, currentGarage, coords, coords.w, data.repair)
    cb('ok')
end)

RegisterNUICallback('storeVehicle', function(data, cb)
    storeVehicle()
    cb('ok')
end)

RegisterNUICallback('retrieveFromImpound', function(data, cb)
    TriggerServerEvent('garage:retrieveFromImpound', data.plate)
    cb('ok')
end)

RegisterNUICallback('getVehicleImage', function(data, cb)
    -- Retourner l'image du véhicule (peut être connecté à un système d'images)
    cb('https://via.placeholder.com/300x200?text=' .. data.model)
end)

-- Initialisation
CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Wait(10)
    end
    
    createBlips()
    createMarkers()
end)

-- Nettoyage à la déconnexion
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        for _, blip in pairs(garageBlips) do
            RemoveBlip(blip)
        end
        
        if isInGarage then
            closeGarage()
        end
    end
end)

-- Commande pour ranger le véhicule actuel
RegisterCommand('parkcar', function()
    if not currentGarage then
        ESX.ShowNotification('Vous devez être près d\'un garage', 'error')
        return
    end
    
    storeVehicle()
end, false)

-- Exports pour d'autres scripts
exports('openGarage', openGarage)
exports('closeGarage', closeGarage)
exports('isInGarage', function() return isInGarage end)