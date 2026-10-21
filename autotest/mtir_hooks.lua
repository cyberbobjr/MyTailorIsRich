-- My Tailor Is Rich in-game nominal test (pz-autotest, .claude/tools/pz-autotest/README.md).
--
-- The authority (single player client, or the dedicated server in mp) plays the
-- nominal path through the mod's real timed actions (complete() called at once,
-- as the server does after a client request):
--   1. label reading (shirt) and shoe size reading (CheckSize)
--   2. alteration by hand (Resize: down with paperclips, or up with strips)
--   3. pattern traced at a work table (TracePattern), then copied (CopyPattern):
--      a written, a renamed and a favourite sheet must NOT be consumed (C01)
--   4. treadle sewing machine placed next to the player: sewing from the copy
--      (SewPattern with machinePos), machine detected, wear when enabled
--   5. dyeing (Dye) and hand embroidery (Embroider)
-- Every test item is marked in ModData (PZAT_MTIR) and synced to its owner.
-- In mp, client 1 (--client-run) then checks what its own copy received:
-- ModData (size, label, pattern, embroidery), custom colour and visual tint.
local H = { client = {}, server = {} }

local MARK = "PZAT_MTIR"
local S = { lines = {}, ok = true, finished = false, failures = 0, passes = 0 }

local function rec(ok, name, detail)
    if ok then
        S.passes = S.passes + 1
    else
        S.ok = false
        S.failures = S.failures + 1
    end
    S.lines[#S.lines + 1] = (ok and "PASS " or "FAIL ") .. name .. (detail and (" - " .. tostring(detail)) or "")
end

local function warn(name, detail)
    S.lines[#S.lines + 1] = "WARN " .. name .. (detail and (" - " .. tostring(detail)) or "")
end

local function check(name, fn)
    local ok, res, detail = pcall(fn)
    if not ok then
        rec(false, name, "error: " .. tostring(res))
        return false
    end
    rec(res == true, name, detail)
    return res == true
end

-------------------------------------------------------------------------------
-- Helpers (authority)
-------------------------------------------------------------------------------
local P -- player under test

local function give(fullType, count)
    local inv = P:getInventory()
    local first
    for _ = 1, count or 1 do
        local item = inv:AddItem(fullType)
        if item then
            first = first or item
            if isServer() then sendAddItemToContainer(inv, item) end
        end
    end
    return first
end

local function mark(item, role, extra)
    local md = item:getModData()
    md[MARK] = role
    if extra then
        for k, v in pairs(extra) do md[k] = v end
    end
    if isServer() then syncItemFields(P, item) end
end

local function equip(primary, secondary)
    P:setPrimaryHandItem(primary)
    P:setSecondaryHandItem(secondary)
end

local function threads()
    local inv = P:getInventory()
    if MTIR.collectThreads then return MTIR.collectThreads(inv) end
    return inv:getItemsFromType("Thread", true)
end

local function inInventory(item)
    return item ~= nil and P:getInventory():getItemWithIDRecursiv(item:getID()) ~= nil
end

local function countType(fullType)
    return P:getInventory():getItemsFromFullType(fullType, true):size()
end

-- First candidate type whose fresh instance satisfies `pred`.
local function pickType(candidates, pred)
    for _, t in ipairs(candidates) do
        local probe = instanceItem(t)
        if probe and pred(probe) then return t end
    end
    return nil
end

local SHIRTS = { "Base.Tshirt_DefaultTEXTURE_TINT", "Base.Tshirt_White", "Base.Shirt_FormalWhite",
    "Base.Tshirt_DefaultDECAL_TINT", "Base.Trousers_WhiteTINT" }
local SHOES = { "Base.Shoes_TrainerTINT", "Base.Shoes_Black", "Base.Shoes_BlackBoots", "Base.Shoes_Brown" }

-- Free floor square next to the player (same level), for the machine.
local function freeSquareNearPlayer()
    local sq0 = P:getCurrentSquare()
    if not sq0 then return nil end
    local cell = getCell()
    for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }) do
        local sq = cell:getGridSquare(sq0:getX() + d[1], sq0:getY() + d[2], sq0:getZ())
        if sq and sq:isSolidFloor() and sq:isFree(false) and not sq:HasStairs()
            and not MTIR.findSewingMachine(sq) and not MTIR.findWorkTable(sq) then
            return sq
        end
    end
    return nil
