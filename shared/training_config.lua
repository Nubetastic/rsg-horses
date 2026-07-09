Config.HorseTraining = {
    Enabled = true,
    Notify = true,
    Debug = false,
    SellPricePerLevel = .25, -- 25% of default price added per level, so a level 10 horse sells for 2.5x the default price.
    -- Minimum total XP required for each training level.
    LevelThresholds = {
        [1] = 0,
        [2] = 100,
        [3] = 200,
        [4] = 300,
        [5] = 400,
        [6] = 500,
        [7] = 1000,
        [8] = 2000,
        [9] = 3000,
        [10] = 4000,
    },

    Methods = {
        leading = {
            enabled = true,
            xpPerMeter = 0.1,
            metersPerGrant = 25.0,
            clientTick = 2000,
            serverCooldown = 5,
            maxMetersPerGrant = 60.0,
            maxHorseDistance = 4.0,
            activeHorseSearchDistance = 25.0,
            minPlayerMove = 1.0,
        },

        riding = {
            enabled = true,
            xpPerMeter = 0.05,
            metersPerGrant = 40.0,
            clientTick = 2000,
            serverCooldown = 5,
            maxMetersPerGrant = 90.0,
        },

        brushing = {
            enabled = true,
            xp = .5,
            cooldown = 300,
            -- Leave empty to allow any item that triggers the base brush event.
            itemNames = { 'horsebrush' },
        },

        feeding = {
            enabled = true,
            xp = .3,
            cooldown = 120,
            -- Leave empty to allow any item that triggers the base feed event.
            itemNames = {},
        },

        cleaning = {
            enabled = true,
            xp = .4,
            cooldown = 300,
            -- The base script cleans the horse during brushing, so this can
            -- award separate cleaning XP without editing the original handler.
            awardWithBrush = true,
            itemNames = { 'horsebrush' },
        },
    },
}

-- Override the base stat values without editing shared/config.lua.
-- Level 1 starts at 25% of the reachable max, levels 2-9 add 7% each,
-- and level 10 reaches 100%.
Config.Level1 = 500
Config.Level2 = 640
Config.Level3 = 780
Config.Level4 = 920
Config.Level5 = 1060
Config.Level6 = 1200
Config.Level7 = 1340
Config.Level8 = 1480
Config.Level9 = 1620
Config.Level10 = 2000
