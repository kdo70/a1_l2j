<#
.SYNOPSIS
	Cuts weapongrp.dat down to the weapons that glow with one EnchantGlow shape, and puts the full table
	back afterwards with the glow tuned on the cut one.

.DESCRIPTION
	For tuning one shape in game without the other two thousand rows in the way : only the rows whose
	effA or effB is EnchantGlow.enchant<rung>_<shape> stay. The full table goes to
	weapongrp.dat.shape.bak first, and a cut is refused while that backup exists - the second cut would
	save a cut table over the full one.

	-Restore takes the full table from the backup, and for every id of the cut table carries over the
	offset block junk1A[0..4] / junk1B[0..4] - the numbers restore_glow_offsets.ps1 works on. Everything
	else comes from the backup as it was, effA / effB included : the cut may have dealt the rung names
	out anew. The backup is then renamed to weapongrp.dat.shape.<time>.bak, so the next cut can run.

	Tuning that went into enchant_glow_tuning.tsv (ALT+S / ALT+D of tune_glow_keys.ps1) is not in the dat
	at all : after -Restore, apply it with tune_enchant_glow.ps1.

	The client has to be closed. Both ways the l2disasm/l2asm round trip is checked byte for byte and the
	written file is read back.

.PARAMETER Shape
	The EnchantGlow shape to keep : 001t, 002t, 004t, 005t, 006t, 007t, 008t.

.PARAMETER UniqueByTexture
	Keep one row per look instead of every row : a look is the textures and weapon_type, the key
	tune_enchant_glow.ps1 -ByTexture spreads an "id:" row of enchant_glow_tuning.tsv with. The row kept
	is the id the tuning table already names for that look (the lowest, if it names several), or else
	the lowest id - so ALT+D of tune_glow_keys.ps1 saves under the id the numbers will spread from.
	After -Restore, run tune_enchant_glow.ps1 -ByTexture to hand the tuning to the rest of each look.

.PARAMETER Recut
	The table is already cut : cut again, from the full table in the backup. Whatever was tuned in the
	cut dat itself is dropped (the tuning table is not touched).

.EXAMPLE
	.\cut_weapongrp_shape.ps1 -SystemDir "C:\Users\Me\Desktop\1\system" -ToolsDir "<L2 File Editor>\data" -Shape 004t

.EXAMPLE
	.\cut_weapongrp_shape.ps1 -SystemDir "C:\Users\Me\Desktop\1\system" -ToolsDir "<L2 File Editor>\data" -Restore
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)][string] $SystemDir,
	[Parameter(Mandatory = $true)][string] $ToolsDir,
	[ValidatePattern('^\d{3}t$')][string] $Shape = '004t',
	[switch] $UniqueByTexture,
	[switch] $Recut,
	[switch] $Restore,
	[string] $Tuning
)
if (-not $Tuning) { $Tuning = Join-Path $PSScriptRoot 'enchant_glow_tuning.tsv' }

$ErrorActionPreference = 'Stop'

$encdec = Join-Path $ToolsDir 'l2encdec\l2encdec.exe'
$disasm = Join-Path $ToolsDir 'l2asm-disasm\l2disasm.exe'
$asm = Join-Path $ToolsDir 'l2asm-disasm\l2asm.exe'
$ddfSrc = Join-Path $ToolsDir 'l2asm-disasm\DAT_defs\Interlude\weapongrp.ddf'
foreach ($p in $encdec, $disasm, $asm, $ddfSrc) { if (-not (Test-Path $p)) { throw "Missing $p." } }

$dat = Join-Path $SystemDir 'weapongrp.dat'
$backup = Join-Path $SystemDir 'weapongrp.dat.shape.bak'
if (-not (Test-Path $dat)) { throw "Missing $dat." }
if (Get-Process -Name 'l2' -ErrorAction SilentlyContinue) { throw 'The client is running - close it first.' }

# What tuning the glow touches, by column name : the offset block. Not effA / effB - the cave writes the
# rung into them anyway, and a cut may have dealt the rung names out anew, which the full table must
# not inherit or a rung could lose its last row there.
$GLOW_COLS = @(0..4 | ForEach-Object { "junk1A[$_]" }) + @(0..4 | ForEach-Object { "junk1B[$_]" })

