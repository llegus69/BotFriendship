-- ============================================================
-- BotFriendship_Rewards.lua  |  Script de SERVIDOR (lua_scripts)
-- Compatible con AzerothCore + Eluna (WotLK 3.3.5)
-- ============================================================
--
-- ╔══════════════════════════════════════════════════════════╗
-- ║            ZONA DE CONFIGURACIÓN DE RECOMPENSAS          ║
-- ║  Todo lo que necesitas editar está en este bloque.       ║
-- ║  No toques nada fuera de esta zona salvo que sepas       ║
-- ║  lo que haces.                                           ║
-- ╚══════════════════════════════════════════════════════════╝
--
-- CÓMO AÑADIR ITEMS:
--   { entry = ID_DEL_ITEM, count = CANTIDAD }
--   Puedes añadir tantas líneas como quieras dentro de items = { }
--   Busca los IDs en: https://www.wowhead.com/wotlk
--
-- CÓMO PONER ORO:
--   gold = X * 10000   →  X = cantidad en oro
--   Ejemplos:  5 * 10000 = 5 oro  |  100 * 10000 = 100 oro
--   gold = 0  si no quieres dar oro
--
-- CÓMO CAMBIAR EL ASUNTO Y CUERPO DEL CORREO:
--   subject = "Texto del asunto"
--   body    = "Texto del cuerpo"
--
-- ════════════════════════════════════════════════════════════
-- RECOMPENSAS DE RANGO NORMAL
-- Se entregan UNA SOLA VEZ por personaje al alcanzar cada rango.
-- Rango 2 = Neutral      | Rango 3 = Compañero
-- Rango 4 = Fiel         | Rango 5 = Hermano de Armas
-- ════════════════════════════════════════════════════════════
local REWARD_RANK = {

    -- ----------------------------------------------------------
    -- RANGO 2: NEUTRAL  (1001 - 3000 puntos)
    -- ----------------------------------------------------------
    [2] = {
        gold    = 5 * 10000,        -- 5 oro
        items   = {
            { entry = 34009, count = 1 },   -- << CAMBIA ESTE ID
        },
        subject = "Nuevo Rango: Neutral",
        body    = "Tu companiero te reconoce como alguien de confianza.",
    },

    -- ----------------------------------------------------------
    -- RANGO 3: COMPAÑERO  (3001 - 6000 puntos)
    -- ----------------------------------------------------------
    [3] = {
        gold    = 15 * 10000,       -- 15 oro
        items   = {
            { entry = 34009, count = 1 },   -- << CAMBIA ESTE ID
            { entry = 34010, count = 1 },   -- << puedes añadir más líneas
        },
        subject = "Nuevo Rango: Companiero",
        body    = "La amistad forjada en batalla vale mas que el oro.",
    },

    -- ----------------------------------------------------------
    -- RANGO 4: FIEL  (6001 - 9999 puntos)
    -- ----------------------------------------------------------
    [4] = {
        gold    = 40 * 10000,       -- 40 oro
        items   = {
            { entry = 34010, count = 1 },   -- << CAMBIA ESTE ID
            { entry = 34011, count = 1 },   -- << puedes añadir más líneas
        },
        subject = "Nuevo Rango: Fiel",
        body    = "Tu companiero te es completamente fiel.",
    },

    -- ----------------------------------------------------------
    -- RANGO 5: HERMANO DE ARMAS  (10000+ puntos, primer ciclo)
    -- ----------------------------------------------------------
    [5] = {
        gold    = 100 * 10000,      -- 100 oro
        items   = {
            { entry = 34012, count = 1 },   -- << CAMBIA ESTE ID
        },
        subject = "Rango Maximo: Hermano de Armas",
        body    = "Has alcanzado el vinculo mas profundo. Que comience el Paragon.",
    },
}

