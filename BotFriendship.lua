-- ============================================================
-- BotFriendship - Sistema de Afinidad Independiente (Separado)
-- Compatible con WotLK 3.3.5
-- ============================================================

local BF_EventFrame = CreateFrame("Frame", "BotFriendshipMain", UIParent)
BF_EventFrame:RegisterEvent("ADDON_LOADED")
BF_EventFrame:RegisterEvent("QUEST_FINISHED")
BF_EventFrame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
BF_EventFrame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
BF_EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
BF_EventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")

local PUNTOS_MISION = 50
local PUNTOS_KILL_NORMAL = 2       
local PUNTOS_KILL_ELITE = 10       
local PUNTOS_KILL_BOSS = 20        

local PENALIZACION_SIN_GRUPO = -30
local PENALIZACION_MUERTE_BOT = -100
local PENALIZACION_DESHONOR = -2000

-- Sistema de bloqueo
local BLOQUEO_DURACION = 30  -- 30 segundos para pruebas (cambiar a 15 * 60 en producción)

local function BF_FormatTiempo(segundos)
    local m = math.floor(segundos / 60)
    local s = segundos % 60
    return string.format("%d:%02d", m, s)
end

local BF_Idiomas = {
    ES = {
        TITLE = "Diario de Compañeros",
        RANK = "Rango",
        LANG_BTN = "Idioma: ES",
        USED_WARNING = "se siente usado por no estar en tu grupo. Fidelidad reducida:",
        DIED_WARNING = "ha muerto en combate! Su fidelidad disminuye.",
        CIVIL_WARNING = "¡Has atacado a la población civil! %s aborrece tus actos deshonrosos. Fidelidad drásticamente reducida:",
        DISMISS_MSG    = "¡La fidelidad de %s ha llegado a 0! Se niega a seguir sirviéndote y se marcha.",
        ABANDON_MSG    = "¡%s te ha abandonado porque su fidelidad llegó a 0!",
        BLOCKED_MSG    = "¡%s está bloqueado! Podrá volver en %d min.",
        UNBLOCKED_MSG  = "%s ha vuelto tras su ausencia. Fidelidad restaurada.",
        BLOCKED_LABEL  = "EN CASTIGO",
        BLOCKED_TIMER  = "Vuelve en: %s",
        R = {"Desconfiado", "Neutral", "Compañero", "Fiel", "Hermano de Armas"},
        RESET_BOT_CONFIRM  = "¿Seguro que quieres reiniciar amistad?",
        JOURNAL_EMPTY      = "No dispones de registros de Compañeros, para hacerlo debes completar alguna misión o matar alguna criatura que dé experiencia u honor.",
        JOURNAL_HELP_BTN   = "Ayuda",
        JOURNAL_HELP_TITLE = "¿Cómo funciona el Diario?",
        JOURNAL_HELP_TEXT  = "El Diario de Companeros registra tu afinidad con cada NPC Bot.\n\nGana puntos completando misiones o matando criaturas que den experiencia u honor mientras tu Bot esta en el grupo.\n\nAl alcanzar ciertos rangos recibiras recompensas por correo. Si llegas al rango maximo (Hermano de Armas) se activa el modo Paragon, que reinicia el contador y anade un indicador +N a tu rango.",
        JOURNAL_HELP_OK    = "Entendido",
    },
    EN = {
        TITLE = "Companion Journal",
        RANK = "Rank",
        LANG_BTN = "Language: EN",
        USED_WARNING = "feels used for not being in your party. Friendship reduced:",
        DIED_WARNING = "has died in combat! Friendship decreases.",
        CIVIL_WARNING = "You have attacked civilians! %s abhors your dishonorable actions. Friendship drastically reduced:",
        DISMISS_MSG    = "Friendship with %s has reached 0! They refuse to serve you and leave.",
        ABANDON_MSG    = "%s has abandoned you because their friendship reached 0!",
        BLOCKED_MSG    = "%s is blocked! They can return in %d min.",
        UNBLOCKED_MSG  = "%s has returned after their absence. Friendship restored.",
        BLOCKED_LABEL  = "IN TIMEOUT",
        BLOCKED_TIMER  = "Returns in: %s",
        R = {"Distrustful", "Neutral", "Companion", "Faithful", "Brother in Arms"},
        RESET_BOT_CONFIRM  = "Are you sure you want to reset friendship?",
        JOURNAL_EMPTY      = "You have no Companion records. To create them, complete a quest or kill a creature that grants experience or honor.",
        JOURNAL_HELP_BTN   = "Help",
        JOURNAL_HELP_TITLE = "How does the Journal work?",
        JOURNAL_HELP_TEXT  = "The Companion Journal tracks your affinity with each NPC Bot.\n\nEarn points by completing quests or killing creatures that grant experience or honor while your Bot is in the group.\n\nReaching certain ranks rewards you with in-game mail. Once you hit the max rank (Brother in Arms), Paragon mode activates, resetting the counter and adding a +N indicator to your rank.",
        JOURNAL_HELP_OK    = "Got it",
    }
}

