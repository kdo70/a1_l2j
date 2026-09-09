<#
.SYNOPSIS
	Sets the size, offset and particle speed of the enchant glow in weapongrp.dat.

.DESCRIPTION
	Next to the effect's NAME, weapongrp carries the numbers the client builds that effect with -
	where it sits relative to the weapon, how big it is and how fast its particles travel. Retail
	tuned them per weapon, for the retail effect ; EnchantGlow is a different set of effects, so
	those numbers are worth setting again.

	**The layout is not what the ddf says.** l2disasm's Interlude weapongrp.ddf splits the block
	into junk1A[5] / junk1B[5], as if each mesh got five floats of its own. It does not. The client
	writes one ARRAY PER FIELD, as many entries as the weapon has meshes:

	    one mesh  (5 floats)   offX offY offZ | scale | velocity
	    two meshes (10 floats) offX offY offZ offX offY offZ | scale scale | velocity velocity
	                           \--- mesh 0 ---/\--- mesh 1 --/  \-- 0  1 --/  \---- 0   1 ----/

	which is why a fist weapon reads "0 0 0 0 0 0 1 1 1 1" and not "0 0 0 1 1" twice - and why
	junk1A[3] looks like a scale of 0 on every two-mesh weapon while nothing is actually wrong.
	Proved on the table itself: 549 of the 564 two-mesh rows carry exactly that, and rows like
	"0 1 3 0 1 3 1.1 1.1 0.5 0.5" show the two offsets sitting side by side.

	The mesh block (junk2A/junk2B, the retail aura this build no longer draws) is the same shape
	with the fields the other way round: scale first, offset second - "0.8 0.8 0.8 | -0.5 2.8 0"
	on one mesh, both scales then both offsets on two. This script does not touch it.

	Values come from a small table, enchant_glow_tuning.tsv next to this script : one row per
	shape of the ladder, plus "*" for everything and "id:<n>" for a single weapon. Only rows whose
	effect is an EnchantGlow rung are touched - stock and foreign effects keep their own tuning.

	id beats shape beats "*". A table WITHOUT a "*" row is allowed and means "write only the
	weapons named here" : everything else keeps the numbers weapongrp already carries. That is what
	a table of two ids is for - putting neutral zeroes over the other four hundred rows would be
	the opposite of what such a table asks for.

	Same guards as the other dat patchers : l2disasm/l2asm round trip checked byte for byte before
	anything is written, and a rollback copy kept as weapongrp.dat.glowtune.bak.

.PARAMETER SystemDir
	The "system" directory of the client to patch.

.PARAMETER ToolsDir
	Directory holding l2encdec\ and l2asm-disasm\ (the "data" directory of L2 File Editor).

.PARAMETER Tuning
	The table to read. Defaults to enchant_glow_tuning.tsv next to this script.

.PARAMETER ByModel
	Read every "id:" row of the table as standing for the weapon's *look* rather than for that one
	id : its numbers go to every row of weapongrp wearing the same meshes and textures. Which is
	what a table tuned on the cut down client of unique_weapongrp_models.ps1 means - there the ids
	are one per look, and the other two thousand rows of the full table wear those same looks.

	A row that names an id of its own always wins over one it inherits this way. Two tuned ids in
	one look with different numbers is a conflict : the lowest id wins, and it says so.

.PARAMETER Report
	Print what the table holds now, per shape, and change nothing.

.PARAMETER DryRun
	Work out every edit and print the tally, but do not write the dat.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File tools\client\tune_enchant_glow.ps1 `
	    -SystemDir "C:\l2client\system" `
	    -ToolsDir "C:\tools\L2 File Editor\data" -Report
