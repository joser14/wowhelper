param([int[]]$ids, [int]$top = 6)
# Reads a Wowhead Classic object page (ore vein / herb) as text and prints the zones with the most spawns,
# each with the centre of its densest cluster.
foreach ($id in $ids) {
    try {
        $c = (Invoke-WebRequest -UseBasicParsing "https://www.wowhead.com/classic/object=$id" -UserAgent "Mozilla/5.0").Content
    } catch { "$id ERROR $_"; continue }
    $name = ""
    if ($c -match '<title>([^<]*)</title>') { $name = $Matches[1] -replace ' - Object - .*','' }
    "=== $id $name"
    $i = $c.IndexOf("g_mapperData = ")
    if ($i -lt 0) { "  (no map data)"; continue }
    $j = $c.IndexOf(";`n", $i)
    $data = $c.Substring($i + 15, $j - $i - 15) | ConvertFrom-Json
    $rows = foreach ($p in $data.PSObject.Properties) {
        foreach ($z in $p.Value) {
            $pts = $z.coords
            $best = $null; $bestN = -1
            foreach ($a in $pts) {
                $n = 0
                foreach ($b in $pts) { if ([math]::Abs($a[0]-$b[0]) -le 8 -and [math]::Abs($a[1]-$b[1]) -le 8) { $n++ } }
                if ($n -gt $bestN) { $bestN = $n; $best = $a }
            }
            $sx = 0; $sy = 0; $k = 0
            foreach ($b in $pts) { if ([math]::Abs($best[0]-$b[0]) -le 8 -and [math]::Abs($best[1]-$b[1]) -le 8) { $sx += $b[0]; $sy += $b[1]; $k++ } }
            [pscustomobject]@{ zone = $z.uiMapName; map = $z.uiMapId; count = $z.count; dense = $k; x = [math]::Round($sx/$k,1); y = [math]::Round($sy/$k,1) }
        }
    }
    $rows | Sort-Object count -Descending | Select-Object -First $top | Format-Table -AutoSize | Out-String -Width 200
}