local function BF_L(key)
    local lang = (BotFriendshipDB and BotFriendshipDB.Idioma) or "ES"
    return BF_Idiomas[lang][key] or key
end

local function GetRankInfo(pts, paragon)
    local p = paragon or 0
    local suffix = p > 0 and (" +" .. p) or ""
    if p > 0 then
        return BF_L("R")[5] .. suffix, 5, 1, 0.84, 0
    end
    if pts >= 10000 then return BF_L("R")[5], 5, 1, 0.84, 0
    elseif pts >= 6001 then return BF_L("R")[4], 4, 0, 0.6, 1
    elseif pts >= 3001 then return BF_L("R")[3], 3, 0, 1, 0
    elseif pts >= 1001 then return BF_L("R")[2], 2, 1, 1, 0
    else return BF_L("R")[1], 1, 1, 0, 0
    end
end

-- Mapeo escalonado: rango de amistad (1-5) -> número de insignia de
-- rango de Honor de Blizzard (1-14). 1 y 2 se mantienen tal cual
-- (Desconfiado=Soldado, Neutral=Bruto/Grunt); a partir de ahí se va
-- escalando hasta llegar a la insignia 14 (General/Warlord) en el
-- rango máximo "Hermano de Armas".
local BF_RankBadgeNum = { 1, 2, 6, 10, 14 }

local function BF_GetBadgeTextureForRank(rango)
    local badgeNum = BF_RankBadgeNum[rango] or 1
    return string.format("Interface\\PvPRankBadges\\PvPRank%02d", badgeNum)
end

local function BF_CheckDB()
    if not BotFriendshipDB then BotFriendshipDB = { Idioma = "ES", Bots = {} } end
    if not BotFriendshipDB.Bots then BotFriendshipDB.Bots = {} end
end

local BF_Journal = CreateFrame("Frame", "BotFriendshipJournal", UIParent)
BF_Journal:SetSize(380, 500)
BF_Journal:SetPoint("CENTER")
BF_Journal:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
BF_Journal:SetMovable(true)
BF_Journal:EnableMouse(true)
BF_Journal:RegisterForDrag("LeftButton")
BF_Journal:SetScript("OnDragStart", BF_Journal.StartMoving)
BF_Journal:SetScript("OnDragStop", BF_Journal.StopMovingOrSizing)
BF_Journal:Hide()

local BF_Title = BF_Journal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
BF_Title:SetPoint("TOP", 0, -15)

local BF_ScrollFrame = CreateFrame("ScrollFrame", "BotFriendshipScrollFrame", BF_Journal, "UIPanelScrollFrameTemplate")
BF_ScrollFrame:SetPoint("TOPLEFT", 15, -45)
BF_ScrollFrame:SetPoint("BOTTOMRIGHT", -35, 55)

local BF_EmptyLabel = BF_Journal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
BF_EmptyLabel:SetPoint("CENTER", BF_Journal, "CENTER", 0, -20)
BF_EmptyLabel:SetWidth(320)
BF_EmptyLabel:SetJustifyH("CENTER")
BF_EmptyLabel:SetTextColor(0.6, 0.6, 0.6)
BF_EmptyLabel:SetText("")
BF_EmptyLabel:Hide()

local BF_ListContainer = CreateFrame("Frame", nil, BF_ScrollFrame)
BF_ListContainer:SetSize(320, 1)
BF_ScrollFrame:SetScrollChild(BF_ListContainer)

local BF_BotRows = {}

local function BF_CreateBotRow(index)
    local row = CreateFrame("Frame", nil, BF_ListContainer)
    row:SetSize(320, 65)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * 72))
    
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetTexture(1, 1, 1, 0.05)
    
    local portrait = row:CreateTexture(nil, "ARTROW")
    portrait:SetSize(45, 45)
    portrait:SetPoint("LEFT", 8, 0)
    portrait:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait")
    row.portrait = portrait

    local classIcon = row:CreateTexture(nil, "ARTROW")
    classIcon:SetSize(18, 18)
    classIcon:SetPoint("TOPLEFT", portrait, "TOPRIGHT", 10, 2)
    row.classIcon = classIcon

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", classIcon, "RIGHT", 5, 0)
    row.nameText = nameText

    local pvpIcon = row:CreateTexture(nil, "OVERLAY")
    pvpIcon:SetSize(14, 14)
    pvpIcon:SetPoint("LEFT", nameText, "RIGHT", 4, 0)
    pvpIcon:SetTexture(BF_GetBadgeTextureForRank(1))
    row.pvpIcon = pvpIcon

    local rankText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rankText:SetPoint("TOPLEFT", classIcon, "BOTTOMLEFT", 0, -2)
    row.rankText = rankText

    local miniBar = CreateFrame("StatusBar", nil, row)
    miniBar:SetSize(160, 10)
    miniBar:SetPoint("BOTTOMLEFT", portrait, "BOTTOMRIGHT", 10, 2)
    miniBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    miniBar:SetMinMaxValues(0, 10000)
    
    local miniBG = miniBar:CreateTexture(nil, "BACKGROUND")
    miniBG:SetAllPoints(true)
    miniBG:SetTexture(0, 0, 0, 0.4)
    row.miniBar = miniBar

    local resetBtn = CreateFrame("Button", nil, row, "UIPanelCloseButton")
    resetBtn:SetSize(20, 20)
    resetBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
    resetBtn:SetScript("OnClick", function()
        local bName = row.nameText:GetText()
        if bName and bName ~= "" then
            local lang = (BotFriendshipDB and BotFriendshipDB.Idioma) or "ES"
            StaticPopupDialogs["NBI_RESET_BOT_JOURNAL_CONFIRM"].text = BF_Idiomas[lang]["RESET_BOT_CONFIRM"] or "¿Seguro que quieres reiniciar amistad?"
            local dialog = StaticPopup_Show("NBI_RESET_BOT_JOURNAL_CONFIRM")
            if dialog then dialog.data = bName end
        end
    end)
    resetBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local lang = (BotFriendshipDB and BotFriendshipDB.Idioma) or "ES"
        GameTooltip:AddLine(BF_Idiomas[lang]["RESET_BOT_CONFIRM"] or "¿Seguro que quieres reiniciar amistad?", 1, 0.2, 0.2, true)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.resetBtn = resetBtn

    return row
