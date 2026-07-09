local RSGCore = exports['rsg-core']:GetCoreObject()

local activeHorseData
local activeHorseRefresh = 0
local ridingDistance = 0.0
local leadingDistance = 0.0
local lastRideCoords
local lastLeadPlayerCoords
local lastLeadHorseCoords
local localCooldowns = {}

local function TrainingConfig()
    return Config.HorseTraining or {}
end

local function MethodConfig(action)
    local training = TrainingConfig()
    return training.Methods and training.Methods[action]
end

local function DebugPrint(message)
    if TrainingConfig().Debug then
        print(('[rsg-horses:training] %s'):format(message))
    end
end

local function GetTrainingProgress(xp)
    local levels = TrainingConfig().LevelThresholds or {}
    local currentLevel = 1
    local nextLevel = nil

    for i = 1, #levels do
        if xp >= (levels[i] or 0) then
            currentLevel = i
        elseif not nextLevel then
            nextLevel = i
            break
        end
    end

    if not nextLevel then
        return currentLevel, 100
    end

    local currentXp = levels[currentLevel] or 0
    local nextXp = levels[nextLevel] or currentXp
    local neededXp = nextXp - currentXp

    if neededXp <= 0 then
        return currentLevel, 100
    end

    local progress = ((xp - currentXp) / neededXp) * 100
    return currentLevel, math.floor(math.max(0, math.min(progress, 100)))
end

local function GetTrainingStatValue(level)
    local levelConfigs = {
        Config.Level1, Config.Level2, Config.Level3, Config.Level4,
        Config.Level5, Config.Level6, Config.Level7, Config.Level8,
        Config.Level9, Config.Level10,
    }

    return levelConfigs[level] or Config.Level1
end

local function GetActiveHorseData()
    local now = GetGameTimer()
    if activeHorseData and activeHorseRefresh > now then
        return activeHorseData
    end

    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data)
        activeHorseData = data
        activeHorseRefresh = GetGameTimer() + 10000
    end)

    return activeHorseData
end

local function GetExportedHorsePed()
    local ok, horse = pcall(function()
        return exports[GetCurrentResourceName()]:CheckActiveHorse()
    end)

    if ok and horse and horse ~= 0 and DoesEntityExist(horse) then
        return horse
    end

    return 0
end

local function FindActiveHorsePed()
    local exportedHorse = GetExportedHorsePed()
    if exportedHorse ~= 0 then return exportedHorse end

    local mount = GetMount(cache.ped)
    if mount and mount ~= 0 and DoesEntityExist(mount) then
        return mount
    end

    local horseData = GetActiveHorseData()
    if not horseData or not horseData.horse then return 0 end

    local leading = MethodConfig('leading') or {}
    local searchDistance = leading.activeHorseSearchDistance or 25.0
    local playerCoords = GetEntityCoords(cache.ped)
    local horseModel = GetHashKey(horseData.horse)
    local closestHorse = 0
    local closestDistance = searchDistance + 0.01

    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= cache.ped and DoesEntityExist(ped) and GetEntityModel(ped) == horseModel then
            local distance = #(playerCoords - GetEntityCoords(ped))
            if distance < closestDistance then
                closestHorse = ped
                closestDistance = distance
            end
        end
    end

    return closestHorse
end

local function OnLocalCooldown(action, seconds)
    if seconds <= 0 then return false end

    local now = GetGameTimer()
    if localCooldowns[action] and localCooldowns[action] > now then
        return true
    end

    localCooldowns[action] = now + (seconds * 1000)
    return false
end

local function AddTrainingXp(action, amount, itemName)
    local method = MethodConfig(action)
    if not TrainingConfig().Enabled or not method or not method.enabled then return end

    local cooldown = tonumber(method.cooldown or method.serverCooldown) or 0
    if OnLocalCooldown(action, cooldown) then return end

    TriggerServerEvent('rsg-horses:server:training:addxp', action, amount, itemName)
    DebugPrint(('sent %s training amount %s'):format(action, amount or 1))
end

