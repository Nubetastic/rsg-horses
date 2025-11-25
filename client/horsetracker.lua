local trackedHorse = 0
local pendingFlee = false
local trackingActive = false
local checkInterval = 10000
local maxDistance = 100.0

local function startMonitoring()
    if trackingActive then return end
    trackingActive = true
    CreateThread(function()
        while trackingActive do
            if trackedHorse == 0 then
                trackingActive = false
                break
            end
            Wait(checkInterval)
            if not trackingActive then break end
            if trackedHorse == 0 then
                trackingActive = false
                break
            end
            if not DoesEntityExist(trackedHorse) then
                trackedHorse = 0
                pendingFlee = false
                trackingActive = false
                break
            end
            local playerPed = cache and cache.ped or PlayerPedId()
            if playerPed ~= 0 then
                local playerCoords = GetEntityCoords(playerPed)
                local horseCoords = GetEntityCoords(trackedHorse)
                if #(playerCoords - horseCoords) > maxDistance and not pendingFlee then
                    pendingFlee = true
                    TriggerEvent('rsg-horses:client:tracker:requestFlee')
                end
            end
        end
        trackingActive = false
    end)
end

RegisterNetEvent('rsg-horses:client:tracker:setHorse', function(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    trackedHorse = ped
    pendingFlee = false
    startMonitoring()
end)

RegisterNetEvent('rsg-horses:client:tracker:clearHorse', function()
    trackedHorse = 0
    pendingFlee = false
    trackingActive = false
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if trackedHorse ~= 0 and DoesEntityExist(trackedHorse) then
        TriggerEvent('rsg-horses:client:tracker:requestFlee')
    end
    trackedHorse = 0
    pendingFlee = false
    trackingActive = false
end)
