-- Commandes administrateur pour le système de garage

-- Fonction pour vérifier les permissions admin
local function isAdmin(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    
    for _, group in pairs(Config.AdminGroups) do
        if xPlayer.getGroup() == group then
            return true
        end
    end
    return false
end

-- Commande pour supprimer un véhicule du garage
RegisterCommand('deletevehicle', function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Vous n'avez pas les permissions nécessaires"}
        })
        return
    end
    
    if not args[1] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 165, 0},
            multiline = false,
            args = {"[GARAGE]", "Usage: /deletevehicle [plaque]"}
        })
        return
    end
    
    local plate = args[1]:upper()
    
    -- Supprimer de la base de données
    MySQL.query('DELETE FROM garage_vehicles WHERE plate = ?', {plate}, function(result)
        if result.affectedRows > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = false,
                args = {"[GARAGE]", "Véhicule " .. plate .. " supprimé du garage"}
            })
            
            -- Supprimer aussi des véhicules possédés
            MySQL.query('DELETE FROM owned_vehicles WHERE plate = ?', {plate})
            
            -- Webhook
            if Config.Webhooks then
                TriggerEvent('garage:webhook', {
                    action = 'admin_delete',
                    admin = GetPlayerName(source),
                    plate = plate
                })
            end
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = false,
                args = {"[GARAGE]", "Véhicule introuvable"}
            })
        end
    end)
end, false)

-- Commande pour mettre un véhicule en fourrière
RegisterCommand('impoundvehicle', function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Vous n'avez pas les permissions nécessaires"}
        })
        return
    end
    
    if not args[1] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 165, 0},
            multiline = false,
            args = {"[GARAGE]", "Usage: /impoundvehicle [plaque] [raison]"}
        })
        return
    end
    
    local plate = args[1]:upper()
    local reason = table.concat(args, " ", 2) or "Infraction administrative"
    local adminName = GetPlayerName(source)
    
    -- Vérifier si le véhicule existe
    MySQL.query('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        if result[1] then
            local vehicleData = result[1].vehicle
            
            -- Créer les données de fourrière
            local impoundData = {
                reason = reason,
                officer = adminName,
                timestamp = os.time(),
                baseCost = Config.Impound.baseCost
            }
            
            -- Insérer ou mettre à jour dans garage_vehicles
            MySQL.query('INSERT INTO garage_vehicles (owner, plate, vehicle, garage, impound, impound_data) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE impound = 1, impound_data = ?', {
                result[1].owner, plate, vehicleData, 'impound', 1, json.encode(impoundData), json.encode(impoundData)
            })
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = false,
                args = {"[GARAGE]", "Véhicule " .. plate .. " mis en fourrière"}
            })
            
            -- Webhook
            if Config.Webhooks then
                TriggerEvent('garage:webhook', {
                    action = 'admin_impound',
                    admin = adminName,
                    plate = plate,
                    reason = reason
                })
            end
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = false,
                args = {"[GARAGE]", "Véhicule introuvable"}
            })
        end
    end)
end, false)

-- Commande pour voir tous les véhicules d'un joueur
RegisterCommand('playervehicles', function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Vous n'avez pas les permissions nécessaires"}
        })
        return
    end
    
    if not args[1] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 165, 0},
            multiline = false,
            args = {"[GARAGE]", "Usage: /playervehicles [id]"}
        })
        return
    end
    
    local targetId = tonumber(args[1])
    local xTarget = ESX.GetPlayerFromId(targetId)
    
    if not xTarget then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Joueur introuvable"}
        })
        return
    end
    
    -- Obtenir tous les véhicules du joueur
    MySQL.query('SELECT * FROM owned_vehicles WHERE owner = ?', {xTarget.identifier}, function(result)
        if result[1] then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 255},
                multiline = false,
                args = {"[GARAGE]", "Véhicules de " .. xTarget.getName() .. ":"}
            })
            
            for i = 1, #result do
                local vehicle = result[i]
                local vehicleData = json.decode(vehicle.vehicle)
                local modelName = GetDisplayNameFromVehicleModel(vehicleData.model)
                
                TriggerClientEvent('chat:addMessage', source, {
                    color = {255, 255, 255},
                    multiline = false,
                    args = {"", "- " .. modelName .. " (" .. vehicle.plate .. ")"}
                })
            end
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = false,
                args = {"[GARAGE]", "Aucun véhicule trouvé"}
            })
        end
    end)
end, false)

