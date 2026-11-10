# Builds the six installed addons from the helper folders in this repo, and optionally installs them.
#
#   .\build.ps1             -> builds into .\dist
#   .\build.ps1 -Install    -> builds, then installs into the Forever AddOns folder (WoW must be closed)
#
# Each helper keeps its own source folder here (and its own tests). The build copies each helper into
# a subfolder of its bundle and writes one .toc per bundle listing every helper's files in order.
# Every file is still its own Lua chunk, so helpers can't see each other's locals, same as before.
#
# Installing also:
#   - moves the old one-folder-per-helper installs out of AddOns into a dated backup folder next to it
#     (nothing is deleted), so nothing loads twice;
#   - copies each old helper's saved data file into the new bundle's saved data file, once, so
#     settings and history carry over. Old saved files are left where they are.

param([switch]$Install)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Dist = Join-Path $Root 'dist'
$Game = 'C:\Program Files (x86)\World of Warcraft\_forever_'
$AddOns = Join-Path $Game 'Interface\AddOns'
$WTF = Join-Path $Game 'WTF\Account'

# Load order inside a bundle follows this list. "!" makes the hub load before every other addon,
# so the error log can catch problems in addons that load after it.
$Bundles = [ordered]@{
    '!ForeverHub'      = @{ Title = 'Forever Hub'; Notes = 'The Forever window, side panel, pop-ups and error log.'
                            Modules = @('!ErrorLog', 'ForeverHub', 'ForeverHelper') }
    'ForeverGuides'    = @{ Title = 'Forever Guides'; Notes = 'Leveling, profession, gold and dungeon guides.'
                            Modules = @('LevelGuide', 'ProfessionCap', 'ProfessionGuide', 'GoldGoal', 'GoldGuide', 'Dungeons') }
    # Acts: holds a helper that does something in game (AutoQuest), so its notes don't say "Only gives information."
    'ForeverQuests'    = @{ Title = 'Forever Quests'; Acts = $true
                            Notes = 'Quest tracker, quest log checks, zone levels, and accepting and turning in quests at NPCs you talk to (AutoQuest; hold Shift to pause).'
                            Modules = @('QuestTracker', 'QuestCheck', 'ZoneLevels', 'QuestMobs', 'AutoQuest') }
    'ForeverBags'      = @{ Title = 'Forever Bags'; Notes = 'Item advice, bag space, item search, prices, food and supplies, repairs.'
                            Modules = @('ItemAdvisor', 'BagCheck', 'ItemFinder', 'PriceMemory', 'FoodCheck', 'SupplyWatch', 'DurabilityWatch', 'Tooltips', 'WindowBadges') }
    'ForeverCharacter' = @{ Title = 'Forever Character'; Notes = 'Talents, trainer, weapon skills, rested XP, level log, reputation, spell ranks and buffs.'
                            Modules = @('TalentNudge', 'Builds', 'TrainerNotes', 'WeaponSkillWatch', 'RestGuard', 'LevelLog', 'RepWatch', 'ReadyCheck') }
    'ForeverWorld'     = @{ Title = 'Forever World'; Notes = 'Remembered places, death spots and rare alerts.'
                            Modules = @('Landmarks', 'DeathNotes', 'RareWatch', 'MapPins') }
}