$UTF8 = New-Object System.Text.UTF8Encoding $false
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("wgshape_" + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $tmp

function Open-Table([string] $file, [string] $tag)
{
	$dec = Join-Path $tmp "$tag.dec"
	$txt = Join-Path $tmp "$tag.txt"
	$exp = Join-Path $tmp "$tag.ddf"
	$chk = Join-Path $tmp "$tag.check"
	& $encdec -d $file $dec | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "Can't decrypt $file." }
	& $disasm -d $ddfSrc -e $exp $dec $txt | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2disasm failed on $file." }
	& $asm -d $exp $txt $chk | Out-Null
	if ($LASTEXITCODE -ne 0) { throw "l2asm failed on $file." }
	if ((Get-FileHash $chk).Hash -ne (Get-FileHash $dec).Hash) { throw "$file : l2disasm/l2asm round trip isn't byte exact ; wrong ddf for this client ?" }
	$lines = [System.IO.File]::ReadAllLines($txt)
	$header = $lines[0].Split("`t")
	$col = @{}
	for ($i = 0; $i -lt $header.Count; $i++) { $col[$header[$i]] = $i }
	foreach ($n in @('id', 'effA', 'effB') + $GLOW_COLS) { if (-not $col.ContainsKey($n)) { throw "$file has no $n column ; wrong ddf ?" } }
	[pscustomobject]@{ Lines = $lines ; Col = $col ; Ddf = $exp }
}

# Reassemble, encrypt, check it decrypts back, write it, and read what was written.
function Save-Table($rows, [string] $ddf, [string] $target, [int] $expectRows)
{
	$txt = Join-Path $tmp 'out.txt'
	$new = Join-Path $tmp 'out.new'
	$enc = Join-Path $tmp 'out.enc'
	$back = Join-Path $tmp 'out.back'
	[System.IO.File]::WriteAllText($txt, (($rows -join "`n") + "`n"), $UTF8)
	& $asm -d $ddf $txt $new | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2asm failed to rebuild weapongrp.' }
	& $encdec -e 413 $new $enc | Out-Null
	if ($LASTEXITCODE -ne 0) { throw 'l2encdec failed to encrypt weapongrp.' }
	& $encdec -d $enc $back | Out-Null
	if ($LASTEXITCODE -ne 0 -or (Get-FileHash $back).Hash -ne (Get-FileHash $new).Hash) { throw "weapongrp doesn't decrypt back to what was built." }
	Copy-Item -LiteralPath $enc -Destination $target -Force
	$check = Open-Table $target 'written'
	if ($check.Lines.Count - 1 -ne $expectRows) { throw "$target reads back with $($check.Lines.Count - 1) rows, $expectRows were written." }
}

