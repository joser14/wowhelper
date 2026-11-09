// Builds LevelGuide/Prereqs.lua from the workers' prerequisite files and adds it to the .toc.
const fs = require('fs');
const [, , guideDir, dir] = process.argv;
let out = '-- Quest prerequisites gathered by research workers from wow4ever.quest (Questie\'s Forever\n' +
    '-- data) and wowhead.com/forever. Each block keeps its own source list.\nlocal parts = {}\n\n';
const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.endsWith('.lua')).sort() : [];
for (const f of files) {
    out += `-- ${f}\nparts[#parts + 1] = (function()\n` + fs.readFileSync(dir + '/' + f, 'utf8').replace(/\r\n/g, '\n').trim() + '\nend)()\n\n';
}
out += `LevelGuidePrereqs = {}
for _, part in ipairs(parts) do
    for title, need in pairs(part) do
        if type(need) == "table" then
            LevelGuidePrereqs[title] = need
        end
    end
end
`;
fs.writeFileSync(guideDir + '/Prereqs.lua', out.replace(/\n/g, '\r\n'));
const toc = guideDir + '/LevelGuide.toc';
let tocText = fs.readFileSync(toc, 'utf8');
if (!tocText.includes('Prereqs.lua')) tocText = tocText.replace('Routes.lua', 'Prereqs.lua\r\nRoutes.lua');
fs.writeFileSync(toc, tocText);
console.log('merged ' + files.length + ' prerequisite files: ' + files.join(', '));