end

local function BF_RefreshJournalList()
    if not BotFriendshipDB or not BotFriendshipDB.Bots then
        BF_EmptyLabel:SetText(BF_L("JOURNAL_EMPTY"))
        BF_EmptyLabel:Show()
        return
    end

    -- Ocultar todas las filas existentes
    for _, row in pairs(BF_BotRows) do row:Hide() end

    local total = 0
    for _ in pairs(BotFriendshipDB.Bots) do total = total + 1 end
    if total == 0 then
        BF_EmptyLabel:SetText(BF_L("JOURNAL_EMPTY"))
        BF_EmptyLabel:Show()
        return
    end
    BF_EmptyLabel:Hide()

    local index = 0
    for name, data in pairs(BotFriendshipDB.Bots) do
        index = index + 1
        -- Indexar por nombre para que cada bot siempre use su propia fila
        if not BF_BotRows[name] then
            BF_BotRows[name] = BF_CreateBotRow(index)
        end
        local row = BF_BotRows[name]
        -- Reposicionar por si el orden cambió
        row:SetPoint("TOPLEFT", 0, -((index - 1) * 72))
        row.nameText:SetText(name)

        local p = data.paragon or 0
        local rankName, rango, r, g, b = GetRankInfo(data.puntos, p)
        local ptsDisplay = p > 0 and (data.puntos .. "/10000 pts") or (data.puntos .. " pts")
        row.pvpIcon:SetTexture(BF_GetBadgeTextureForRank(rango))

        if data.bloqueado then
            local ahora = time()
            local restante = math.max(0, BLOQUEO_DURACION - (ahora - (data.bloqueadoEn or ahora)))
            row.rankText:SetText("|cffff2020" .. BF_L("BLOCKED_LABEL") .. "|r  " .. string.format(BF_L("BLOCKED_TIMER"), BF_FormatTiempo(restante)))
            row.miniBar:SetValue(0)
            row.miniBar:SetStatusBarColor(0.6, 0, 0)
        else
            row.rankText:SetText(rankName .. " (" .. ptsDisplay .. ")")
            row.miniBar:SetValue(data.puntos)
            row.miniBar:SetStatusBarColor(r, g, b)
        end
        
        local asignado = false
        local numMiembros = GetNumPartyMembers()
        if numMiembros > 0 then
            for i = 1, numMiembros do
                local partyName = GetPartyMember(i) and UnitName("party"..i)
                if partyName == name then
                    local _, classToken = UnitClass("party"..i)
                    if classToken then
                        row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
                        local coords = CLASS_BUTTONS[classToken]
                        if coords then row.classIcon:SetTexCoord(unpack(coords)) end
                    end
                    SetPortraitTexture(row.portrait, "party"..i)
                    data.clase = classToken
                    asignado = true
                    break
                end
            end
        end
        
        if not asignado then
            if data.clase then
                row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
                local coords = CLASS_BUTTONS[data.clase]
                if coords then row.classIcon:SetTexCoord(unpack(coords)) end
            else
                row.classIcon:SetTexture(nil)
            end
            row.portrait:SetTexture("Interface\\CharacterFrame\\TemporaryPortrait")
        end
        row:Show()
    end
end

-- ============================================================
-- ICONO DE RANGO (insignia de Honor) junto al nombre del bot
-- Aparece en: fila del Diario (ya añadido arriba), Party Frame
-- y nameplate del bot en el mundo. La insignia mostrada depende
-- del rango de amistad actual del bot (ver BF_RankBadgeNum más
-- arriba). Es solo un indicador visual del propio sistema de
-- afinidad, no del estado real de PvP del personaje.
-- ============================================================

