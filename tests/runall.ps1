# Runs every test in this folder. Needs Node.js and fengari: run `npm install` here once.
# Prints one line per test (name, exit code, last output line) and exits 1 if any test fails.
$t = $PSScriptRoot
$w = Split-Path $t
if (-not (Test-Path (Join-Path $t 'node_modules\fengari'))) { throw "Run 'npm install' in $t first." }
# Most tests load the whole repo; these take one file or folder instead.
$map = @{
  'test_itemadvisor_extra.lua' = "$w\ItemAdvisor\ItemAdvisor.lua"; 'test_itemadvisor_review.lua' = "$w\ItemAdvisor\ItemAdvisor.lua"
  'test_itemadvisor_roles.lua' = "$w\ItemAdvisor\ItemAdvisor.lua"; 'test_itemadvisor_spellpower.lua' = "$w\ItemAdvisor\ItemAdvisor.lua"
  'test_tracker_extra.lua' = "$w\QuestTracker\QuestTracker.lua"
  'test14.lua' = "$w\LevelGuide\LevelGuide.lua"
  'test_lg_teldrassil.lua' = "$w\LevelGuide"; 'test_lg_side.lua' = "$w\LevelGuide"; 'test_lg_engine.lua' = "$w\LevelGuide"; 'test_lg_route_data.lua' = "$w\LevelGuide"
  'test_lg_legs.lua' = "$w\LevelGuide"; 'test_lg_ne_route.lua' = "$w\LevelGuide"; 'test_lg_20_60.lua' = "$w\LevelGuide"; 'test_lg_faction.lua' = "$w\LevelGuide"; 'test_lg_givers.lua' = "$w\LevelGuide"
  'test16.lua' = "$w\LevelGuide";'test16_pre.lua' = "$w\LevelGuide"; 'test17.lua' = "$w\LevelGuide"; 'test18.lua' = "$w\LevelGuide"
}
Push-Location $t
$failed = 0
try {
  foreach ($f in Get-ChildItem $t -Filter 'test*.lua' | Sort-Object Name) {
    $arg = if ($map.ContainsKey($f.Name)) { $map[$f.Name] } else { $w }
    $o = cmd /c "node run.js `"$arg`" $($f.Name) 2>&1"
    if ($LASTEXITCODE -ne 0) { $failed++ }
    $last = ($o | Where-Object { $_ -ne '' } | Select-Object -Last 1)
    "{0}`t{1}`t{2}" -f $f.Name, $LASTEXITCODE, $last
  }
} finally { Pop-Location }
"{0} failed" -f $failed
if ($failed) { exit 1 }