function Read-Toc($module) {
    $toc = Join-Path $Root "$module\$module.toc"
    $files = @(); $sv = @(); $svChar = @(); $extra = @()
    foreach ($line in Get-Content $toc) {
        $t = $line.Trim()
        # Header fields that belong to the whole installed addon (the AddOns menu entry and its icon).
        if ($t -match '^##\s*(IconTexture|AddonCompartmentFunc\w*):') { $extra += $t }
        elseif ($t -match '^##\s*SavedVariables:\s*(.+)$') { $sv += ($Matches[1] -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
        elseif ($t -match '^##\s*SavedVariablesPerCharacter:\s*(.+)$') { $svChar += ($Matches[1] -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
        elseif ($t -ne '' -and -not $t.StartsWith('#')) { $files += $t }
    }
    [pscustomobject]@{ Files = $files; SV = $sv; SVChar = $svChar; Extra = $extra }
}

# --- Build ---------------------------------------------------------------------------------------
if (Test-Path $Dist) { Remove-Item -Recurse -Force $Dist }
New-Item -ItemType Directory $Dist | Out-Null
$built = [ordered]@{}
foreach ($name in $Bundles.Keys) {
    $bundle = $Bundles[$name]
    $out = Join-Path $Dist $name
    New-Item -ItemType Directory $out | Out-Null
    $fileLines = @(); $sv = @(); $svChar = @(); $extra = @(); $included = @()
    foreach ($module in $bundle.Modules) {
        if (-not (Test-Path (Join-Path $Root "$module\$module.toc"))) {
            Write-Warning "${name}: helper '$module' isn't in the repo yet, skipped."
            continue
        }
        $info = Read-Toc $module
        New-Item -ItemType Directory (Join-Path $out $module) | Out-Null
        foreach ($file in $info.Files) {
            Copy-Item (Join-Path $Root "$module\$file") (Join-Path $out "$module\$file")
            $fileLines += "$module\$file"
        }
        # Keybindings are only read from the addon's own folder, so they go to the bundle root.
        $bindings = Join-Path $Root "$module\Bindings.xml"
        if (Test-Path $bindings) {
            if (Test-Path (Join-Path $out 'Bindings.xml')) { throw "${name}: two helpers ship Bindings.xml; merge them first." }
            Copy-Item $bindings (Join-Path $out 'Bindings.xml')
        }
        $sv += $info.SV; $svChar += $info.SVChar; $extra += $info.Extra; $included += $module
    }
    $deps = if ($name -eq '!ForeverHub') { '' } else { "## OptionalDeps: !ForeverHub`r`n" }
    $notes = if ($bundle.Acts) { $bundle.Notes } else { "$($bundle.Notes) Only gives information." }
    $toc = "## Interface: 16001`r`n## Title: $($bundle.Title)`r`n## Notes: $notes`r`n## Version: 1.0.0`r`n$deps"
    if ($sv.Count) { $toc += "## SavedVariables: $($sv -join ', ')`r`n" }
    if ($svChar.Count) { $toc += "## SavedVariablesPerCharacter: $($svChar -join ', ')`r`n" }
    foreach ($line in $extra) { $toc += "$line`r`n" }
    $toc += "`r`n" + ($fileLines -join "`r`n") + "`r`n"
    [IO.File]::WriteAllText((Join-Path $out "$name.toc"), $toc, (New-Object Text.UTF8Encoding $false))
    $built[$name] = $included
    Write-Output ("{0}: {1}" -f $name, ($included -join ', '))
}

if (-not $Install) { return }

# --- Install -------------------------------------------------------------------------------------
if (Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^(Wow|WowClassic|WowT|WowB)' }) {
    throw 'WoW is running. Close it first: it rewrites saved data on exit and would undo the move.'
}

# 1. Saved data: old <Helper>.lua files become one <Bundle>.lua per account (and per character for
#    per-character data). Only done when the bundle has no saved file yet, so later installs never
#    overwrite data the new addons have saved since.
$accountDirs = Get-ChildItem $WTF -Directory -ErrorAction SilentlyContinue
foreach ($account in $accountDirs) {
    $dirs = @(Join-Path $account.FullName 'SavedVariables')
    $dirs += Get-ChildItem $account.FullName -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'SavedVariables' -and $_.FullName -ne $dirs[0] } | ForEach-Object { $_.FullName }
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($name in $built.Keys) {
            $target = Join-Path $dir "$name.lua"
            if (Test-Path $target) { continue }
            $parts = @()
            foreach ($module in $built[$name]) {
                $old = Join-Path $dir "$module.lua"
                if (Test-Path $old) { $parts += "-- from $module`r`n" + [IO.File]::ReadAllText($old) }
            }
            if ($parts.Count) {
                [IO.File]::WriteAllText($target, ($parts -join "`r`n"), (New-Object Text.UTF8Encoding $false))
                Write-Output "Saved data carried over: $target ($($parts.Count) helper(s))"
            }
        }
    }
}

# 2. Old one-folder installs move to a backup next to AddOns, so they don't load next to the bundles.
$backup = Join-Path (Split-Path $AddOns) ("AddOns_ForeverBackup_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
foreach ($name in $built.Keys) {
    foreach ($module in $built[$name]) {
        $old = Join-Path $AddOns $module
        if (Test-Path $old) {
            if (-not (Test-Path $backup)) { New-Item -ItemType Directory $backup | Out-Null }
            Move-Item $old (Join-Path $backup $module)
        }
    }
}
if (Test-Path $backup) { Write-Output "Old helper folders moved to $backup" }

# 3. The bundles themselves.
foreach ($name in $built.Keys) {
    $dest = Join-Path $AddOns $name
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    Copy-Item -Recurse (Join-Path $Dist $name) $dest
}
Write-Output "Installed: $($built.Keys -join ', ')"