-- --- Party Frame (PartyMemberFrame1-4) ---
local BF_PartyPvPIcons = {}
for i = 1, 4 do
    local pf = _G["PartyMemberFrame" .. i]
    if pf then
        local nameFS = _G["PartyMemberFrame" .. i .. "Name"]
        local icon = pf:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14)
        icon:SetTexture(BF_GetBadgeTextureForRank(1))
        if nameFS then
            icon:SetPoint("LEFT", nameFS, "RIGHT", 2, 0)
        else
            icon:SetPoint("TOPRIGHT", pf, "TOPRIGHT", -4, -4)
        end
        icon:Hide()
        BF_PartyPvPIcons[i] = icon
    end
end

local function BF_UpdatePartyPvPIcons()
    for i = 1, 4 do
        local icon = BF_PartyPvPIcons[i]
        if icon then
            local memberName = GetPartyMember(i) and UnitName("party" .. i)
            local data = memberName and BotFriendshipDB and BotFriendshipDB.Bots and BotFriendshipDB.Bots[memberName]
            if data then
                local _, rango = GetRankInfo(data.puntos, data.paragon or 0)
                icon:SetTexture(BF_GetBadgeTextureForRank(rango))
                icon:Show()
            else
                icon:Hide()
            end
        end
    end
end

-- --- Nameplates (placa de nombre sobre la cabeza del bot) ---
-- AVISO: WotLK 3.3.5 no tiene una API oficial para vincular una
-- nameplate con una unidad concreta. Esta detección se basa en la
-- estructura por defecto de Blizzard (Frame sin nombre global +
-- StatusBar de vida como primer hijo + FontString con el texto del
-- nombre). Si usas otro addon de nameplates (TidyPlates, Aloft,
-- KuiNameplates, etc.) que reemplace esa estructura, el icono puede
-- no aparecer y habría que adaptar la detección a ese addon.
-- Solo se muestra cuando el propio juego está mostrando el nombre
-- sobre la placa (por ejemplo, con "Mostrar siempre nombres" activado,
-- al objetivo, o al pasar el ratón).
local BF_NamePlatePvPIcons = setmetatable({}, { __mode = "k" })

local function BF_IsDefaultNamePlate(frame)
    if frame:GetObjectType() ~= "Frame" or frame:GetName() then return false end
    local child = select(1, frame:GetChildren())
    return child ~= nil and child:GetObjectType() == "StatusBar"
end

