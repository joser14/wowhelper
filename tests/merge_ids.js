// Rebuilds LevelGuide/QuestIDs.lua from every worker file, leaving out titles whose ID lists
// don't line up with the route's parts (more IDs than route parts would count steps done early).
const fs = require('fs');
const [, , guideDir, idsDir] = process.argv;
const skip = []; // The Bloodsail Buccaneers was skipped here until Stranglethorn was rebuilt with all 5 Forever parts.
let out = '-- Forever quest IDs and renamed titles, gathered by research workers from wow4ever.quest\n' +
    '-- (Questie\'s Forever data) and wowhead.com/forever. Each block keeps its own source list.\n' +
    'local parts = {}\n\n';
const files = fs.readdirSync(idsDir).filter(f => f.endsWith('.lua')).sort();
for (const f of files) {
    out += `-- ${f}\nparts[#parts + 1] = (function()\n` + fs.readFileSync(idsDir + '/' + f, 'utf8').replace(/\r\n/g, '\n').trim() + '\nend)()\n\n';
}
out += `-- These chains have more quests in Forever than the route has steps, so counting them would
-- mark route steps done too early. They fall back to turn-ins this addon has seen.
local MISMATCHED = { ${skip.map(s => '["' + s.replace(/"/g, '\\"') + '"] = true').join(', ')} }

LevelGuideQuestIDs = { ids = {}, renamed = {} }
for _, part in ipairs(parts) do
    -- Older worker files are a plain title-to-IDs table; newer ones split ids and renamed.
    local ids = part.ids or part
    for title, list in pairs(ids) do
        if type(list) == "table" and not MISMATCHED[title] then
            LevelGuideQuestIDs.ids[title] = list
        end
    end
    for from, to in pairs(part.renamed or {}) do
        LevelGuideQuestIDs.renamed[from] = to
    end
end
`;
fs.writeFileSync(guideDir + '/QuestIDs.lua', out.replace(/\n/g, '\r\n'));
console.log('merged ' + files.length + ' ID files: ' + files.join(', '));
