assert(loadfile(ADDON_PATH .. "/Prereqs.lua"))()
for _, t in ipairs({ "Tenaron's Summons", "Webwood Egg", "Crown of the Earth", "Dolanaar Delivery", "The Woodland Protector" }) do
    local n = LevelGuidePrereqs[t]
    print(t .. ": " .. (n and ("all={" .. table.concat(n.all or {}, ",") .. "} any={" .. table.concat(n.any or {}, ",") .. "} level=" .. tostring(n.level)) or "none"))
end