end

local machine, machineSq

local function placeMachine()
    machineSq = freeSquareNearPlayer()
    if not machineSq then return nil end
    machine = IsoObject.new(getCell(), machineSq, "mtir_treadle_01_0")
    machineSq:AddTileObject(machine)
    if isServer() then machine:transmitCompleteItemToClients() end
    return machine
end

local function removeMachine()
    if machine and machineSq and machine:getObjectIndex() ~= -1 then
        machineSq:transmitRemoveItemFromSquare(machine)
    end
end

-------------------------------------------------------------------------------
-- Scenario (authority)
-------------------------------------------------------------------------------
local function scenario()
    P:setPerkLevelDebug(Perks.Tailoring, 10)
    give("Base.Thimble")
    local needle = give("Base.Needle")
    local scissors = give("Base.Scissors")
    local pen = give("Base.Pencil")
    give("Base.Thread", 6)

    local shirtType = pickType(SHIRTS, function(i)
        return MTIR.canClothesHaveSize(i) and MTIR.canResizeClothes(i) and MTIR.canTintClothing(i)
            and MTIR.canEmbroider(i) and MTIR.describeModel(i) ~= nil
    end)
    local shoeType = pickType(SHOES, function(i) return MTIR.canShoeHaveSize(i) end)
    rec(shirtType ~= nil, "test garment found", shirtType)
    rec(shoeType ~= nil, "test shoes found", shoeType)
    if not shirtType then return end

    -- 1. Label reading and shoe size --------------------------------------------
    local shirtA = give(shirtType)
    check("label: CheckSize reveals the size", function()
        -- A fresh garment is sometimes born already altered (10 %): reset for a fixed path.
        MTIR.ensureData(shirtA).resized = 0
        local done = MTIR_CheckSizeAction:new(P, shirtA):complete()
        local data = MTIR.getData(shirtA)
        return done == true and data ~= nil and data.size ~= nil and data.reveal == true,
            data and ("size=" .. tostring(data.size)) or "no data"
    end)
    if shoeType then
        local shoe = give(shoeType)
        check("shoe size: CheckSize reads the size", function()
            local done = MTIR_CheckSizeAction:new(P, shoe):complete()
            local data = MTIR.getShoeData(shoe)
            return done == true and data ~= nil and data.reveal == true, data and ("size=" .. tostring(data.size))
        end)
        mark(shoe, "shoe")
    end

    -- 2. Alteration by hand ----------------------------------------------------
    check("alteration by hand: Resize changes the size", function()
        local before = MTIR.getData(shirtA).size
        local upsize = MTIR.getResizeTarget(shirtA, false) == nil
        local target = MTIR.getResizeTarget(shirtA, upsize)
        local matType, matCount = MTIR.getResizeMaterial(shirtA, upsize)
        if not target or not matType then return false, "no target or material" end
        give(matType, matCount)
        local mats = MTIR.pickItems(P:getInventory():getItemsFromFullType(matType, true), matCount)
        equip(scissors, needle)
        local done = MTIR_ResizeAction:new(P, shirtA, needle, scissors, threads(), mats, upsize, ""):complete()
        local data = MTIR.getData(shirtA)
        return done == true and data.size == target.name and data.resized ~= 0,
            tostring(before) .. " -> " .. tostring(data.size) .. (upsize and " (up)" or " (down)")
    end)
    mark(shirtA, "resized")

    -- 3. Machine (also the work table: the treadle machine is sewing furniture) --
    local m = placeMachine()
    rec(m ~= nil, "treadle machine placed next to the player", machineSq and (machineSq:getX() .. "," .. machineSq:getY()))
    if not m then return end
    local pos = MTIR.encodeMachinePos(m)
    check("machine detected, usable, and a work table", function()
        local problem = MTIR.getSewingMachineProblem(P, m, nil)
        return MTIR.machineFromPos(pos) == m and problem == nil and MTIR.workTableFromPos(pos) == m,
            "problem=" .. tostring(problem)
    end)

    -- 4. Trace a pattern; protected sheets must survive (C01) -----------------
    local written = give("Base.SheetPaper2")
    written:addPage(1, "PZAT note: do not consume")
    local renamed = give("Base.SheetPaper2")
    renamed:setName("PZAT named sheet")
    renamed:setCustomName(true)
    local favourite = give("Base.SheetPaper2")
    favourite:setFavorite(true)
    mark(written, "written")
    mark(renamed, "renamed")
    mark(favourite, "favourite")
    check("C01: predicatePaper rejects written, renamed and favourite sheets", function()
        local w, r, f = MTIR.predicatePaper(written), MTIR.predicatePaper(renamed), MTIR.predicatePaper(favourite)
        return not w and not r and not f, "written=" .. tostring(w) .. " renamed=" .. tostring(r)
            .. " favourite=" .. tostring(f)
    end)

    local shirtB = give(shirtType)
    MTIR.ensureData(shirtB)
    local model = MTIR.describeModel(shirtB)
    local pattern
    check("trace: TracePattern creates a pattern from blank sheets only", function()
        give("Base.SheetPaper2", MTIR.getRequiredPaper(model) * 2 + 2)
        -- Same selection as the context menu (MTIR_PatternMenu.addTraceOption).
        local papers = MTIR.pickItems(P:getInventory():getAllEvalRecurse(MTIR.predicatePaper),
            MTIR.getRequiredPaper(model))
        if not papers then return false, "no blank sheets picked" end
        local before = countType(MTIR.PATTERN_ITEM)
        equip(scissors, pen)
        local done = MTIR_TracePatternAction:new(P, shirtB, scissors, pen, papers, pos):complete()
        local items = P:getInventory():getItemsFromFullType(MTIR.PATTERN_ITEM, true)
        pattern = items:size() > before and items:get(items:size() - 1) or nil
        return done == true and pattern ~= nil and MTIR.getPatternData(pattern) ~= nil and not inInventory(shirtB),
            "done=" .. tostring(done)
    end)
    check("C01: authority refuses a trace that lists a written sheet", function()
        local shirtX = give(shirtType)
        MTIR.ensureData(shirtX)
        local papers = ArrayList.new()
        papers:add(written)
        local blanks = P:getInventory():getAllEvalRecurse(MTIR.predicatePaper)
        for i = 0, math.min(blanks:size(), MTIR.getRequiredPaper(model)) - 2 do papers:add(blanks:get(i)) end
        equip(scissors, pen)
        local done = MTIR_TracePatternAction:new(P, shirtX, scissors, pen, papers, pos):complete()
        local kept = inInventory(shirtX)
        MTIR.removeItem(shirtX)
        return done ~= true and kept, "done=" .. tostring(done)
    end)
    if not pattern then return end
    mark(pattern, "traced")

    -- 5. Copy the pattern -------------------------------------------------------
    local copy
    check("copy: CopyPattern keeps the original and adds a copy", function()
        local data = MTIR.getPatternData(pattern)
        local papers = MTIR.pickItems(P:getInventory():getAllEvalRecurse(MTIR.predicatePaper),
            MTIR.getRequiredPaperToCopy(data))
        if not papers then return false, "no blank sheets picked" end
        local before = countType(MTIR.PATTERN_ITEM)
        equip(scissors, pen)
        local done = MTIR_CopyPatternAction:new(P, pattern, scissors, pen, papers, pos):complete()
        local items = P:getInventory():getItemsFromFullType(MTIR.PATTERN_ITEM, true)
        for i = 0, items:size() - 1 do
            local d = MTIR.getPatternData(items:get(i))
            if d and (d.copies or 0) >= 1 then copy = items:get(i) end
        end
        return done == true and items:size() == before + 1 and copy ~= nil and inInventory(pattern),
            copy and ("copies=" .. tostring(MTIR.getPatternData(copy).copies)) or "no copy"
    end)
    check("C01: written, renamed and favourite sheets still there and unchanged", function()
        return inInventory(written) and inInventory(renamed) and inInventory(favourite)
            and not written:isEmptyPages() and renamed:getDisplayName() == "PZAT named sheet" and favourite:isFavorite(),
            "written=" .. tostring(inInventory(written)) .. " renamed=" .. tostring(inInventory(renamed))
                .. " favourite=" .. tostring(inInventory(favourite))
    end)
    if copy then mark(copy, "copy") end

    -- 6. Sew from the copy on the machine ----------------------------------------
    check("machine: SewPattern on the treadle creates the garment", function()
        local src = copy or pattern
        local data = MTIR.getPatternData(src)
        local mods = MTIR.resolveWorkMods(P, pos, data)
        if not mods or not mods.machine then return false, "machine mods unavailable" end
        local size = data.kind == "shoe" and tostring(MTIR.getPlayerShoeSize(P)) or MTIR.getPlayerSize(P).name
        for _, t in ipairs(MTIR.getPatternMaterialTypes(data.fabric)) do give(t, 12) end
        local condBefore = MTIR.getMachineCondition(m)
        local before = countType(data.fullType)
        local made, attempts = false, 0
        -- A needle may break on a machine (fail roll): fetch a new one and retry.
        while not made and attempts < 4 do
            attempts = attempts + 1
            local req = MTIR.getSewRequirements(P, data, size, mods)
            if not (req.needle and req.scissors and req.threads and req.materials) then
                give("Base.Needle")
                req = MTIR.getSewRequirements(P, data, size, mods)
            end
            if not (req.needle and req.scissors and req.threads and req.materials) then
                return false, "requirements missing"
            end
            equip(req.scissors, req.needle)
            local done = MTIR_SewPatternAction:new(P, src, req.needle, req.scissors, req.threads, req.materials, size,
                pos, req.awl, req.glue):complete()
            if done ~= true then return false, "complete refused" end
            made = countType(data.fullType) > before
        end
        local worn = not MTIR.isMaintenanceEnabled() or MTIR.getMachineCondition(m) < condBefore
        if made then
            local items = P:getInventory():getItemsFromFullType(data.fullType, true)
            mark(items:get(items:size() - 1), "sewn")
        end
        return made and worn, "attempts=" .. attempts .. " size=" .. tostring(size) .. " wear=" .. tostring(condBefore)
            .. "->" .. tostring(MTIR.getMachineCondition(m))
    end)

    -- 7. Dyeing and embroidery ---------------------------------------------------
    local shirtC = give(shirtType)
    MTIR.ensureData(shirtC)
    check("dyeing: Dye applies the dye colour", function()
        local dye = give("Base.IndustrialDye")
        local water = give("Base.BucketEmpty")
        water:getFluidContainer():addFluid(Fluid.Water, 10)
        if isServer() then sendItemStats(water) end
        local kind = MTIR.checkDyeBath(shirtC, dye, water)
        if not kind then return false, "dye bath refused (dye kind " .. tostring(MTIR.getDyeKind(dye)) .. ")" end
        local r, g, b = MTIR.getDyeColor(dye)
        local done = MTIR_DyeAction:new(P, shirtC, dye, water):complete()
        local same = math.abs(shirtC:getColorRed() - r) < 0.01 and math.abs(shirtC:getColorGreen() - g) < 0.01
            and math.abs(shirtC:getColorBlue() - b) < 0.01
        shirtC:getModData().PZAT_MTIR_color = { r = r, g = g, b = b }
        return done == true and shirtC:isCustomColor() and same, string.format("rgb=%.2f,%.2f,%.2f", r, g, b)
    end)
    check("embroidery: Embroider renames and stores the text", function()
        local text = "PZAT"
        local newName = shirtC:getDisplayName() .. " " .. text
        local cleanName = MTIR.cleanEmbroideryText(newName, MTIR.EMBROIDERY_NAME_MAX) or (text .. " shirt")
        equip(needle, nil)
        local done = MTIR_EmbroiderAction:new(P, shirtC, needle, threads(), text, cleanName):complete()
        local emb = MTIR.getEmbroidery(shirtC)
        shirtC:getModData().PZAT_MTIR_name = cleanName
        return done == true and emb ~= nil and emb.text == text and shirtC:getDisplayName() == cleanName,
            "name=" .. tostring(shirtC:getDisplayName())
    end)
    mark(shirtC, "dyed")
    equip(nil, nil)
