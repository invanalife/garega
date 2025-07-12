-- Utilitaires côté client pour le système de garage

-- Fonction pour obtenir le nom d'affichage d'un véhicule
function GetVehicleDisplayName(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end
    
    local displayName = GetDisplayNameFromVehicleModel(model)
    local text = GetLabelText(displayName)
    
    if text == 'NULL' then
        return displayName
    end
    
    return text
end

-- Fonction pour obtenir la classe d'un véhicule
function GetVehicleClassFromModel(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end
    
    return GetVehicleClassFromName(model)
end

-- Fonction pour vérifier si un véhicule appartient à une catégorie
function IsVehicleInCategory(model, category)
    local vehicleClass = GetVehicleClassFromModel(model)
    local categoryConfig = Config.VehicleCategories[category]
    
    if not categoryConfig then return false end
    
    for _, class in pairs(categoryConfig.classes) do
        if class == vehicleClass then
            return true
        end
    end
    
    return false
end

-- Fonction pour obtenir la catégorie d'un véhicule
function GetVehicleCategory(model)
    local vehicleClass = GetVehicleClassFromModel(model)
    
    for category, config in pairs(Config.VehicleCategories) do
        for _, class in pairs(config.classes) do
            if class == vehicleClass then
                return category
            end
        end
    end
    
    return 'car' -- Par défaut
end

-- Fonction pour obtenir l'état d'un véhicule (pourcentage de dégâts)
function GetVehicleDamageStatus(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    
    local enginePercent = math.floor((engineHealth / 1000) * 100)
    local bodyPercent = math.floor((bodyHealth / 1000) * 100)
    
    return {
        engine = enginePercent,
        body = bodyPercent,
        overall = math.floor((enginePercent + bodyPercent) / 2)
    }
end

-- Fonction pour obtenir le niveau de carburant
function GetVehicleFuelLevel(vehicle)
    return GetVehicleFuelLevel(vehicle) or 100
end

-- Fonction pour créer un effet de particules
function CreateSpawnEffect(coords)
    RequestNamedPtfxAsset('scr_rcbarry1')
    
    while not HasNamedPtfxAssetLoaded('scr_rcbarry1') do
        Wait(0)
    end
    
    UseParticleFxAssetNextCall('scr_rcbarry1')
    StartParticleFxLoopedAtCoord('scr_alien_teleport', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
end

-- Fonction pour créer un effet de lumière
function CreateSpawnLight(coords)
    local light = CreateObject(GetHashKey('prop_spot_01'), coords.x, coords.y, coords.z - 1.0, true, true, true)
    
    CreateThread(function()
        Wait(3000)
        DeleteObject(light)
    end)
end

-- Fonction pour animer l'apparition d'un véhicule
function AnimateVehicleSpawn(vehicle, callback)
    if not DoesEntityExist(vehicle) then return end
    
    -- Effet de transparence
    SetEntityAlpha(vehicle, 0)
    
    -- Position initiale (légèrement plus haut)
    local coords = GetEntityCoords(vehicle)
    SetEntityCoords(vehicle, coords.x, coords.y, coords.z + 2.0)
    
    CreateThread(function()
        local alpha = 0
        local height = 2.0
        
        while alpha < 255 do
            alpha = alpha + 15
            height = height - 0.1
            
            SetEntityAlpha(vehicle, alpha)
            SetEntityCoords(vehicle, coords.x, coords.y, coords.z + height)
            
            Wait(50)
        end
        
        SetEntityAlpha(vehicle, 255)
        SetEntityCoords(vehicle, coords.x, coords.y, coords.z)
        
        if callback then
            callback()
        end
    end)
end

-- Fonction pour animer la disparition d'un véhicule
function AnimateVehicleStore(vehicle, callback)
    if not DoesEntityExist(vehicle) then return end
    
    local coords = GetEntityCoords(vehicle)
    
    CreateThread(function()
        local alpha = 255
        local height = 0.0
        
        while alpha > 0 do
            alpha = alpha - 15
            height = height + 0.1
            
            SetEntityAlpha(vehicle, alpha)
            SetEntityCoords(vehicle, coords.x, coords.y, coords.z + height)
            
            Wait(50)
        end
        
        DeleteEntity(vehicle)
        
        if callback then
            callback()
        end
    end)
end

-- Fonction pour obtenir le véhicule le plus proche
function GetClosestVehicle(coords, radius)
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = nil
    local closestDistance = radius or 10.0
    
    for _, vehicle in pairs(vehicles) do
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(coords - vehicleCoords)
        
        if distance < closestDistance then
            closestVehicle = vehicle
            closestDistance = distance
        end
    end
    
    return closestVehicle, closestDistance
end

-- Fonction pour vérifier si un véhicule est possédé par le joueur
function IsVehicleOwned(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = string.gsub(plate, "%s+", "")
    
    -- Utiliser un callback serveur pour vérifier
    local isOwned = false
    ESX.TriggerServerCallback('garage:isVehicleOwned', function(result)
        isOwned = result
    end, plate)
    
    -- Attendre la réponse (pas idéal mais nécessaire pour la synchronisation)
    while isOwned == false do
        Wait(10)
    end
    
    return isOwned
end

-- Fonction pour obtenir les statistiques d'un véhicule
function GetVehicleStats(model)
    if type(model) == 'string' then
        model = GetHashKey(model)
    end
    
    local stats = {
        speed = GetVehicleModelMaxSpeed(model),
        acceleration = GetVehicleModelAcceleration(model),
        braking = GetVehicleModelMaxBraking(model),
        handling = GetVehicleModelMaxTraction(model)
    }
    
    -- Convertir en pourcentages
    stats.speed = math.floor((stats.speed / 50.0) * 100)
    stats.acceleration = math.floor(stats.acceleration * 100)
    stats.braking = math.floor(stats.braking * 100)
    stats.handling = math.floor(stats.handling * 100)
    
    return stats
end

-- Fonction pour formater la distance
function FormatDistance(distance)
    if distance < 1000 then
        return string.format("%.0fm", distance)
    else
        return string.format("%.1fkm", distance / 1000)
    end
end

-- Fonction pour formater le temps
function FormatTime(timestamp)
    local currentTime = os.time()
    local diff = currentTime - timestamp
    
    if diff < 60 then
        return "Il y a " .. diff .. " secondes"
    elseif diff < 3600 then
        return "Il y a " .. math.floor(diff / 60) .. " minutes"
    elseif diff < 86400 then
        return "Il y a " .. math.floor(diff / 3600) .. " heures"
    else
        return "Il y a " .. math.floor(diff / 86400) .. " jours"
    end
end

-- Fonction pour obtenir la couleur selon l'état
function GetStatusColor(percentage)
    if percentage >= 80 then
        return {r = 0, g = 255, b = 0} -- Vert
    elseif percentage >= 50 then
        return {r = 255, g = 255, b = 0} -- Jaune
    elseif percentage >= 20 then
        return {r = 255, g = 165, b = 0} -- Orange
    else
        return {r = 255, g = 0, b = 0} -- Rouge
    end
end

-- Fonction pour créer un blip temporaire
function CreateTemporaryBlip(coords, sprite, color, text, duration)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipAsShortRange(blip, true)
    
    if text then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandSetBlipName(blip)
    end
    
    if duration then
        CreateThread(function()
            Wait(duration)
            RemoveBlip(blip)
        end)
    end
    
    return blip
end

-- Fonction pour jouer un son
function PlayGarageSound(soundName, soundSet)
    PlaySoundFrontend(-1, soundName or 'SELECT', soundSet or 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end

-- Fonction pour vibrer la manette
function VibrateController(duration, strength)
    if IsUsingKeyboard(2) then return end
    
    duration = duration or 500
    strength = strength or 255
    
    CreateThread(function()
        SetControllerShakeLevel(0, strength, strength)
        Wait(duration)
        SetControllerShakeLevel(0, 0, 0)
    end)
end

-- Fonction pour obtenir la météo actuelle
function GetCurrentWeather()
    local weather = GetWeatherTypeTransition()
    return weather
end

-- Fonction pour vérifier si c'est la nuit
function IsNightTime()
    local hour = GetClockHours()
    return hour >= 20 or hour <= 6
end

-- Fonction pour obtenir des informations sur le joueur
function GetPlayerInfo()
    local playerData = ESX.GetPlayerData()
    return {
        name = playerData.getName and playerData.getName() or 'Joueur',
        job = playerData.job,
        money = playerData.money,
        bank = playerData.bank,
        identifier = playerData.identifier
    }
end

-- Exports des fonctions utilitaires
exports('GetVehicleDisplayName', GetVehicleDisplayName)
exports('GetVehicleClassFromModel', GetVehicleClassFromModel)
exports('IsVehicleInCategory', IsVehicleInCategory)
exports('GetVehicleCategory', GetVehicleCategory)
exports('GetVehicleDamageStatus', GetVehicleDamageStatus)
exports('GetVehicleFuelLevel', GetVehicleFuelLevel)
exports('AnimateVehicleSpawn', AnimateVehicleSpawn)
exports('AnimateVehicleStore', AnimateVehicleStore)
exports('GetClosestVehicle', GetClosestVehicle)
exports('GetVehicleStats', GetVehicleStats)
exports('FormatDistance', FormatDistance)
exports('FormatTime', FormatTime)
exports('GetStatusColor', GetStatusColor)
exports('PlayGarageSound', PlayGarageSound)