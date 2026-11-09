param([int[]]$ids)
# Reads a Wowhead Classic NPC page as text and prints, per zone, the spawn count and the centre of the densest cluster.
foreach ($id in $ids) {
    try {
        $c = (Invoke-WebRequest -UseBasicParsing "https://www.wowhead.com/classic/npc=$id" -UserAgent "Mozilla/5.0").Content
    } catch { "$id ERROR $_"; continue }
    $name = ""
    if ($c -match '<title>([^<]*)</title>') { $name = $Matches[1] -replace ' - NPC - .*','' }
    $lvl = ""
    if ($c -match 'Level: ([0-9 \-]+)') { $lvl = $Matches[1] }
    $i = $c.IndexOf("g_mapperData = ")
    if ($i -lt 0) { "$id $name (no map data)"; continue }
    $j = $c.IndexOf(";`n", $i)
    $json = $c.Substring($i + 15, $j - $i - 15)
    $data = $json | ConvertFrom-Json
    foreach ($p in $data.PSObject.Properties) {
        foreach ($z in $p.Value) {
            $pts = $z.coords
            $best = $null; $bestN = -1
            foreach ($a in $pts) {
                $n = 0
                foreach ($b in $pts) { if ([math]::Abs($a[0]-$b[0]) -le 4 -and [math]::Abs($a[1]-$b[1]) -le 4) { $n++ } }
                if ($n -gt $bestN) { $bestN = $n; $best = $a }
            }
            $sx = 0; $sy = 0; $k = 0
            foreach ($b in $pts) { if ([math]::Abs($best[0]-$b[0]) -le 4 -and [math]::Abs($best[1]-$b[1]) -le 4) { $sx += $b[0]; $sy += $b[1]; $k++ } }
            "{0} {1} [{2}] {3} map{4}: {5} spawns, densest {6} at {7:N1},{8:N1}" -f $id, $name, $lvl, $z.uiMapName, $z.uiMapId, $z.count, $k, ($sx/$k), ($sy/$k)
        }
    }
}