-- Commande pour forcer la sortie d'un véhicule de fourrière
RegisterCommand('releaseimpound', function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Vous n'avez pas les permissions nécessaires"}
        })
        return
    end
    
    if not args[1] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 165, 0},
            multiline = false,
            args = {"[GARAGE]", "Usage: /releaseimpound [plaque]"}
        })
        return
    end
    
    local plate = args[1]:upper()
    
    -- Libérer le véhicule de la fourrière
    MySQL.query('UPDATE garage_vehicles SET impound = 0, impound_data = NULL, garage = ? WHERE plate = ? AND impound = 1', {
        'legion', plate
    }, function(result)
        if result.affectedRows > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = false,
                args = {"[GARAGE]", "Véhicule " .. plate .. " libéré de la fourrière"}
            })
            
            -- Webhook
            if Config.Webhooks then
                TriggerEvent('garage:webhook', {
                    action = 'admin_release',
                    admin = GetPlayerName(source),
                    plate = plate
                })
            end
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = false,
                args = {"[GARAGE]", "Véhicule introuvable en fourrière"}
            })
        end
    end)
end, false)

-- Commande pour nettoyer les véhicules abandonnés
RegisterCommand('cleangarage', function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Vous n'avez pas les permissions nécessaires"}
        })
        return
    end
    
    local days = tonumber(args[1]) or 30
    local timestamp = os.time() - (days * 86400)
    
    -- Supprimer les véhicules anciens
    MySQL.query('DELETE FROM garage_vehicles WHERE stored < FROM_UNIXTIME(?)', {timestamp}, function(result)
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = false,
            args = {"[GARAGE]", result.affectedRows .. " véhicules supprimés (+" .. days .. " jours)"}
        })
        
        -- Webhook
        if Config.Webhooks then
            TriggerEvent('garage:webhook', {
                action = 'admin_clean',
                admin = GetPlayerName(source),
                count = result.affectedRows,
                days = days
            })
        end
    end)
end, false)

-- Commande pour téléporter à un garage
RegisterCommand('tpgarage', function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Vous n'avez pas les permissions nécessaires"}
        })
        return
    end
    
    if not args[1] then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 165, 0},
            multiline = false,
            args = {"[GARAGE]", "Usage: /tpgarage [nom_garage]"}
        })
        
        -- Lister les garages disponibles
        local garageList = {}
        for garageId, _ in pairs(Config.Garages) do
            table.insert(garageList, garageId)
        end
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 255},
            multiline = false,
            args = {"[GARAGE]", "Garages disponibles: " .. table.concat(garageList, ", ")}
        })
        return
    end
    
    local garageName = args[1]:lower()
    local garageConfig = Config.Garages[garageName]
    
    if not garageConfig then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Garage introuvable"}
        })
        return
    end
    
    -- Téléporter le joueur
    TriggerClientEvent('garage:teleport', source, garageConfig.coords)
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {0, 255, 0},
        multiline = false,
        args = {"[GARAGE]", "Téléporté au garage " .. garageConfig.name}
    })
end, false)

-- Commande pour les statistiques du garage
RegisterCommand('garagestats', function(source, args, rawCommand)
    if not isAdmin(source) then
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = false,
            args = {"[GARAGE]", "Vous n'avez pas les permissions nécessaires"}
        })
        return
    end
    
    -- Statistiques générales
    MySQL.query('SELECT COUNT(*) as total, SUM(CASE WHEN impound = 1 THEN 1 ELSE 0 END) as impounded, SUM(CASE WHEN state = 0 THEN 1 ELSE 0 END) as out FROM garage_vehicles', {}, function(result)
        if result[1] then
            local stats = result[1]
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 255},
                multiline = false,
                args = {"[GARAGE]", "=== STATISTIQUES GARAGE ==="}
            })
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 255},
                multiline = false,
                args = {"", "Total véhicules: " .. stats.total}
            })
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 255},
                multiline = false,
                args = {"", "Véhicules sortis: " .. stats.out}
            })
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 255},
                multiline = false,
                args = {"", "Véhicules en fourrière: " .. stats.impounded}
            })
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 255, 255},
                multiline = false,
                args = {"", "Véhicules rangés: " .. (stats.total - stats.out - stats.impounded)}
            })
        end
    end)
end, false)

-- Event pour téléporter un joueur (côté client)
RegisterNetEvent('garage:teleport', function(coords)
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z + 1.0)
end)

print('^2[Advanced Garage] ^7Commandes administrateur chargées')