#>
param(
	[Parameter(Mandatory = $true)][string]$SystemDir,
	[Parameter(Mandatory = $true)][string]$ToolsDir,
	[string]$Tuning = '',
	[switch]$ByModel,
	[switch]$Report,
	[switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if ($Tuning -eq '') { $Tuning = Join-Path $PSScriptRoot 'enchant_glow_tuning.tsv' }

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$ddfSrc = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude\weapongrp.ddf'
foreach ($p in $encdec, $disasm, $asm, $ddfSrc) { if (-not (Test-Path $p)) { throw "Missing $p." } }

$GLOW_PACKAGE = 'EnchantGlow'
$INV = [System.Globalization.CultureInfo]::InvariantCulture
$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("glowtune_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

# ---------------------------------------------------------------------------
# The tuning table.
# ---------------------------------------------------------------------------

function Read-Tuning([string]$path)
{
	if (-not (Test-Path $path)) { throw "Missing $path." }
	$t = @{}
	$n = 0
	foreach ($line in [System.IO.File]::ReadAllLines($path))
	{
		$n++
		$s = $line.Trim()
		if ($s -eq '' -or $s.StartsWith('#')) { continue }
		$f = @($s -split '[\s]+')
		if ($f.Count -ne 6) { throw "$path line $n : expected 6 fields (key offX offY offZ scale velocity), got $($f.Count)." }

		$v = New-Object 'double[]' 5
		for ($i = 0; $i -lt 5; $i++)
		{
			$parsed = 0.0
			if (-not [double]::TryParse($f[$i + 1], [Globalization.NumberStyles]::Float, $INV, [ref]$parsed))
			{
				throw "$path line $n : '$($f[$i + 1])' is not a number."
			}
			$v[$i] = $parsed
		}
		if ($t.ContainsKey($f[0])) { throw "$path line $n : '$($f[0])' is in the table twice." }
		$t[$f[0]] = $v
	}
	Write-Host "tuning : $($t.Count) row(s) from $path"
	# No "*" row is a deliberate mode, not a broken table : then only the weapons the table names
	# are written, and everything else keeps whatever weapongrp already carries. Which is the whole
	# point of a table of two ids - flattening the other 400 rows to neutral is the opposite of what
	# is being asked for.
	if (-not $t.ContainsKey('*')) { Write-Host '         no "*" row : rows the table does not name are left as they are' }
	$t
}

# The meshes and textures that make a weapon's look, in table order - the same key
# unique_weapongrp_models.ps1 groups by, so a table tuned on its cut down client lands where it was
# meant to. l2disasm writes only as many cells of an array as the data fills, so a column being
# absent from this table is normal and not a broken ddf.
$MODEL_COLS = @('wpn_mesh[0]', 'wpn_mesh[1]', 'wpn_tex[0]', 'wpn_tex[1]', 'wpn_tex[2]')

# -ByModel : every "id:" row is really about the look that id wears, so hand its numbers to every
# other row wearing it. Rows named in the table keep their own numbers.
function Expand-ByModel($table, $rows, $cols)
{
	$idC = $cols['id']
	$look = @{}          # id -> look
	$wearers = @{}       # look -> ids

	for ($i = 1; $i -lt $rows.Count; $i++)
	{
		$c = $rows[$i].Split("`t")
		$parts = @()
		foreach ($n in $MODEL_COLS) { if ($cols.ContainsKey($n) -and $c[$cols[$n]]) { $parts += $c[$cols[$n]].ToLowerInvariant() } }
		# No mesh and no texture : nothing to look at and nothing to share with, so such a row
		# stands alone rather than joining every other blank one.
		$key = if ($parts.Count -eq 0) { "id:$($c[$idC])" } else { $parts -join '|' }
		$look[$c[$idC]] = $key
		if (-not $wearers.ContainsKey($key)) { $wearers[$key] = [System.Collections.Generic.List[int]]::new() }
		$null = $wearers[$key].Add([int]$c[$idC])
	}

	# Which looks the table actually names, and by which ids.
	$tunedIn = @{}
	foreach ($k in $table.Keys)
	{
		if ($k -notmatch '^id:(\d+)$') { continue }
		$id = $Matches[1]
		if (-not $look.ContainsKey($id)) { Write-Warning "tuning names id $id, which is not in weapongrp ; ignored." ; continue }
		$key = $look[$id]
		if (-not $tunedIn.ContainsKey($key)) { $tunedIn[$key] = [System.Collections.Generic.List[int]]::new() }
		$null = $tunedIn[$key].Add([int]$id)
	}

	$added = 0 ; $clash = 0
	foreach ($key in $tunedIn.Keys)
	{
		# Lowest first : that is the id unique_weapongrp_models.ps1 keeps as a look's stand-in, so
		# it is the row that was actually looked at while the numbers were picked.
		$named = @($tunedIn[$key] | Sort-Object)
		$v = $table["id:$($named[0])"]
		if ($named.Count -gt 1)
		{
			foreach ($other in $named[1..($named.Count - 1)])
			{
				$w = $table["id:$other"]
				if ((0..4 | Where-Object { $v[$_] -ne $w[$_] }).Count -eq 0) { continue }
				Write-Warning "ids $($named[0]) and $other wear the same look but are tuned differently ; $($named[0]) is the one that spreads."
				$clash++
			}
		}
		foreach ($m in $wearers[$key])
		{
			if ($table.ContainsKey("id:$m")) { continue }
			$table["id:$m"] = $v
			$added++
		}
	}

	Write-Host "  -ByModel : $($tunedIn.Count) look(s) named by the table -> $added more row(s) covered$(if ($clash) { ", $clash conflict(s)" })"
	$table
}

# id beats shape beats "*", and no "*" means "leave this row alone" rather than a neutral default.
function Get-Tuning($table, [string]$shape, [int]$id)
{
	if ($table.ContainsKey("id:$id")) { return $table["id:$id"] }
	if ($table.ContainsKey($shape)) { return $table[$shape] }
	$table['*']
}

# ---------------------------------------------------------------------------
# One table in, one table out - the same round trip guard the other patchers use.
# ---------------------------------------------------------------------------

$dat = Join-Path $SystemDir 'weapongrp.dat'
if (-not (Test-Path $dat)) { throw "Missing $dat." }

$dec = Join-Path $tmp 'weapongrp.dec'
$txt = Join-Path $tmp 'weapongrp.txt'
$ddf = Join-Path $tmp 'weapongrp.ddf'

try
{
	& $encdec -d $dat $dec | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $dat." }

	& $disasm -d $ddfSrc -e $ddf $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2disasm failed on weapongrp.' }

	$check = Join-Path $tmp 'weapongrp.check'
	& $asm -d $ddf $txt $check | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed on weapongrp.' }
	if ((Get-FileHash $check).Hash -ne (Get-FileHash $dec).Hash)
	{
		throw "weapongrp : l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?"
	}

	$rows = [System.Collections.Generic.List[string]]::new()
	foreach ($l in [System.IO.File]::ReadAllLines($txt)) { $null = $rows.Add($l) }

	$cols = @{}
	$header = $rows[0].Split("`t")
	for ($i = 0; $i -lt $header.Count; $i++) { $cols[$header[$i]] = $i }
	foreach ($need in 'id', 'wpn_mesh_cnt', 'effA', 'junk1A[0]')
	{
		if (-not $cols.ContainsKey($need)) { throw "weapongrp has no $need column ; wrong ddf ?" }
	}
	$idC = $cols['id']; $mcC = $cols['wpn_mesh_cnt']; $eaC = $cols['effA']; $j1 = $cols['junk1A[0]']
	Write-Host "weapongrp : $($rows.Count - 1) rows, round trip verified"

	# The ten floats of a two-mesh weapon run junk1A[0..4] then junk1B[0..4] in the ddf, and this
	# reads straight through both - they are one block, whatever the ddf calls its halves.
	function Get-Shape([string]$eff)
	{
		if ($eff -notmatch "^$GLOW_PACKAGE\.enchant\d+_(\w+)$") { return '' }
		$Matches[1]
	}

	if ($Report)
	{
		$tally = @{}
		for ($i = 1; $i -lt $rows.Count; $i++)
		{
			$c = $rows[$i].Split("`t")
			$shape = Get-Shape $c[$eaC]
			if ($shape -eq '') { continue }
			$n = [int]$c[$mcC]
			$wide = $(if ($n -eq 2) { 10 } else { 5 })
			$vals = @()
			for ($k = 0; $k -lt $wide; $k++) { $vals += ([double]$c[$j1 + $k]).ToString('0.###', $INV) }
			$key = "$shape`t$($vals -join ' ')"
			$tally[$key] = 1 + $(if ($tally.ContainsKey($key)) { $tally[$key] } else { 0 })
		}
		foreach ($k in ($tally.Keys | Sort-Object))
		{
			$p = $k.Split("`t")
			"{0}  {1,5} row(s)  {2}" -f $p[0], $tally[$k], $p[1]
		}
		return
	}

	$table = Read-Tuning $Tuning
	if ($ByModel) { $table = Expand-ByModel $table $rows $cols }

	$touched = 0
	$left = 0
	$perShape = @{}
	for ($i = 1; $i -lt $rows.Count; $i++)
	{
		$c = $rows[$i].Split("`t")
		$shape = Get-Shape $c[$eaC]
		if ($shape -eq '') { continue }

		$t = Get-Tuning $table $shape ([int]$c[$idC])
		# Nothing in the table covers this weapon and there is no "*" to fall back on : its numbers
		# stay exactly as weapongrp has them.
		if ($null -eq $t) { $left++ ; continue }
		$n = [int]$c[$mcC]

		# offset per mesh, then one scale per mesh, then one velocity per mesh.
		if ($n -eq 2)
		{
			$want = @($t[0], $t[1], $t[2], $t[0], $t[1], $t[2], $t[3], $t[3], $t[4], $t[4])
		}
		else
		{
			$want = @($t[0], $t[1], $t[2], $t[3], $t[4])
		}

		$changed = $false
		for ($k = 0; $k -lt $want.Count; $k++)
		{
			$new = ([double]$want[$k]).ToString('0.00000000', $INV)
			if ($c[$j1 + $k] -ne $new) { $c[$j1 + $k] = $new ; $changed = $true }
		}
		if ($changed) { $rows[$i] = $c -join "`t" ; $touched++ }
		$perShape[$shape] = 1 + $(if ($perShape.ContainsKey($shape)) { $perShape[$shape] } else { 0 })
	}

	foreach ($s in ($perShape.Keys | Sort-Object)) { Write-Host ("  {0} : {1} weapon(s)" -f $s, $perShape[$s]) }
	if ($left) { Write-Host "  $left glowing row(s) the table does not name - left as they are" }
	Write-Host "weapongrp : $touched row(s) retuned"

	if ($DryRun) { Write-Host 'dry run, nothing written' ; return }
	if ($touched -eq 0) { Write-Host 'nothing to write' ; return }

	$new = Join-Path $tmp 'weapongrp.new'
	$enc = Join-Path $tmp 'weapongrp.enc'
	$back = Join-Path $tmp 'weapongrp.back'

	[System.IO.File]::WriteAllText($txt, (($rows -join "`n") + "`n"), $UTF8)

	& $asm -d $ddf $txt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed to rebuild weapongrp.' }

	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2encdec failed to encrypt weapongrp.' }

	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash)
	{
		throw "weapongrp doesn't decrypt back to what was built."
	}

	$bak = "$dat.glowtune.bak"
	if (-not (Test-Path $bak)) { Copy-Item $dat $bak }
	Copy-Item $enc $dat -Force
	Write-Host "wrote $dat (rollback copy $bak)"
}
finally
{
	Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
