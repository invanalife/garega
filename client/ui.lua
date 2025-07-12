-- Interface utilisateur pour le système de garage

local UIOpen = false
local currentVehicles = {}
local currentGarageData = {}

-- Fonction pour ouvrir l'interface
function OpenGarageUI(vehicles, garageId, garageConfig)
    if UIOpen then return end
    
    UIOpen = true
    currentVehicles = vehicles
    currentGarageData = garageConfig
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showGarage',
        vehicles = vehicles,
        garage = garageId,
        garageConfig = garageConfig,
        messages = Config.Messages
    })
end

-- Fonction pour fermer l'interface
function CloseGarageUI()
    if not UIOpen then return end
    
    UIOpen = false
    currentVehicles = {}
    currentGarageData = {}
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'hideGarage'
    })
end

-- Fonction pour ouvrir l'interface de fourrière
function OpenImpoundUI(vehicles)
    if UIOpen then return end
    
    UIOpen = true
    currentVehicles = vehicles
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showImpound',
        vehicles = vehicles,
        messages = Config.Messages,
        impoundConfig = Config.Impound
    })
end

-- Fonction pour mettre à jour la liste des véhicules
function UpdateVehicleList(vehicles)
    currentVehicles = vehicles
    SendNUIMessage({
        action = 'updateVehicles',
        vehicles = vehicles
    })
end

-- Fonction pour afficher un message dans l'interface
function ShowUINotification(message, type)
    SendNUIMessage({
        action = 'showNotification',
        message = message,
        type = type or 'info'
    })
end

-- Fonction pour afficher un loader
function ShowUILoader(show, message)
    SendNUIMessage({
        action = 'showLoader',
        show = show,
        message = message or 'Chargement...'
    })
end

-- Fonction pour afficher la boîte de dialogue de confirmation
function ShowConfirmDialog(title, message, callback)
    SendNUIMessage({
        action = 'showConfirm',
        title = title,
        message = message,
        callback = callback
    })
end

-- Callbacks NUI
RegisterNUICallback('closeGarage', function(data, cb)
    CloseGarageUI()
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local garageConfig = Config.Garages[currentGarage]
    if not garageConfig then
        cb('error')
        return
    end
    
    ShowUILoader(true, 'Sortie du véhicule...')
    
    local coords = garageConfig.spawnCoords
    TriggerServerEvent('garage:spawnVehicle', data.plate, currentGarage, coords, coords.w, data.repair or false)
    cb('ok')
end)

RegisterNUICallback('storeVehicle', function(data, cb)
    ShowUILoader(true, 'Rangement du véhicule...')
    
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        ShowUINotification('Vous devez être dans un véhicule', 'error')
        ShowUILoader(false)
        cb('error')
        return
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = string.gsub(plate, "%s+", "")
    
    TriggerServerEvent('garage:storeVehicle', plate, currentGarage)
    cb('ok')
end)

RegisterNUICallback('retrieveFromImpound', function(data, cb)
    ShowUILoader(true, 'Récupération du véhicule...')
    TriggerServerEvent('garage:retrieveFromImpound', data.plate)
    cb('ok')
end)

RegisterNUICallback('getVehicleInfo', function(data, cb)
    -- Obtenir les informations détaillées du véhicule
    local vehicleInfo = {
        model = data.model,
        name = data.name,
        plate = data.plate,
        image = 'https://via.placeholder.com/400x200/333333/ffffff?text=' .. (data.name or 'Véhicule'),
        stats = {
            speed = GetVehicleModelMaxSpeed(data.model),
            acceleration = GetVehicleModelAcceleration(data.model),
            braking = GetVehicleModelMaxBraking(data.model),
            handling = GetVehicleModelMaxTraction(data.model)
        }
    }
    
    cb(vehicleInfo)
end)

RegisterNUICallback('playSound', function(data, cb)
    -- Jouer un son
    PlaySoundFrontend(-1, data.sound or 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
    cb('ok')
end)

RegisterNUICallback('requestVehiclePreview', function(data, cb)
    -- Demander un aperçu du véhicule (peut être utilisé pour afficher le véhicule en 3D)
    TriggerEvent('garage:requestVehiclePreview', data.model)
    cb('ok')
end)

-- Events reçus du serveur
RegisterNetEvent('garage:receiveVehicles', function(vehicles)
    UpdateVehicleList(vehicles)
    OpenGarageUI(vehicles, currentGarage, Config.Garages[currentGarage])
end)

RegisterNetEvent('garage:receiveImpoundedVehicles', function(vehicles)
    OpenImpoundUI(vehicles)
end)

RegisterNetEvent('garage:spawnResult', function(success, error)
    ShowUILoader(false)
    
    if success then
        ShowUINotification(Config.Messages['vehicle_spawned'], 'success')
        CloseGarageUI()
    else
        if error == 'already_out' then
            ShowUINotification(Config.Messages['vehicle_already_out'], 'error')
        elseif error == 'no_money' then
            ShowUINotification(Config.Messages['no_money'], 'error')
        else
            ShowUINotification('Erreur lors de la sortie du véhicule', 'error')
        end
    end
end)

RegisterNetEvent('garage:storeResult', function(success)
    ShowUILoader(false)
    
    if success then
        ShowUINotification(Config.Messages['vehicle_stored'], 'success')
        CloseGarageUI()
        -- Rafraîchir la liste des véhicules
        TriggerServerEvent('garage:getVehicles', currentGarage)
    else
        ShowUINotification(Config.Messages['vehicle_not_owned'], 'error')
    end
end)

-- Fonction pour gérer les touches
CreateThread(function()
    while true do
        Wait(0)
        
        if UIOpen then
            -- Désactiver les contrôles quand l'interface est ouverte
            DisableControlAction(0, 1, true) -- LookLeftRight
            DisableControlAction(0, 2, true) -- LookUpDown
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 142, true) -- MeleeAttackAlternate
            DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
            
            -- Fermer avec ESC
            if IsControlJustPressed(0, 322) then -- ESC
                CloseGarageUI()
            end
        else
            Wait(100)
        end
    end
end)

-- Exports
exports('OpenGarageUI', OpenGarageUI)
exports('CloseGarageUI', CloseGarageUI)
exports('OpenImpoundUI', OpenImpoundUI)
exports('UpdateVehicleList', UpdateVehicleList)
exports('ShowUINotification', ShowUINotification)
exports('IsUIOpen', function() return UIOpen end)