local function BF_GetNamePlateNameRegion(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            local text = region:GetText()
            if text and text ~= "" then return region, text end
        end
    end
end

local function BF_ScanNamePlatesForPvPIcon()
    if not BotFriendshipDB or not BotFriendshipDB.Bots then return end
    for _, frame in ipairs({ WorldFrame:GetChildren() }) do
        if frame:IsVisible() and BF_IsDefaultNamePlate(frame) then
            local nameRegion, text = BF_GetNamePlateNameRegion(frame)
            local data = text and BotFriendshipDB.Bots[text]
            if nameRegion and data then
                local icon = BF_NamePlatePvPIcons[frame]
                if not icon then
                    icon = frame:CreateTexture(nil, "OVERLAY")
                    icon:SetSize(12, 12)
                    BF_NamePlatePvPIcons[frame] = icon
                end
                local _, rango = GetRankInfo(data.puntos, data.paragon or 0)
                icon:SetTexture(BF_GetBadgeTextureForRank(rango))
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", nameRegion, "RIGHT", 2, 0)
                icon:Show()
            elseif BF_NamePlatePvPIcons[frame] then
                BF_NamePlatePvPIcons[frame]:Hide()
            end
        elseif BF_NamePlatePvPIcons[frame] then
            BF_NamePlatePvPIcons[frame]:Hide()
        end
    end
end

local BF_NamePlateScanner = CreateFrame("Frame")
local BF_NPScanElapsed = 0
BF_NamePlateScanner:SetScript("OnUpdate", function(self, elapsed)
    BF_NPScanElapsed = BF_NPScanElapsed + elapsed
    if BF_NPScanElapsed >= 0.2 then
        BF_NPScanElapsed = 0
        BF_ScanNamePlatesForPvPIcon()
    end
end)

local BF_HelpWin = CreateFrame("Frame", nil, BF_Journal)
BF_HelpWin:SetSize(360, 320)
BF_HelpWin:SetPoint("CENTER", BF_Journal, "CENTER", 0, 0)
BF_HelpWin:SetFrameLevel(BF_Journal:GetFrameLevel() + 10)
BF_HelpWin:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
BF_HelpWin:Hide()

local BF_HelpWinTitle = BF_HelpWin:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
BF_HelpWinTitle:SetPoint("TOP", BF_HelpWin, "TOP", 0, -15)
BF_HelpWinTitle:SetTextColor(1, 0.82, 0, 1)
BF_HelpWinTitle:SetText(BF_L("JOURNAL_HELP_TITLE"))

local BF_HelpWinText = BF_HelpWin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
BF_HelpWinText:SetPoint("TOPLEFT",     BF_HelpWin, "TOPLEFT",     20, -45)
BF_HelpWinText:SetPoint("BOTTOMRIGHT", BF_HelpWin, "BOTTOMRIGHT", -20, 50)
BF_HelpWinText:SetJustifyH("LEFT")
BF_HelpWinText:SetJustifyV("TOP")
BF_HelpWinText:SetTextColor(1, 1, 1, 1)
BF_HelpWinText:SetText(BF_L("JOURNAL_HELP_TEXT"))

local BF_HelpWinClose = CreateFrame("Button", nil, BF_HelpWin, "UIPanelButtonTemplate")
BF_HelpWinClose:SetSize(100, 26)
BF_HelpWinClose:SetPoint("BOTTOM", BF_HelpWin, "BOTTOM", 0, 12)
BF_HelpWinClose:SetText(BF_L("JOURNAL_HELP_OK"))
BF_HelpWinClose:SetScript("OnClick", function() BF_HelpWin:Hide() end)

local BF_HelpBtn = CreateFrame("Button", nil, BF_Journal, "UIPanelButtonTemplate")
BF_HelpBtn:SetSize(80, 25)
BF_HelpBtn:SetPoint("BOTTOMRIGHT", BF_Journal, "BOTTOMRIGHT", -15, 15)
BF_HelpBtn:SetText(BF_L("JOURNAL_HELP_BTN"))
BF_HelpBtn:SetScript("OnClick", function()
    if BF_HelpWin:IsShown() then BF_HelpWin:Hide() else BF_HelpWin:Show() end
end)

local BF_LangBtn = CreateFrame("Button", nil, BF_Journal, "UIPanelButtonTemplate")
BF_LangBtn:SetSize(100, 25)
BF_LangBtn:SetPoint("BOTTOMLEFT", 15, 15)
BF_LangBtn:SetScript("OnClick", function()
    BotFriendshipDB.Idioma = (BotFriendshipDB.Idioma == "ES") and "EN" or "ES"
    BF_LangBtn:SetText(BF_L("LANG_BTN"))
    BF_Title:SetText(BF_L("TITLE"))
    BF_HelpBtn:SetText(BF_L("JOURNAL_HELP_BTN"))
    BF_HelpWinTitle:SetText(BF_L("JOURNAL_HELP_TITLE"))
    BF_HelpWinText:SetText(BF_L("JOURNAL_HELP_TEXT"))
    BF_HelpWinClose:SetText(BF_L("JOURNAL_HELP_OK"))
    BF_EmptyLabel:SetText(BF_L("JOURNAL_EMPTY"))
    BF_RefreshJournalList()
end)

local BF_CloseBtn = CreateFrame("Button", nil, BF_Journal, "UIPanelCloseButton")
BF_CloseBtn:SetPoint("TOPRIGHT", -5, -5)
BF_CloseBtn:SetScript("OnClick", function() BF_Journal:Hide() end)

-- Forward declaration: se define aquí para que BF_ModificarPuntos pueda llamarla
-- La implementación completa viene justo después de BF_ModificarPuntos
local BF_CheckDesbloqueos

local function BF_ModificarPuntos(name, cantidad)
    BF_CheckDB()
    if not BotFriendshipDB.Bots[name] then BotFriendshipDB.Bots[name] = { puntos = 0, paragon = 0 } end
    if not BotFriendshipDB.Bots[name].paragon then BotFriendshipDB.Bots[name].paragon = 0 end

    -- Si el bot está bloqueado, ignorar cualquier modificación de puntos
    if BotFriendshipDB.Bots[name].bloqueado then return end

    local data        = BotFriendshipDB.Bots[name]
    local puntosAntes = data.puntos
    local paragonAntes = data.paragon
    local _, rangoAntes = GetRankInfo(puntosAntes, paragonAntes)

    local nuevosPuntos = puntosAntes + cantidad
    if nuevosPuntos <= 0 then
        -- Guardar el estado de bloqueo: puntos que tenía, timestamp y flag
        local puntosGuardados = 1  -- siempre vuelve con 1 punto al salir del castigo
        BotFriendshipDB.Bots[name] = {
            puntos        = 0,
            paragon       = paragonAntes,
            clase         = data.clase,
            bloqueado     = true,
            bloqueadoEn   = time(),
            puntosGuardados = puntosGuardados,
        }
        print("|cffff0000BotFriendship:|r " .. string.format(BF_L("BLOCKED_MSG"), name, 15))
        SendChatMessage(".npcbot hide", "SAY")
        -- Programar el check de desbloqueo por si el ticker aún no corrió
        C_Timer.After(1, function() BF_CheckDesbloqueos() end)
    else
        local nuevoParagon = paragonAntes
        if nuevosPuntos >= 10000 then
            nuevoParagon   = paragonAntes + 1
            nuevosPuntos   = nuevosPuntos - 10000
            data.paragon   = nuevoParagon
            data.puntos    = nuevosPuntos

            local rankName = GetRankInfo(nuevosPuntos, nuevoParagon)
            print(string.format("|cffFF8C00[Paragon]|r |cffFFD700%s|r ha alcanzado |cffFF6600Hermano de Armas +%d|r! Revisa tu correo.", name, nuevoParagon))
            SendChatMessage(string.format(".bfrank PAR:%s:%d", name, nuevoParagon), "SAY")
        else
            data.puntos = nuevosPuntos
            if nuevoParagon == 0 then
                local rankName, rangoNuevo = GetRankInfo(nuevosPuntos, 0)
                if rangoNuevo > rangoAntes and rangoNuevo >= 2 then
                    SendChatMessage(string.format(".bfrank %s:%d:%d", name, nuevosPuntos, rangoAntes), "SAY")
                    print(string.format("|cff00ff00[Afinidad]|r |cffFFD700%s|r alcanzo el rango |cff00ccff%s|r! Revisa tu correo.", name, rankName))
                end
            end
        end
    end
    
    if BotFriendshipDB.Bots[name] and not BotFriendshipDB.Bots[name].bloqueado then
        if UnitName("target") == name then
            local _, classToken = UnitClass("target")
            if classToken then BotFriendshipDB.Bots[name].clase = classToken end
        end
    end
    
    if BF_Journal:IsShown() then BF_RefreshJournalList() end
    return nuevosPuntos
end

-- Implementación de BF_CheckDesbloqueos (declarada arriba como forward declaration)
BF_CheckDesbloqueos = function()
    if not BotFriendshipDB or not BotFriendshipDB.Bots then return end
    local ahora = time()

    -- Recoger primero los bots a desbloquear para no modificar la tabla mientras iteramos
    local aDesbloquear = {}
    for name, data in pairs(BotFriendshipDB.Bots) do
        if data.bloqueado then
            local transcurrido = ahora - (data.bloqueadoEn or ahora)
            if transcurrido >= BLOQUEO_DURACION then
                aDesbloquear[name] = {
                    puntos  = data.puntosGuardados or 1,
                    paragon = data.paragon or 0,
                    clase   = data.clase,
                }
            end
        end
    end

    -- Ahora aplicar los desbloqueos sobre la tabla limpia
    for name, nuevaData in pairs(aDesbloquear) do
        BotFriendshipDB.Bots[name] = nil
        BotFriendshipDB.Bots[name] = {
            puntos  = nuevaData.puntos,
            paragon = nuevaData.paragon,
            clase   = nuevaData.clase,
        }
        print("|cff00ff00BotFriendship:|r " .. string.format(BF_L("UNBLOCKED_MSG"), name))
        SendChatMessage(".npcbot unhide", "SAY")
    end

    if BF_Journal:IsShown() then BF_RefreshJournalList() end
end

-- Ticker: cada 1 segundo refresca el contador visual del diario,
-- cada 30 segundos comprueba desbloqueos
local BF_TickerFrame    = CreateFrame("Frame")
local BF_TickerAcum     = 0
local BF_TickerDesbloqueo = 0
BF_TickerFrame:SetScript("OnUpdate", function(self, elapsed)
    BF_TickerAcum       = BF_TickerAcum + elapsed
    BF_TickerDesbloqueo = BF_TickerDesbloqueo + elapsed

    -- Refrescar contador visual cada segundo si el diario está abierto y hay algún bloqueado
    if BF_TickerAcum >= 1 then
        BF_TickerAcum = 0
        if BF_Journal:IsShown() and BotFriendshipDB and BotFriendshipDB.Bots then
            local hayBloqueado = false
            for _, data in pairs(BotFriendshipDB.Bots) do
                if data.bloqueado then hayBloqueado = true break end
            end
            if hayBloqueado then BF_RefreshJournalList() end
        end
    end

    -- Comprobar desbloqueos cada 30 segundos
    if BF_TickerDesbloqueo >= 30 then
        BF_TickerDesbloqueo = 0
        BF_CheckDesbloqueos()
    end
end)

-- ============================================================
local BF_UltimaKillDioXP = false

BF_EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and (... == "BotFriendship" or ... == "NPCBotInventory") then
        BF_CheckDB()
        BF_Title:SetText(BF_L("TITLE"))
        BF_LangBtn:SetText(BF_L("LANG_BTN"))
        -- Revisar si algún bot debe desbloquearse tras haber cerrado sesión durante el castigo
        C_Timer.After(2, function() BF_CheckDesbloqueos() end)
        BF_UpdatePartyPvPIcons()
        print("|cff00ff00BotFriendship:|r " .. BF_L("TITLE") .. " listo.")
    end

    if event == "PARTY_MEMBERS_CHANGED" then
        BF_UpdatePartyPvPIcons()
    end

    if event == "QUEST_FINISHED" then
        local numMiembros = GetNumPartyMembers()
        if numMiembros > 0 then
            for i = 1, numMiembros do
                local name = GetPartyMember(i) and UnitName("party"..i)
                if name and name ~= UnitName("player") then
                    BF_ModificarPuntos(name, PUNTOS_MISION)
                end
            end
        else
            if BotFriendshipDB and BotFriendshipDB.Bots then
                for name, _ in pairs(BotFriendshipDB.Bots) do
                    if UnitExists(name) or UnitExists("party1") then
                        BF_ModificarPuntos(name, PUNTOS_MISION)
                        break
                    end
                end
            end
        end
    end

    if event == "CHAT_MSG_COMBAT_XP_GAIN" or event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        BF_UltimaKillDioXP = true
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, _, _, _, destName, destFlags = ...
        if subevent == "UNIT_DIED" then
            local esMiembroGrupo = bit.band(destFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) ~= 0
            if esMiembroGrupo and destName and destName ~= UnitName("player") then
                BF_ModificarPuntos(destName, PENALIZACION_MUERTE_BOT)
                if BotFriendshipDB.Bots[destName] then
                    print("|cffff0000BotFriendship:|r ¡" .. destName .. " " .. BF_L("DIED_WARNING"))
                end
            end
            
            local esNPCEnemigo = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0 or bit.band(destFlags, COMBATLOG_OBJECT_CONTROL_NPC) ~= 0
            if esNPCEnemigo and not esMiembroGrupo and destName then
                local puntosAGanar = PUNTOS_KILL_NORMAL
                if UnitExists("target") and UnitName("target") == destName then
                    local clasificacion = UnitClassification("target")
                    if clasificacion == "worldboss" or clasificacion == "rareelite" then puntosAGanar = PUNTOS_KILL_BOSS
                    elseif clasificacion == "elite" or clasificacion == "rare" then puntosAGanar = PUNTOS_KILL_ELITE end
                end

                -- FIX: capturamos destName en el closure para que no se pierda tras el delay
                local nombreMuerto = destName

                local delayTimer = 0
                local delayFrame = CreateFrame("Frame")
                delayFrame:SetScript("OnUpdate", function(df, elap)
                    delayTimer = delayTimer + elap
                    if delayTimer > 0.1 then
                        local numMiembros = GetNumPartyMembers()
                        local killValida = BF_UltimaKillDioXP or (UnitLevel("player") == 80)
                        if numMiembros > 0 and killValida then
                            -- Con grupo: puntos positivos a todos los bots del grupo
                            for i = 1, numMiembros do
                                local name = GetPartyMember(i) and UnitName("party"..i)
                                if name and name ~= UnitName("player") then BF_ModificarPuntos(name, puntosAGanar) end
                            end
                        elseif numMiembros == 0 and killValida then
                            -- Sin grupo: penalizamos todos los bots registrados en la BD.
                            -- UnitExists() no funciona con NPCBots fuera del grupo, así que
                            -- usamos la BD directamente como fuente de verdad.
                            if BotFriendshipDB and BotFriendshipDB.Bots then
                                for botName, _ in pairs(BotFriendshipDB.Bots) do
                                    BF_ModificarPuntos(botName, PENALIZACION_SIN_GRUPO)
                                    print("|cffff0000BotFriendship:|r " .. botName .. " " .. BF_L("USED_WARNING") .. " " .. (BotFriendshipDB.Bots[botName] and BotFriendshipDB.Bots[botName].puntos or 0))
                                end
                            end
                        end
                        BF_UltimaKillDioXP = false
                        df:SetScript("OnUpdate", nil)
                    end
                end)
            end
            
            local esDestinoCivil = bit.band(destFlags, COMBATLOG_OBJECT_REACTION_FRIENDLY) ~= 0 or bit.band(destFlags, COMBATLOG_OBJECT_REACTION_NEUTRAL) ~= 0
            local sourceFlags = select(5, ...)
            local esAsesinatoDelJugador = bit.band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) ~= 0
            if esAsesinatoDelJugador and esDestinoCivil and destName and not UnitIsPlayer("target") then
                local numMiembros = GetNumPartyMembers()
                if numMiembros > 0 then
                    for i = 1, numMiembros do
                        local name = GetPartyMember(i) and UnitName("party"..i)
                        if name and name ~= UnitName("player") then BF_ModificarPuntos(name, PENALIZACION_DESHONOR) end
                    end
                else
                    -- Sin grupo: deshonor a todos los bots registrados en la BD.
                    if BotFriendshipDB and BotFriendshipDB.Bots then
                        for botName, _ in pairs(BotFriendshipDB.Bots) do
                            print("|cffff0000BotFriendship:|r " .. string.format(BF_L("CIVIL_WARNING"), botName) .. " " .. (BotFriendshipDB.Bots[botName] and BotFriendshipDB.Bots[botName].puntos or 0))
                            BF_ModificarPuntos(botName, PENALIZACION_DESHONOR)
                        end
                    end
                end
            end
        end
    end
