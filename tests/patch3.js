const fs = require('fs');
const root = process.argv[2];
const edits = [
['LevelGuide/LevelGuide.lua', `local AHEAD_RADIANS = 0.35`, `local AHEAD_RADIANS = 0.35
local XP_WEIGHT = 2          -- a quest worth a fifth of a level counts as 1.4 times closer`],
// XP per quest, and tags.
['LevelGuide/LevelGuide.lua', `local function QuestDetail(step, logIndex)`, `local function RewardXP(questID)
    return GetQuestLogRewardXP and Safe(GetQuestLogRewardXP(questID)) or 0
end

local function MaxXP()
    local maxXP = Safe(UnitXPMax("player"))
    return maxXP and maxXP > 0 and maxXP or nil
end

local function QuestDetail(step, logIndex)`],
['LevelGuide/LevelGuide.lua', `    local here, away, unplaced = {}, {}, {}
    local points = mapID and MapPoints(mapID) or {}
    local level = Safe(UnitLevel("player"))`, `    local here, away, unplaced, later = {}, {}, {}, {}
    local points = mapID and MapPoints(mapID) or {}
    local level = Safe(UnitLevel("player"))`],
['LevelGuide/LevelGuide.lua', `            if not failed and not tooHard then
                local step = {
                    id = id, kind = ready and "turnin" or "work", title = Safe(info.title) or "A quest",
                    trivial = not ready and Safe(C_QuestLog.IsQuestTrivial(id)) or false,
                }`, `            if tooHard then
                later[#later + 1] = questLevel
            end
            if not failed and not tooHard then
                local step = {
                    id = id, kind = ready and "turnin" or "work", title = Safe(info.title) or "A quest",
                    trivial = not ready and Safe(C_QuestLog.IsQuestTrivial(id)) or false,
                    xp = RewardXP(id), group = Safe(info.suggestedGroup) or 0,
                }`],
['LevelGuide/LevelGuide.lua', `    return here, away, unplaced
end`, `    return here, away, unplaced, later
end`],
// Cost: XP pulls a step closer.
['LevelGuide/LevelGuide.lua', `    if step.trivial then
        cost = cost + TRIVIAL_PENALTY
    end
    return cost`, `    local maxXP = MaxXP()
    if step.xp and step.xp > 0 and maxXP then
        cost = cost / (1 + XP_WEIGHT * step.xp / maxXP)
    end
    if step.trivial then
        cost = cost + TRIVIAL_PENALTY
    end
    return cost`],
// Build: gray zones send you on; the ding; later quests.
['LevelGuide/LevelGuide.lua', `    local mapID, playerX, playerY = PlayerPosition()
    local here, away, unplaced = ReadQuests(mapID)
    for _, offer in ipairs(ReadOffers(mapID)) do
        here[#here + 1] = offer
    end
    local list = Route(here, mapID, playerX, playerY)
    for _, step in ipairs(unplaced) do
        list[#list + 1] = step
    end
    for _, step in ipairs(TravelSteps(away)) do
        list[#list + 1] = step
    end
    return list, mapID, playerX, playerY`, `    local mapID, playerX, playerY = PlayerPosition()
    local here, away, unplaced, later = ReadQuests(mapID)
    for _, offer in ipairs(ReadOffers(mapID)) do
        here[#here + 1] = offer
    end
    local list = Route(here, mapID, playerX, playerY)
    for _, step in ipairs(unplaced) do
        list[#list + 1] = step
    end
    local travel = TravelSteps(away)
    -- Gray quests are barely worth the walk, so when that's all that's left here, move on first.
    local onlyGray = #travel > 0
    for _, step in ipairs(list) do
        if not step.trivial then
            onlyGray = false
        end
    end
    if onlyGray then
        travel[1].detail = travel[1].detail .. ". What's left here is gray"
        table.insert(list, 1, table.remove(travel, 1))
    end
    for _, step in ipairs(travel) do
        list[#list + 1] = step
    end
    MarkLevelUp(list)
    return list, mapID, playerX, playerY, later`],
['LevelGuide/LevelGuide.lua', `local function BuildSteps()`, `-- Following the route, which turn-in takes you past the end of this level.
local function MarkLevelUp(list)
    local xp, maxXP = Safe(UnitXP("player")), MaxXP()
    if not (xp and maxXP) then
        return
    end
    local needed = maxXP - xp
    for _, step in ipairs(list) do
        if step.kind == "turnin" and step.xp and step.xp > 0 then
            needed = needed - step.xp
            if needed <= 0 then
                step.dings = true
                return
            end
        end
    end
end

local function ReadyShare(list)
    local total, maxXP = 0, MaxXP()
    for _, step in ipairs(list) do
        if step.kind == "turnin" then
            total = total + (step.xp or 0)
        end
    end
    return maxXP and total > 0 and math.floor(total * 100 / maxXP) or nil
end

local function BuildSteps()`],
// Chores line also mentions quests for later.
['LevelGuide/LevelGuide.lua', `local function ChoresText()
    local parts = {}`, `local function ChoresText(later)
    local parts = {}
    if later and #later > 0 then
        table.sort(later)
        parts[#parts + 1] = string.format("%d quest(s) for level %d+", #later, later[1] - HARD_LEVELS + 1)
    end`],
// Step lines carry tags.
['LevelGuide/LevelGuide.lua', `local function StepLine(step)
    local kind = KINDS[step.kind]
    return kind.color .. kind.label .. ":|r " .. step.title
end`, `local function StepLine(step)
    local kind = KINDS[step.kind]
    local tags = ""
    if step.dings then
        tags = tags .. " |cff33ff33Level up!|r"
    end
    if step.group and step.group > 1 then
        tags = tags .. string.format(" |cffff8040Group %d|r", step.group)
    end
    return kind.color .. kind.label .. ":|r " .. step.title .. tags
end`],
['LevelGuide/LevelGuide.lua', `local function Render(mapID, playerX, playerY)`, `local function Render(mapID, playerX, playerY, later)`],
['LevelGuide/LevelGuide.lua', `        headerText:SetText(string.format("Guide  %sLevel %d, %d%%|r", COLOR_DIM, level, math.floor(xp * 100 / maxXP)))`, `        local ready = ReadyShare(steps)
        local readyText = ready and string.format("  |cff33ff33+%d%% ready to turn in|r", ready) or ""
        headerText:SetText(string.format("Guide  %sLevel %d, %d%%|r%s", COLOR_DIM, level, math.floor(xp * 100 / maxXP), readyText))`],
['LevelGuide/LevelGuide.lua', `    local also = not db.collapsed and ChoresText()`, `    local also = not db.collapsed and ChoresText(later)`],
['LevelGuide/LevelGuide.lua', `    local mapID, playerX, playerY
    steps, mapID, playerX, playerY = BuildSteps()
    currentKey = StepKey(steps[1])
    Render(mapID, playerX, playerY)`, `    local mapID, playerX, playerY, later
    steps, mapID, playerX, playerY, later = BuildSteps()
    currentKey = StepKey(steps[1])
    Render(mapID, playerX, playerY, later)`],
['LevelGuide/LevelGuide.lua', `    if step.detail then
        GameTooltip:AddLine(step.detail, 0.8, 0.8, 0.8, true)
    end`, `    if step.detail then
        GameTooltip:AddLine(step.detail, 0.8, 0.8, 0.8, true)
    end
    local maxXP = MaxXP()
    if step.xp and step.xp > 0 and maxXP then
        GameTooltip:AddLine(string.format("Reward: %d XP (%d%% of a level)", step.xp, math.floor(step.xp * 100 / maxXP)), 0.6, 0.8, 1)
    end`],
];
for (const [file, oldText, newText] of edits) {
    const path = root + '/' + file;
    const raw = fs.readFileSync(path, 'utf8');
    const crlf = raw.includes('\r\n');
    const text = raw.replace(/\r\n/g, '\n');
    const count = text.split(oldText).length - 1;
    if (count !== 1) throw new Error(file + ': matched ' + count + ' times: ' + oldText.slice(0, 70));
    let out = text.replace(oldText, () => newText);
    if (crlf) out = out.replace(/\n/g, '\r\n');
    fs.writeFileSync(path, out);
}
console.log('applied ' + edits.length);