try
{
	if ($Restore)
	{
		if (-not (Test-Path $backup)) { throw "No $backup - nothing was cut." }
		$full = Open-Table $backup 'full'
		$cut = Open-Table $dat 'cut'

		$tuned = @{}
		foreach ($line in ($cut.Lines | Select-Object -Skip 1))
		{
			$c = $line.Split("`t")
			$tuned[$c[$cut.Col['id']]] = $c
		}
		$rows = New-Object System.Collections.Generic.List[string]
		$rows.Add($full.Lines[0])
		$carried = 0
		$changed = 0
		foreach ($line in ($full.Lines | Select-Object -Skip 1))
		{
			$c = $line.Split("`t")
			$id = $c[$full.Col['id']]
			if ($tuned.ContainsKey($id))
			{
				$from = $tuned[$id]
				$diff = $false
				foreach ($n in $GLOW_COLS)
				{
					$v = $from[$cut.Col[$n]]
					if ($c[$full.Col[$n]] -ne $v) { $c[$full.Col[$n]] = $v ; $diff = $true }
				}
				$carried++
				if ($diff) { $changed++ }
				$tuned.Remove($id)
			}
			$rows.Add($c -join "`t")
		}
		if ($tuned.Count) { throw "the cut table has $($tuned.Count) id(s) the backup has not : $(@($tuned.Keys | Select-Object -First 10) -join ', ') - not restoring." }
		Save-Table $rows $full.Ddf $dat ($full.Lines.Count - 1)
		$kept = $backup -replace '\.bak$', ".$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
		Move-Item -LiteralPath $backup -Destination $kept
		Write-Host "restored $dat : $($full.Lines.Count - 1) rows, glow carried over for $carried, of them $changed changed"
		Write-Host "the full table as it was before : $kept"
		return
	}

	if (Test-Path $backup)
	{
		if (-not $Recut) { throw "$backup exists - the table is already cut. Run -Restore first, or -Recut." }
		$full = Open-Table $backup 'full'
	}
	else
	{
		if ($Recut) { throw "No $backup - the table is not cut, -Recut has nothing to cut from." }
		$full = Open-Table $dat 'full'
	}
	$rx = "^EnchantGlow\.enchant\d+_$Shape$"
	$names = @{}
	$picked = New-Object System.Collections.Generic.List[object]
	foreach ($line in ($full.Lines | Select-Object -Skip 1))
	{
		$c = $line.Split("`t")
		$hit = $false
		foreach ($n in 'effA', 'effB')
		{
			$v = $c[$full.Col[$n]]
			if ($v -match $rx) { $hit = $true ; $names[$v.ToLowerInvariant()] = $true }
		}
		if ($hit) { $picked.Add(@{ Id = [int]$c[$full.Col['id']]; Cells = $c; Line = $line }) }
	}
	if (-not $picked.Count) { throw "no row of $dat glows with _$Shape." }

	$keep = $picked
	if ($UniqueByTexture)
	{
		# the ids the tuning table names, so that a look keeps the id its numbers are filed under
		$named = @{}
		if (Test-Path $Tuning)
		{
			foreach ($t in [System.IO.File]::ReadAllLines($Tuning)) { if ($t -match '^\s*id:(\d+)\s') { $named[[int]$Matches[1]] = $true } }
		}
		# the -ByTexture key of tune_enchant_glow.ps1 : textures, then weapon_type
		$lookCols = @('wpn_tex[0]', 'wpn_tex[1]', 'wpn_tex[2]', 'weapon_type')
		$byLook = [ordered]@{}
		foreach ($p in $picked)
		{
			$parts = @()
			foreach ($n in $lookCols) { if ($full.Col.ContainsKey($n) -and $p.Cells[$full.Col[$n]]) { $parts += $p.Cells[$full.Col[$n]].ToLowerInvariant() } }
			$key = if ($parts.Count) { $parts -join '|' } else { "id:$($p.Id)" }
			if (-not $byLook.Contains($key)) { $byLook[$key] = New-Object System.Collections.Generic.List[object] }
			$byLook[$key].Add($p)
		}
		$keep = New-Object System.Collections.Generic.List[object]
		$fromTable = 0
		foreach ($key in $byLook.Keys)
		{
			$group = @($byLook[$key] | Sort-Object { $_.Id })
			$rep = @($group | Where-Object { $named.ContainsKey($_.Id) } | Select-Object -First 1)
			if ($rep.Count) { $fromTable++ } else { $rep = @($group[0]) }
			$keep.Add($rep[0])
		}
		$keep = @($keep | Sort-Object { $_.Id })
		Write-Host "$($picked.Count) row(s) glow with _$Shape, $($byLook.Count) look(s) by textures and weapon_type ; $fromTable of the kept ids are already in $Tuning"
	}

	# Every rung has to be named somewhere in the dat, or it does not draw. A unique cut can lose some,
	# so the names are dealt round robin over the kept rows - the engine writes the rung it wants into
	# the field anyway, the name only has to be one of the shape's (see patch_client.ps1).
	$rungNames = @($names.Keys | Sort-Object { [int]([regex]::Match($_, 'enchant(\d+)_').Groups[1].Value) })
	$kept = @{}
	foreach ($p in $keep) { foreach ($n in 'effA', 'effB') { if ($p.Cells[$full.Col[$n]] -match $rx) { $kept[$p.Cells[$full.Col[$n]].ToLowerInvariant()] = $true } } }
	if ($kept.Count -lt $rungNames.Count -and $keep.Count -ge $rungNames.Count)
	{
		$i = 0
		foreach ($p in $keep)
		{
			$name = $rungNames[$i % $rungNames.Count]
			foreach ($n in 'effA', 'effB') { if ($p.Cells[$full.Col[$n]] -match $rx) { $p.Cells[$full.Col[$n]] = $name -replace '^enchantglow\.', 'EnchantGlow.' } }
			$i++
		}
		Write-Host "rung names dealt round robin over the kept rows : $($kept.Count) of $($rungNames.Count) were left by the cut"
	}

	$rows = New-Object System.Collections.Generic.List[string]
	$rows.Add($full.Lines[0])
	# the table's own order, not the id order
	$keepIds = @{}
	foreach ($p in $keep) { $keepIds[$p.Id] = $true }
	foreach ($p in $picked) { if ($keepIds.ContainsKey($p.Id)) { $rows.Add($p.Cells -join "`t") } }
	if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $dat -Destination $backup }
	Save-Table $rows $full.Ddf $dat ($rows.Count - 1)
	Write-Host "cut $dat : $($full.Lines.Count - 1) -> $($rows.Count - 1) rows glowing with _$Shape"
	Write-Host "ids kept : $(@($keep | ForEach-Object { $_.Id }) -join ' ')"
	# rung names that are left : a unique cut can drop some, and a rung whose name is not in the dat does not draw
	$names = @{}
	foreach ($r in ($rows | Select-Object -Skip 1))
	{
		$c = $r.Split("`t")
		foreach ($n in 'effA', 'effB') { if ($c[$full.Col[$n]] -match $rx) { $names[$c[$full.Col[$n]].ToLowerInvariant()] = $true } }
	}
	Write-Host "rung names in the cut table : $(@($names.Keys | Sort-Object) -join ', ')"
	# The client only draws a rung whose name was in a dat when it loaded - see docs/enchant-glow.md.
	if ($names.Count -lt 7) { Write-Warning "only $($names.Count) of the 7 rungs of _$Shape are named in the cut table ; the others will not draw." }
	Write-Host "full table kept as $backup ; put it back with -Restore"
}
finally
{
	Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