end)

StaticPopupDialogs["NBI_RESET_BOT_JOURNAL_CONFIRM"] = {
    text = "¿Seguro que quieres reiniciar amistad?",
    button1 = YES, button2 = NO,
    OnAccept = function(self, data)
        if data and BotFriendshipDB and BotFriendshipDB.Bots and BotFriendshipDB.Bots[data] then
            BotFriendshipDB.Bots[data] = nil
            BF_RefreshJournalList()
            print("|cff00ff00BotFriendship:|r Se ha reiniciado la amistad de " .. data)
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

SLASH_BOTFRIEND1 = "/botfriend"
SlashCmdList["BOTFRIEND"] = function(msg)
    if msg == "menu" or msg == "journal" then
        if BF_Journal:IsShown() then BF_Journal:Hide() else BF_RefreshJournalList() BF_Journal:Show() end
    elseif msg:match("^desbloquear%s+(.+)$") then
        local botName = msg:match("^desbloquear%s+(.+)$")
        if BotFriendshipDB and BotFriendshipDB.Bots and BotFriendshipDB.Bots[botName] then
            local data = BotFriendshipDB.Bots[botName]
            if data.bloqueado then
                local puntosRestaurados = data.puntosGuardados or 1
                local paragonGuardado   = data.paragon or 0
                local claseGuardada     = data.clase
                BotFriendshipDB.Bots[botName] = nil
                BotFriendshipDB.Bots[botName] = {
                    puntos  = puntosRestaurados,
                    paragon = paragonGuardado,
                    clase   = claseGuardada,
                }
                print("|cff00ff00BotFriendship:|r " .. botName .. " desbloqueado manualmente.")
                SendChatMessage(".npcbot unhide", "SAY")
                if BF_Journal:IsShown() then BF_RefreshJournalList() end
            else
                print("|cff00ff00BotFriendship:|r " .. botName .. " no está bloqueado.")
            end
        else
            print("|cffff0000BotFriendship:|r Bot no encontrado: " .. botName)
        end
    else
        print("|cff00ff00BotFriendship:|r Comandos disponibles:")
        print("  /botfriend menu            — abre el diario")
        print("  /botfriend desbloquear NombreBot  — desbloquea un bot manualmente")
    end
end

-- ============================================================
-- BOTÓN FLOTANTE EN PANTALLA
-- Icono: corazón de amigo (FriendsFrame toast)
-- Clic izquierdo: abre/cierra el diario
-- Clic derecho: ayuda rápida en chat
-- Arrastrable, posición guardada en SavedVariables
-- ============================================================
local BF_MinimapBtn = CreateFrame("Button", "BotFriendshipMinimapBtn", UIParent)
BF_MinimapBtn:SetSize(40, 40)
BF_MinimapBtn:SetFrameStrata("MEDIUM")
BF_MinimapBtn:SetMovable(true)
BF_MinimapBtn:EnableMouse(true)
BF_MinimapBtn:RegisterForDrag("LeftButton")
BF_MinimapBtn:RegisterForClicks("RightButtonUp", "LeftButtonUp")

-- Icono cuadrado que ocupa todo el botón
local BF_BtnIcon = BF_MinimapBtn:CreateTexture(nil, "ARTWORK")
BF_BtnIcon:SetAllPoints(true)
BF_BtnIcon:SetTexture("Interface\\Icons\\INV_Banner_02")

-- Borde de ranura de acción encima del icono
local BF_BtnBorder = BF_MinimapBtn:CreateTexture(nil, "OVERLAY")
BF_BtnBorder:SetAllPoints(true)
BF_BtnBorder:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")

-- Posición por defecto: esquina superior derecha bajo el minimap
BF_MinimapBtn:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -15, -200)