end

-------------------------------------------------------------------------------
-- MP client: checks its own copy of the marked items
-------------------------------------------------------------------------------
local C = { deadline = 0, checked = false }

local function findMarked(player, role)
    local items = player:getInventory():getAllEvalRecurse(function(i)
        return i:hasModData() and i:getModData()[MARK] == role
    end)
    return items:size() > 0 and items:get(0) or nil
end

local CLIENT_ROLES = { "shoe", "resized", "written", "renamed", "favourite", "traced", "copy", "sewn", "dyed" }

local function clientReady(player)
    for _, role in ipairs(CLIENT_ROLES) do
        if not findMarked(player, role) then return false end
    end
    -- The last item is marked after embroidery: wait until its name arrives too.
    local dyed = findMarked(player, "dyed")
    return MTIR.getEmbroidery(dyed) ~= nil
end

local function clientChecks(player)
    local function has(role)
        return findMarked(player, role) ~= nil
    end
    rec(has("shoe") and (MTIR.getShoeData(findMarked(player, "shoe")) or {}).reveal == true,
        "client: shoe size revealed (ModData synced)")
    local resized = findMarked(player, "resized")
    local rd = resized and MTIR.getData(resized)
    rec(rd ~= nil and rd.reveal == true and rd.resized ~= 0, "client: altered garment ModData synced",
        rd and ("size=" .. tostring(rd.size)))
    rec(has("written") and has("renamed") and has("favourite"), "client: C01 protected sheets still owned")
    rec(has("traced") and MTIR.getPatternData(findMarked(player, "traced")) ~= nil, "client: traced pattern data")
    local copy = findMarked(player, "copy")
    rec(copy ~= nil and (MTIR.getPatternData(copy) or {}).copies == 1, "client: pattern copy data")
    rec(has("sewn") and MTIR.getData(findMarked(player, "sewn")) ~= nil, "client: sewn garment has a size")
    local dyed = findMarked(player, "dyed")
    local md = dyed and dyed:getModData()
    local col = md and md.PZAT_MTIR_color
    if dyed and col then
        local okColour = dyed:isCustomColor() and math.abs(dyed:getColorRed() - col.r) < 0.01
            and math.abs(dyed:getColorGreen() - col.g) < 0.01 and math.abs(dyed:getColorBlue() - col.b) < 0.01
        rec(okColour, "client: dye colour synced (custom colour)")
        local visual = dyed:getVisual()
        local tint = visual and visual:getTint()
        local okTint = tint ~= nil and math.abs(tint:getRedFloat() - col.r) < 0.02
            and math.abs(tint:getGreenFloat() - col.g) < 0.02 and math.abs(tint:getBlueFloat() - col.b) < 0.02
        if okTint then
            rec(true, "client: visual tint synced")
        else
            -- syncItemFields carries the custom colour, not the visual tint (unworn item).
            warn("client: visual tint not synced on the unworn item", tint and string.format("%.2f,%.2f,%.2f",
                tint:getRedFloat(), tint:getGreenFloat(), tint:getBlueFloat()) or "no visual")
        end
    else
        rec(false, "client: dyed garment received")
    end
    rec(dyed ~= nil and MTIR.getEmbroidery(dyed) ~= nil and md.PZAT_MTIR_name == dyed:getDisplayName(),
        "client: embroidery ModData and name synced", dyed and dyed:getDisplayName())
