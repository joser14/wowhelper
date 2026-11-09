assert(loadfile(ADDON_PATH))()
local titles, renamed = 0, 0
for _ in pairs(LevelGuideQuestIDs.ids) do titles = titles + 1 end
for _ in pairs(LevelGuideQuestIDs.renamed) do renamed = renamed + 1 end
print(titles .. " titles with IDs, " .. renamed .. " renamed")