-- ════════════════════════════════════════════════════════════
-- RECOMPENSAS PARAGON
-- Se entregan CADA VEZ que completas un ciclo 0 → 10000.
-- paragonLevel es el nivel alcanzado: 1 = +1, 2 = +2, etc.
--
-- Tienes dos opciones:
--
--   OPCIÓN A — Misma recompensa en todos los ciclos:
--     Edita solo el bloque DEFAULT aquí abajo y deja
--     PARAGON_LEVELS vacío ( {} ).
--
--   OPCIÓN B — Recompensa diferente por nivel concreto:
--     Añade una entrada [N] en PARAGON_LEVELS.
--     Si el nivel no tiene entrada propia, usa DEFAULT.
-- ════════════════════════════════════════════════════════════
local PARAGON_DEFAULT = {
    gold    = 100 * 10000,          -- 100 oro base (se multiplica x nivel abajo)
    items   = {
        { entry = 34012, count = 1 },   -- << item épico por ciclo (cámbialo)
    },
    subject = "Paragon completado!",
    body    = "Tu dedicacion no tiene limites. Tu companiero te admira.",
}

local PARAGON_LEVELS = {
    -- Ejemplo: nivel +3 da una recompensa especial
    -- [3] = {
    --     gold    = 500 * 10000,
    --     items   = { { entry = 40753, count = 1 } },
    --     subject = "Paragon +3: Recompensa Especial!",
    --     body    = "Has alcanzado el tercer ciclo Paragon. Extraordinario.",
    -- },
}

-- ════════════════════════════════════════════════════════════
-- FIN DE LA ZONA DE CONFIGURACIÓN — no edites más abajo
-- ════════════════════════════════════════════════════════════

local rewardsSent = {}

local function hasRankReward(guid, rankId)
    return rewardsSent[guid] and rewardsSent[guid][rankId]
end

local function markRankReward(guid, rankId)
    if not rewardsSent[guid] then rewardsSent[guid] = {} end
    rewardsSent[guid][rankId] = true
end

local function SendRewardMail(player, subject, body, gold, botName)
    local fullBody = string.format("[Bot: %s] %s", botName or "?", body)
    local ok, err = pcall(function()
        SendMail(subject, fullBody, player:GetGUIDLow(), gold or 0, 0, 0, 61)
    end)
    if not ok then
        print("[BotFriendship] SendMail fallo: " .. tostring(err))
    end
end

local function GiveRankReward(player, rankId, botName)
    local reward = REWARD_RANK[rankId]
    if not reward then return end

    local guid = player:GetGUIDLow()
    if hasRankReward(guid, rankId) then return end
    markRankReward(guid, rankId)

    SendRewardMail(player, reward.subject, reward.body, reward.gold, botName)
    print(string.format("[BotFriendship] Rango %d -> %s (bot: %s)",
        rankId, player:GetName(), botName or "?"))
end

local function GiveParagonReward(player, paragonLevel, botName)
    -- Usar recompensa específica del nivel si existe, si no la DEFAULT
    local reward = PARAGON_LEVELS[paragonLevel] or PARAGON_DEFAULT
    -- El oro escala con el nivel usando la base de DEFAULT salvo que el nivel tenga la suya propia
    local gold = reward.gold
    if not PARAGON_LEVELS[paragonLevel] then
        gold = PARAGON_DEFAULT.gold * paragonLevel
    end
    local subject = string.format("[+%d] %s", paragonLevel, reward.subject)
    SendRewardMail(player, subject, reward.body, gold, botName)
    print(string.format("[BotFriendship] Paragon +%d -> %s (bot: %s)",
        paragonLevel, player:GetName(), botName or "?"))
end

local function GetRankId(puntos)
    if     puntos >= 10000 then return 5
    elseif puntos >= 6001  then return 4
    elseif puntos >= 3001  then return 3
    elseif puntos >= 1001  then return 2
    else                        return 1
    end
end

RegisterPlayerEvent(42, function(event, player, command)
    if not command then return end
    local payload = command:match("^bfrank%s+(.+)$")
    if not payload then return end

    local parBotName, parLevelStr = payload:match("^PAR:(.+):(%d+)$")
    if parBotName then
        GiveParagonReward(player, tonumber(parLevelStr) or 1, parBotName)
        return false
    end

    local botName, puntosStr, rangoAnteriorStr = payload:match("^(.+):(%d+):(%d+)$")
    if not botName then return false end

    local puntos        = tonumber(puntosStr) or 0
    local rangoAnterior = tonumber(rangoAnteriorStr) or 1
    local rangoActual   = GetRankId(puntos)

    if rangoActual > rangoAnterior and rangoActual >= 2 then
        GiveRankReward(player, rangoActual, botName)
    end

    return false
end)

print("[BotFriendship_Rewards] Cargado correctamente.")