param([int[]]$ids, [int]$top = 8, [string]$tab = "dropped-by")
# Reads a Wowhead Classic item page as text and prints the item name and its top "dropped by" NPCs.
foreach ($id in $ids) {
    try {
        $c = (Invoke-WebRequest -UseBasicParsing "https://www.wowhead.com/classic/item=$id" -UserAgent "Mozilla/5.0").Content
    } catch { "$id ERROR $_"; continue }
    $name = ""
    if ($c -match '<title>([^<]*)</title>') { $name = $Matches[1] -replace ' - Item - World of Warcraft Classic.*','' }
    "=== $id $name"
    $i = $c.IndexOf("id: '$tab'")
    if ($i -lt 0) { $i = $c.IndexOf("$tab'") }
    if ($i -lt 0) { "  (no dropped-by)"; continue }
    $j = $c.IndexOf("data: [", $i)
    $k = $c.IndexOf("});", $j)
    $json = $c.Substring($j + 6, $k - $j - 6).Trim()
    $json = $json.TrimEnd(',').Trim()
    try { $arr = $json | ConvertFrom-Json } catch { "  parse fail"; continue }
    $rows = foreach ($n in $arr) {
        $pct = 0; if ($n.outof -gt 0) { $pct = [math]::Round(100.0 * $n.count / $n.outof, 1) }
        [pscustomobject]@{ npc = $n.id; name = $n.name; lvl = "$($n.minlevel)-$($n.maxlevel)"; loc = ($n.location -join ','); pct = $pct; count = $n.count }
    }
    $rows | Where-Object { $_.count -ge 30 } | Sort-Object -Property count -Descending | Select-Object -First $top | Format-Table -AutoSize | Out-String -Width 200
}

