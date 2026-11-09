$h = "C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\harness"
$w = "C:\Users\you\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\scratch-workspaces\c73d4152-ec25-4579-8c12-afe6c58434bb\b2b91152-4cd0-4fba-ac18-3c0d7474a45f\scratch-2026-11-04-2c8855"
Set-Location $h
$map = @{
  "test.lua" = "$w\ForeverHelper\ForeverHelper.lua"
  "test3.lua" = "$w\ItemAdvisor\ItemAdvisor.lua"; "test10.lua" = "$w\ItemAdvisor\ItemAdvisor.lua"
  "test_itemadvisor_extra.lua" = "$w\ItemAdvisor\ItemAdvisor.lua"; "test_itemadvisor_review.lua" = "$w\ItemAdvisor\ItemAdvisor.lua"; "test_itemadvisor_roles.lua" = "$w\ItemAdvisor\ItemAdvisor.lua"
  "test11.lua" = "$w\QuestTracker\QuestTracker.lua"; "test_tracker_extra.lua" = "$w\QuestTracker\QuestTracker.lua"
  "test14.lua" = "$w\LevelGuide\LevelGuide.lua"
  "test15.lua" = "$w\LevelGuide"; "test16.lua" = "$w\LevelGuide"; "test16_pre.lua" = "$w\LevelGuide"; "test17.lua" = "$w\LevelGuide"; "test18.lua" = "$w\LevelGuide"
}
foreach ($t in Get-ChildItem $h -Filter "test*.lua" | Sort-Object Name) {
  $arg = if ($map.ContainsKey($t.Name)) { $map[$t.Name] } else { $w }
  $o = cmd /c "node run.js `"$arg`" $($t.Name) 2>&1"
  $last = ($o | Where-Object { $_ -ne "" } | Select-Object -Last 1)
  "{0}`t{1}`t{2}" -f $t.Name, $LASTEXITCODE, $last
}
