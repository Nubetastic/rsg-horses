local RSGCore = exports['rsg-core']:GetCoreObject()

local actionCooldowns = {}

local function TrainingConfig()
    return Config.HorseTraining or {}
end

local function CalculateTrainingLevel(xp)
    local levels = TrainingConfig().LevelThresholds or {}
    local level = 1

    for i = 1, #levels do
        if xp >= (levels[i] or 0) then
            level = i
        end
    end

    return level
end

local function ItemAllowed(method, itemName)
    local items = method.itemNames or {}
    if #items == 0 then return true end
    if not itemName then return false end

    itemName = itemName:lower()
    for _, allowedItem in ipairs(items) do
        if itemName == tostring(allowedItem):lower() then
            return true
        end
    end

    return false
end

local function OnCooldown(src, action, cooldown)
    if cooldown <= 0 then return false end

    local now = os.time()
    actionCooldowns[src] = actionCooldowns[src] or {}

    if actionCooldowns[src][action] and actionCooldowns[src][action] > now then
        return true
    end

    actionCooldowns[src][action] = now + cooldown
    return false
end

local function Notify(src, message, notifyType)
    if not TrainingConfig().Notify then return end

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Horse Training',
        description = message,
        type = notifyType or 'success',
        duration = 10000,
    })
end

RegisterNetEvent('rsg-horses:server:training:addxp', function(action, amount, itemName)
    local src = source
    local training = TrainingConfig()
    if not training.Enabled then return end

    local method = training.Methods and training.Methods[action]
    if not method or not method.enabled then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local xp = 0
    local cooldown = tonumber(method.cooldown or method.serverCooldown) or 0

    if action == 'leading' or action == 'riding' then
        local meters = tonumber(amount) or 0
        meters = math.max(0, math.min(meters, tonumber(method.maxMetersPerGrant) or meters))
        xp = math.floor(meters * (tonumber(method.xpPerMeter) or 0))
    else
        if not ItemAllowed(method, itemName) then return end
        xp = tonumber(method.xp) or 0
    end

    if xp <= 0 then return end
    if OnCooldown(src, action, cooldown) then return end

    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.query.await('SELECT id, horsexp FROM player_horses WHERE citizenid = ? AND active = ?', { citizenid, 1 })
    local horse = result and result[1]
    if not horse then return end

    local oldXp = tonumber(horse.horsexp) or 0
    local newXp = oldXp + xp

    MySQL.update('UPDATE player_horses SET horsexp = ? WHERE id = ? AND citizenid = ?', { newXp, horse.id, citizenid })

    local oldLevel = CalculateTrainingLevel(oldXp)
    local newLevel = CalculateTrainingLevel(newXp)

    if newLevel > oldLevel then
        Notify(src, ('Your horse reached training level %s.'):format(newLevel))
        TriggerClientEvent('rsg-horses:client:training:applyLevelStats', src, newLevel, newXp)
    end
end)

AddEventHandler('playerDropped', function()
    actionCooldowns[source] = nil
end)