-- Restaurar posición guardada al cargar
BF_MinimapBtn:RegisterEvent("ADDON_LOADED")
BF_MinimapBtn:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and (addon == "BotFriendship" or addon == "NPCBotInventory") then
        if BotFriendshipDB and BotFriendshipDB.BtnPos then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "TOPLEFT",
                BotFriendshipDB.BtnPos.x, BotFriendshipDB.BtnPos.y)
        end
    end
end)

-- Guardar posición al soltar
BF_MinimapBtn:SetScript("OnDragStart", function(self) self:StartMoving() end)
BF_MinimapBtn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not BotFriendshipDB then BotFriendshipDB = {} end
    BotFriendshipDB.BtnPos = {
        x = self:GetLeft(),
        y = self:GetTop() - UIParent:GetHeight(),
    }
end)

-- Clics
BF_MinimapBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if BF_Journal:IsShown() then
            BF_Journal:Hide()
        else
            BF_RefreshJournalList()
            BF_Journal:Show()
        end
    elseif button == "RightButton" then
        print("|cff00ff00BotFriendship:|r Clic izquierdo — abre/cierra el Diario.")
        print("|cff00ff00BotFriendship:|r /botfriend desbloquear NombreBot — desbloqueo manual.")
    end
end)

-- Tooltip al pasar el ratón
BF_MinimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cffFFD700Diario de Compañeros|r")
    GameTooltip:AddLine("Clic izquierdo: abrir / cerrar", 1, 1, 1)
    GameTooltip:AddLine("Clic derecho: ayuda", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Arrastra para mover", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end)
BF_MinimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