RegisterNetEvent('rsg-horses:client:HorseLevel', function()
    RSGCore.Functions.TriggerCallback('rsg-horses:server:GetActiveHorse', function(data)
        if not data then
            lib.notify({
                title = 'Horse Training',
                description = 'No active horse found.',
                type = 'error',
                duration = 10000,
            })
            return
        end

        local level, progress = GetTrainingProgress(tonumber(data.horsexp) or 0)

        lib.notify({
            title = ('Horse Level %s'):format(level),
            description = ('%s%% until next level'):format(progress),
            type = 'info',
            duration = 10000,
        })
    end)
end)

RegisterNetEvent('rsg-horses:client:training:applyLevelStats', function(level, xp)
    local horse = FindActiveHorsePed()
    if horse == 0 then return end

    level = tonumber(level) or 1
    xp = tonumber(xp) or 0

    local statValue = GetTrainingStatValue(level)

    SetAttributePoints(horse, 0, statValue) -- HEALTH
    SetAttributePoints(horse, 1, statValue) -- STAMINA

    if level >= 10 then
        EnableAttributeOverpower(horse, 0, 5000.0)
        EnableAttributeOverpower(horse, 1, 5000.0)
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, horse, 0, xp + 0.0)
        Citizen.InvokeNative(0xF6A7C08DF2E28B28, horse, 1, xp + 0.0)
    end

    activeHorseData = nil
    activeHorseRefresh = 0
    DebugPrint(('applied live health/stamina stats for level %s'):format(level))
end)

AddEventHandler('rsg-horses:client:playerfeedhorse', function(itemName)
    AddTrainingXp('feeding', 1, itemName)
end)

AddEventHandler('rsg-horses:client:playerbrushhorse', function(itemName)
    AddTrainingXp('brushing', 1, itemName)

    local cleaning = MethodConfig('cleaning')
    if cleaning and cleaning.awardWithBrush then
        AddTrainingXp('cleaning', 1, itemName)
    end
end)

CreateThread(function()
    while true do
        local method = MethodConfig('riding')
        local waitTime = method and method.clientTick or 2500

        if TrainingConfig().Enabled and method and method.enabled then
            local mount = GetMount(cache.ped)

            if mount and mount ~= 0 and DoesEntityExist(mount) then
                local coords = GetEntityCoords(cache.ped)

                if lastRideCoords then
                    local distance = #(coords - lastRideCoords)
                    if distance > 0.1 and distance < (method.maxMetersPerGrant or 90.0) then
                        ridingDistance = ridingDistance + distance
                    end
                end

                lastRideCoords = coords

                if ridingDistance >= (method.metersPerGrant or 40.0) then
                    AddTrainingXp('riding', ridingDistance)
                    ridingDistance = 0.0
                end
            else
                lastRideCoords = nil
                ridingDistance = 0.0
            end
        end

        Wait(waitTime)
    end
end)

CreateThread(function()
    while true do
        local method = MethodConfig('leading')
        local waitTime = method and method.clientTick or 2500

        if TrainingConfig().Enabled and method and method.enabled then
            local horse = FindActiveHorsePed()
            local mounted = GetMount(cache.ped)

            if horse ~= 0 and (not mounted or mounted == 0) then
                local playerCoords = GetEntityCoords(cache.ped)
                local horseCoords = GetEntityCoords(horse)
                local horseDistance = #(playerCoords - horseCoords)

                if horseDistance <= (method.maxHorseDistance or 4.0) then
                    if lastLeadPlayerCoords and lastLeadHorseCoords then
                        local playerMove = #(playerCoords - lastLeadPlayerCoords)
                        local horseMove = #(horseCoords - lastLeadHorseCoords)

                        if playerMove >= (method.minPlayerMove or 1.0) and horseMove > 0.25 then
                            leadingDistance = leadingDistance + math.min(playerMove, horseMove)
                        end
                    end

                    lastLeadPlayerCoords = playerCoords
                    lastLeadHorseCoords = horseCoords

                    if leadingDistance >= (method.metersPerGrant or 25.0) then
                        AddTrainingXp('leading', leadingDistance)
                        leadingDistance = 0.0
                    end
                else
                    lastLeadPlayerCoords = nil
                    lastLeadHorseCoords = nil
                    leadingDistance = 0.0
                end
            else
                lastLeadPlayerCoords = nil
                lastLeadHorseCoords = nil
                leadingDistance = 0.0
            end
        end

        Wait(waitTime)
    end
end)
