param([int[]]$ids)
# Reads a Wowhead Classic item page as text and prints who sells it, where, the price and the stock (limited supply).
foreach ($id in $ids) {
    try {
        $c = (Invoke-WebRequest -UseBasicParsing "https://www.wowhead.com/classic/item=$id" -UserAgent "Mozilla/5.0").Content
    } catch { "$id ERROR $_"; continue }
    $name = ""
    if ($c -match '<title>([^<]*)</title>') { $name = $Matches[1] -replace ' - Item - .*','' }
    $i = $c.IndexOf("id: 'sold-by'")
    if ($i -lt 0) { "=== $id $name : not sold"; continue }
    $j = $c.IndexOf("data: [", $i)
    $k = $c.IndexOf("});", $j)
    $json = $c.Substring($j + 6, $k - $j - 6).Trim().TrimEnd(',').Trim()
    "=== $id $name"
    try { $arr = $json | ConvertFrom-Json } catch { "  parse fail: " + $json.Substring(0, [Math]::Min(300, $json.Length)); continue }
    foreach ($n in $arr) { "  npc {0} {1} loc {2} react {3} stock {4} cost {5}" -f $n.id, $n.name, ($n.location -join ','), ($n.react -join ','), $n.stock, ($n.cost | ConvertTo-Json -Compress) }
}
