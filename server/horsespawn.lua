local HorseSettings = lib.load('shared.horse_settings')
local HorseBreeds = lib.load('shared.horse_breed')

local stableHorseStock = {}
local stockReady = false

local function getBreedData(name)
    if type(name) ~= 'string' then return nil end
    return HorseBreeds[name] or HorseBreeds[string.lower(name)] or HorseBreeds[string.upper(name)]
end

local function generateHorseForStable(stableId, usedModels)
    local stableData = HorseSettings[stableId]
    if not stableData or not stableData.horsebreeds or #stableData.horsebreeds == 0 then return nil end

    if usedModels then
        local candidates = {}
        for _, breedName in ipairs(stableData.horsebreeds) do
            local breedData = getBreedData(breedName)
            if breedData and breedData.models and #breedData.models > 0 then
                for _, modelInfo in ipairs(breedData.models) do
                    local model = modelInfo[2]
                    if model and not usedModels[model] then
                        candidates[#candidates + 1] = {
                            breedName = breedName,
                            breedData = breedData,
                            modelInfo = modelInfo
                        }
                    end
                end
            end
        end

        if #candidates > 0 then
            local entry = candidates[math.random(#candidates)]
            local data = {
                breed = entry.breedName,
                horsename = entry.modelInfo[1],
                horsemodel = entry.modelInfo[2],
                horseprice = entry.breedData.price
            }
            usedModels[data.horsemodel] = true
            return data
        end
    end

    local breedName = stableData.horsebreeds[math.random(#stableData.horsebreeds)]
    local breedData = getBreedData(breedName)
    if not breedData or not breedData.models or #breedData.models == 0 then
        print(('[rsg-horses] missing breed data for %s'):format(tostring(breedName)))
        return nil
    end

    local modelInfo = breedData.models[math.random(#breedData.models)]
    local data = {
        breed = breedName,
        horsename = modelInfo[1],
        horsemodel = modelInfo[2],
        horseprice = breedData.price
    }

    if usedModels then
        usedModels[data.horsemodel] = true
    end

    return data
end

local function refreshStable(stableId)
    local stableData = HorseSettings[stableId]
    if not stableData or not stableData.horsecoords then return end
    stableHorseStock[stableId] = stableHorseStock[stableId] or {}
    local usedModels = {}
    for index = 1, #stableData.horsecoords do
        stableHorseStock[stableId][index] = generateHorseForStable(stableId, usedModels)
    end
end

local function refreshAllStables()
    for stableId in pairs(HorseSettings) do
        refreshStable(stableId)
    end
    stockReady = true
end

local function ensureStableStock()
    if stockReady then return end
    refreshAllStables()
end

local function broadcastStableStock(target)
    ensureStableStock()
    TriggerClientEvent('rsg-horses:client:ReceiveStableStock', target or -1, stableHorseStock)
end

local function regenerateAndBroadcast()
    refreshAllStables()
    broadcastStableStock()
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    regenerateAndBroadcast()
end)

RegisterNetEvent('rsg-horses:server:RequestStableStock')
AddEventHandler('rsg-horses:server:RequestStableStock', function()
    local src = source
    broadcastStableStock(src)
end)

lib.callback.register('rsg-horses:server:GetStableStock', function(source)
    ensureStableStock()
    return stableHorseStock
end)

CreateThread(function()
    local refreshInterval = tonumber(Config.HorseUpdate) or 0
    if refreshInterval <= 0 then return end
    while true do
        Wait(refreshInterval)
        regenerateAndBroadcast()
    end
end)
