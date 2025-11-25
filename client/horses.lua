local spawnedHorses = {}
local stableHorseStock = {}
local HorseSettings = lib.load('shared.horse_settings')
lib.locale()


function SpawnHorses(horsemodel, horsecoords, heading)
    local spawnedHorse = CreatePed(horsemodel, horsecoords.x, horsecoords.y, horsecoords.z - 1.0, heading or 0.0, false, false, 0, 0)
    SetEntityAlpha(spawnedHorse, 0, false)
    SetRandomOutfitVariation(spawnedHorse, true)
    SetEntityCanBeDamaged(spawnedHorse, false)
    SetEntityInvincible(spawnedHorse, true)
    FreezeEntityPosition(spawnedHorse, true)
    SetBlockingOfNonTemporaryEvents(spawnedHorse, true)
    SetPedCanBeTargetted(spawnedHorse, false)

    if Config.FadeIn then
        for i = 0, 255, 51 do
            Wait(50)
            SetEntityAlpha(spawnedHorse, i, false)
        end
    end

    return spawnedHorse
end

local function removeHorseTarget(point)
    if point.ped and DoesEntityExist(point.ped) then
        pcall(function()
            exports.ox_target:removeEntity(point.ped, 'npc_stablehorses')
        end)
    end
end

local function deleteHorse(point)
    if point.ped and DoesEntityExist(point.ped) then
        removeHorseTarget(point)
        if Config.FadeIn then
            for i = 255, 0, -51 do
                Wait(50)
                SetEntityAlpha(point.ped, i, false)
            end
        end
        DeleteEntity(point.ped)
    end
    point.ped = nil
end

local function addHorseTarget(point)
    if not point.ped or not DoesEntityExist(point.ped) then return end
    pcall(function()
        exports.ox_target:addLocalEntity(point.ped, {
            {
                name = 'npc_stablehorses',
                icon = 'fas fa-horse-head',
                label = string.format('%s $%s', point.horsename or '', tostring(point.price or 0)),
                onSelect = function()
                    local dialog = lib.inputDialog(locale('cl_setup'), {
                        { type = 'input', label = locale('cl_setup_name'), required = true },
                        {
                            type = 'select',
                            label = locale('cl_setup_gender'),
                            options = {
                                { value = 'male',   label = locale('cl_setup_gender_a') },
                                { value = 'female', label = locale('cl_setup_gender_b') }
                            }
                        }
                    })

                    if not dialog then return end

                    local setHorseName = dialog[1]
                    local setHorseGender = dialog[2]

                    if setHorseName and setHorseGender then
                        TriggerServerEvent('rsg-horses:server:BuyHorse', point.model, point.stableid, setHorseName, setHorseGender)
                    end
                end,
                distance = 2.5,
            }
        })
    end)
end

local function spawnHorseForPoint(point)
    if not point.model or not point.spawnCoords then return end
    lib.requestModel(point.model, 10000)
    point.ped = SpawnHorses(point.model, point.spawnCoords, point.heading)
    addHorseTarget(point)
end

local function assignHorse(point, horseData)
    if not point or not horseData then return end
    point.model = horseData.horsemodel
    point.price = horseData.horseprice
    point.horsename = horseData.horsename
    point.breed = horseData.breed

    if point.inside then
        deleteHorse(point)
        spawnHorseForPoint(point)
    end
end

local function applyStableStock(stableId)
    local stablePoints = spawnedHorses[stableId]
    if not stablePoints then return end
    local stock = stableHorseStock[stableId]

    for index = 1, #stablePoints do
        local point = stablePoints[index]
        if point then
            local horseData = stock and stock[index] or nil
            if horseData then
                assignHorse(point, horseData)
            else
                point.model = nil
                point.price = nil
                point.horsename = nil
                point.breed = nil
                deleteHorse(point)
            end
        end
    end
end

local function applyAllStableStock()
    for stableId in pairs(spawnedHorses) do
        applyStableStock(stableId)
    end
end

local function requestStableStock()
    TriggerServerEvent('rsg-horses:server:RequestStableStock')
end

local function createPoint(stableId, coords, index)
    local point = lib.points.new({
        coords = vector3(coords.x, coords.y, coords.z),
        distance = Config.DistanceSpawn,
        stableid = stableId,
        stallIndex = index,
        heading = coords.w
    })

    point.spawnCoords = coords
    point.inside = false
    point.ped = nil

    point.onEnter = function(self)
        self.inside = true
        if self.model and not self.ped then
            spawnHorseForPoint(self)
        end
    end

    point.onExit = function(self)
        self.inside = false
        deleteHorse(self)
    end

    return point
end

RegisterNetEvent('rsg-horses:client:ReceiveStableStock', function(stock)
    if type(stock) ~= 'table' then return end
    stableHorseStock = stock
    applyAllStableStock()
end)

CreateThread(function()
    for stableId, stableData in pairs(HorseSettings) do
        spawnedHorses[stableId] = spawnedHorses[stableId] or {}
        for index, coords in ipairs(stableData.horsecoords) do
            spawnedHorses[stableId][index] = createPoint(stableId, coords, index)
        end
    end

    applyAllStableStock()
    requestStableStock()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, stablePoints in pairs(spawnedHorses) do
        for _, point in pairs(stablePoints) do
            removeHorseTarget(point)
            deleteHorse(point)
        end
    end
end)
