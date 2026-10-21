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
-- Handshake (mp): the client sends "ready" until the server answers "started";
-- the server waits for it (and for the player's square to be loaded on the
-- server), runs the scenario, then sends "done" with the roles it prepared, so
-- the client only checks what was really done and fails fast after an abort.
local H = { client = {}, server = {} }

local MARK = "PZAT_MTIR"
local CMD = "PZAT_MTIR" -- module of the hook's network commands
local S = { lines = {}, ok = true, finished = false, failures = 0, passes = 0, roles = {} }

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

local function info(name, detail)
    local line = "INFO " .. name .. (detail and (" - " .. tostring(detail)) or "")
    S.lines[#S.lines + 1] = line
    print("[MTIR autotest] " .. line)
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
    local known = false
    for _, r in ipairs(S.roles) do known = known or r == role end
    if not known then S.roles[#S.roles + 1] = role end
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

-- Free floor square near the player (same level, ring 1 then ring 2), for the
-- machine. Returns the square, or nil and the reason of each rejected square.
local NEAR = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 },
    { 2, 0 }, { 0, 2 }, { -2, 0 }, { 0, -2 }, { 2, 1 }, { 1, 2 }, { -2, -1 }, { -1, -2 } }

local function freeSquareNearPlayer()
    local sq0 = P:getCurrentSquare()
    if not sq0 then
        return nil, string.format("player square nil at %.1f,%.1f,%.1f", P:getX(), P:getY(), P:getZ())
    end
    local cell = getCell()
    local why = {}
    for _, d in ipairs(NEAR) do
        local sq = cell:getGridSquare(sq0:getX() + d[1], sq0:getY() + d[2], sq0:getZ())
        local reason
        if not sq then
            reason = "not loaded"
        elseif not sq:isSolidFloor() then
            reason = "no floor"
        elseif not sq:isFree(false) then
            reason = "not free"
        elseif sq:HasStairs() then
            reason = "stairs"
        elseif MTIR.findSewingMachine(sq) or MTIR.findWorkTable(sq) then
            reason = "furniture"
        else
            return sq
        end
        why[#why + 1] = d[1] .. "," .. d[2] .. "=" .. reason
    end
    return nil, table.concat(why, " ")
end

local machine, machineSq
local MACHINE_SPRITE = "mtir_treadle_01_0"
local MACHINE_ITEM = "Base.Mov_MTIR_TreadleMachine"

-- Same path as a player placing the furniture item (ISMoveablesAction:complete
-- -> placeMoveableInternal, four arguments, no character): right class, B42
-- entity created from the SpriteConfig, sent to the clients on a server.
local function placeMachine()
    local sq, why = freeSquareNearPlayer()
    local sq0 = P:getCurrentSquare()
    info("machine: player square", sq0 and (sq0:getX() .. "," .. sq0:getY() .. "," .. sq0:getZ()) or "nil")
    if not sq then return nil, "no free square (" .. tostring(why) .. ")" end
    machineSq = sq
    info("machine: target square", sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ())
    local sprite = getSprite(MACHINE_SPRITE)
    if not sprite or sprite:getName() ~= MACHINE_SPRITE then
        return nil, "sprite " .. MACHINE_SPRITE .. " not loaded on this side"
    end
    local props = ISMoveableSpriteProps.new(sprite)
    if not props.isMoveable then return nil, "sprite " .. MACHINE_SPRITE .. " has no IsMoveAble" end
    local item = props:instanceItem(MACHINE_SPRITE) or instanceItem(MACHINE_ITEM)
    if not item then return nil, "no inventory item for " .. MACHINE_SPRITE end
    info("machine: inventory item", item:getFullType())
    local obj = props:placeMoveableInternal(nil, sq, item, MACHINE_SPRITE)
    if not obj or obj:getObjectIndex() == -1 then return nil, "placeMoveableInternal placed nothing" end
    machine = obj
    info("machine: object created", tostring(obj:getObjectName()) .. " sprite="
        .. tostring(obj:getSprite() and obj:getSprite():getName()) .. " thumpable="
        .. tostring(instanceof(obj, "IsoThumpable")) .. " recognised=" .. tostring(MTIR.isSewingMachine(obj)))
    return obj
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
    local placedOk, m, why = pcall(placeMachine)
    if not placedOk then m, why = nil, "error: " .. tostring(m) end
    rec(m ~= nil, "treadle machine placed next to the player", m and MTIR.encodeMachinePos(m) or why)
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
local C = { deadline = 0, serverDone = false, started = false, nextReady = 0, grace = 0, expected = nil }

local function findMarked(player, role)
    local items = player:getInventory():getAllEvalRecurse(function(i)
        return i:hasModData() and i:getModData()[MARK] == role
    end)
    return items:size() > 0 and items:get(0) or nil
end

local CLIENT_ROLES = { "shoe", "resized", "written", "renamed", "favourite", "traced", "copy", "sewn", "dyed" }

-- Roles to check: those the server reported as prepared, or all of them.
local function expectedRoles()
    if C.expected then return C.expected end
    local set = {}
    for _, r in ipairs(CLIENT_ROLES) do set[r] = true end
    return set
end

local function missingRoles(player)
    local want, missing = expectedRoles(), {}
    for _, role in ipairs(CLIENT_ROLES) do
        if want[role] and not findMarked(player, role) then missing[#missing + 1] = role end
    end
    return missing
end

local function clientReady(player)
    if #missingRoles(player) > 0 then return false end
    -- The last item is marked after embroidery: wait until its name arrives too.
    local dyed = findMarked(player, "dyed")
    return not dyed or not dyed:getModData().PZAT_MTIR_name or MTIR.getEmbroidery(dyed) ~= nil
end

local function clientChecks(player)
    local want = expectedRoles()
    local function has(role)
        return findMarked(player, role) ~= nil
    end
    if want.shoe then
        rec(has("shoe") and (MTIR.getShoeData(findMarked(player, "shoe")) or {}).reveal == true,
            "client: shoe size revealed (ModData synced)")
    end
    if want.resized then
        local resized = findMarked(player, "resized")
        local rd = resized and MTIR.getData(resized)
        rec(rd ~= nil and rd.reveal == true and rd.resized ~= 0, "client: altered garment ModData synced",
            rd and ("size=" .. tostring(rd.size)))
    end
    if want.written or want.renamed or want.favourite then
        rec(has("written") and has("renamed") and has("favourite"), "client: C01 protected sheets still owned")
    end
    if want.traced then
        rec(has("traced") and MTIR.getPatternData(findMarked(player, "traced")) ~= nil, "client: traced pattern data")
    end
    if want.copy then
        local copy = findMarked(player, "copy")
        rec(copy ~= nil and (MTIR.getPatternData(copy) or {}).copies == 1, "client: pattern copy data")
    end
    if want.sewn then
        rec(has("sewn") and MTIR.getData(findMarked(player, "sewn")) ~= nil, "client: sewn garment has a size")
    end
    if not want.dyed then return end
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

-- MP client ----------------------------------------------------------------------
local function onServerCommand(module, command, args)
    if module ~= CMD then return end
    if command == "started" then
        C.started = true
    elseif command == "done" and not C.serverDone then
        C.serverDone, C.started = true, true
        C.grace = getTimestampMs() + 30000
        C.expected = {}
        for role in string.gmatch(tostring(args and args.roles or ""), "[^,]+") do C.expected[role] = true end
        if not (args and args.ok) then
            rec(false, "client: server scenario completed", tostring(args and args.summary) .. " - "
                .. tostring(args and args.firstFail))
        end
    end
end

function H.client.start(ctx)
    if ctx.role == "sp" then
        P = getPlayer()
        if not P then return false, "no player" end
        runAuthority()
        return true
    end
    -- mpclient: announce readiness, wait for the server scenario, then check the local copies.
    C.deadline = getTimestampMs() + (tonumber(ctx.params.clientWaitSec) or 180) * 1000
    Events.OnServerCommand.Add(onServerCommand)
    return true
end

local function clientFinish(player)
    Events.OnServerCommand.Remove(onServerCommand)
    if player then clientChecks(player) end
    return true
end

function H.client.done(ctx)
    if ctx.role == "sp" then return S.finished end
    local player = getPlayer()
    local now = getTimestampMs()
    if player and not C.started and now >= C.nextReady then
        sendClientCommand(player, CMD, "ready", {})
        C.nextReady = now + 2000
    end
    if C.serverDone then
        if player and clientReady(player) then return clientFinish(player) end
        if now > C.grace then
            rec(false, "client: prepared items received within 30 s of the server result",
                player and ("missing " .. table.concat(missingRoles(player), ",")) or "no player")
            return clientFinish(player)
        end
        return false
    end
    if now > C.deadline then
        rec(false, "client: server result received before the deadline",
            C.started and "server started" or "server never answered ready")
        return clientFinish(player)
    end
    return false
end

H.client.result = result

-- Server -------------------------------------------------------------------------
local W = { since = 0, clientReady = false, sent = false }
local READY_WAIT_MS = 60000 -- without a "ready" (mp without --client-run), run anyway after this
local SQUARE_WAIT_MS = 90000

local function onClientCommand(module, command, player)
    if module ~= CMD or command ~= "ready" then return end
    if not W.clientReady then info("server: client ready", player and player:getUsername()) end
    W.clientReady = true
    sendServerCommand(player, CMD, "started", {})
end

local function sendDone()
    if W.sent or not P then return end
    W.sent = true
    local firstFail
    for _, line in ipairs(S.lines) do
        if not firstFail and line:sub(1, 5) == "FAIL " then firstFail = line end
    end
    sendServerCommand(P, CMD, "done", { ok = S.ok, summary = S.passes .. " pass, " .. S.failures .. " fail",
        roles = table.concat(S.roles, ","), firstFail = firstFail or "" })
end

function H.server.start(ctx)
    local players = ctx.players()
    P = players and players[1]
    if not P then return false, "no online player" end
    W.since = getTimestampMs()
    Events.OnClientCommand.Add(onClientCommand)
    return true
end

function H.server.done()
    if S.finished then return true end
    local waited = getTimestampMs() - W.since
    local squareLoaded = P:getCurrentSquare() ~= nil
    if not squareLoaded and waited > SQUARE_WAIT_MS then
        rec(false, "player square loaded on the server",
            string.format("%.1f,%.1f,%.1f", P:getX(), P:getY(), P:getZ()))
        S.finished = true
    elseif squareLoaded and (W.clientReady or waited > READY_WAIT_MS) then
        if not W.clientReady then warn("server: no client ready message, running anyway") end
        info("server: scenario start", "waited " .. waited .. " ms")
        runAuthority()
    else
        return false
    end
    sendDone()
    Events.OnClientCommand.Remove(onClientCommand)
    return true
end

H.server.result = result

return H
