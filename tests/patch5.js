// Quest IDs in LevelGuide: helper functions, call sites, the merged data file and the .toc.
const fs = require('fs');
const [, , guideDir, idsDir] = process.argv;
const file = guideDir + '/LevelGuide.lua';
let text = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n');
function once(oldText, newText) {
    const count = text.split(oldText).length - 1;
    if (count !== 1) throw new Error('matched ' + count + ': ' + oldText.slice(0, 60));
    text = text.replace(oldText, () => newText);
}
function all(oldText, newText, expected) {
    const count = text.split(oldText).length - 1;
    if (count !== expected) throw new Error('matched ' + count + ' (wanted ' + expected + '): ' + oldText);
    text = text.split(oldText).join(newText);
}
once(`-- Quests done before this addon was installed were never counted,`, `-- Quest IDs (QuestIDs.lua) let the game itself say what this character has finished, including
-- quests done before this addon was installed. Titles Forever renamed are looked up under both names.
local function RealTitle(title)
    local data = LevelGuideQuestIDs
    return data and data.renamed and data.renamed[title] or title
end

local function InLog(byTitle, title)
    return byTitle[title] or byTitle[RealTitle(title)]
end

local function TurnedIn(title)
    local counted = math.max(charData.done[title] or 0, charData.done[RealTitle(title)] or 0)
    local data = LevelGuideQuestIDs
    local ids = data and data.ids and (data.ids[title] or data.ids[RealTitle(title)])
    if ids and C_QuestLog.IsQuestFlaggedCompleted then
        local flagged = 0
        for _, id in ipairs(ids) do
            if Safe(C_QuestLog.IsQuestFlaggedCompleted(id)) then
                flagged = flagged + 1
            end
        end
        counted = math.max(counted, flagged)
    end
    return counted
end

-- Quests done before this addon was installed were never counted,`);
once(`if step.t == "accept" and byTitle[step.q] then`, `if step.t == "accept" and InLog(byTitle, step.q) then`);
once(`if step.t == "accept" and not byTitle[step.q] then`, `if step.t == "accept" and not InLog(byTitle, step.q) then`);
once(`if offers and not offers[step.q] then`, `if offers and not (offers[step.q] or offers[RealTitle(step.q)]) then`);
all(`local turnedIn = charData.done[step.q] or 0`, `local turnedIn = TurnedIn(step.q)`, 2);
all(`local entry = byTitle[step.q]`, `local entry = InLog(byTitle, step.q)`, 2);
once(`local entry = step.q and byTitle[step.q]`, `local entry = step.q and InLog(byTitle, step.q)`);
fs.writeFileSync(file, text.replace(/\n/g, '\r\n'));

// Merge every worker file into one data file.
let out = '-- Forever quest IDs and renamed titles, gathered by research workers from wow4ever.quest\n' +
    '-- (Questie\'s Forever data) and wowhead.com/forever. Each block keeps its own source list.\n' +
    'local parts = {}\n\n';
const files = fs.readdirSync(idsDir).filter(f => f.endsWith('.lua')).sort();
for (const f of files) {
    out += `-- ${f}\nparts[#parts + 1] = (function()\n` + fs.readFileSync(idsDir + '/' + f, 'utf8').replace(/\r\n/g, '\n').trim() + '\nend)()\n\n';
}
out += `LevelGuideQuestIDs = { ids = {}, renamed = {} }
for _, part in ipairs(parts) do
    -- Older worker files are a plain title-to-IDs table; newer ones split ids and renamed.
    local ids = part.ids or part
    for title, list in pairs(ids) do
        if type(list) == "table" then
            LevelGuideQuestIDs.ids[title] = list
        end
    end
    for from, to in pairs(part.renamed or {}) do
        LevelGuideQuestIDs.renamed[from] = to
    end
end
`;
fs.writeFileSync(guideDir + '/QuestIDs.lua', out.replace(/\n/g, '\r\n'));
const toc = guideDir + '/LevelGuide.toc';
let tocText = fs.readFileSync(toc, 'utf8');
if (!tocText.includes('QuestIDs.lua')) tocText = tocText.replace('Routes.lua', 'QuestIDs.lua\r\nRoutes.lua');
fs.writeFileSync(toc, tocText);
console.log('merged ' + files.length + ' ID files: ' + files.join(', '));