end

-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------
local function runAuthority()
    local ok, err = pcall(scenario)
    if not ok then rec(false, "scenario", "error: " .. tostring(err)) end
    pcall(removeMachine)
    S.finished = true
end

local function result()
    return { ok = S.ok, summary = S.passes .. " pass, " .. S.failures .. " fail", lines = S.lines }
end

function H.client.start(ctx)
    if ctx.role == "sp" then
        P = getPlayer()
        if not P then return false, "no player" end
        runAuthority()
        return true
    end
    -- mpclient: wait for the server scenario, then check the local copies.
    C.deadline = getTimestampMs() + (tonumber(ctx.params.clientWaitSec) or 180) * 1000
    return true
end

function H.client.done(ctx)
    if ctx.role == "sp" then return S.finished end
    local player = getPlayer()
    if player and clientReady(player) then
        clientChecks(player)
        return true
    end
    if getTimestampMs() > C.deadline then
        rec(false, "client: marked items received before the deadline")
        if player then clientChecks(player) end
        return true
    end
    return false
end

H.client.result = result

function H.server.start(ctx)
    local players = ctx.players()
    P = players and players[1]
    if not P then return false, "no online player" end
    runAuthority()
    return true
end

function H.server.done()
    return S.finished
end

H.server.result = result

return H
