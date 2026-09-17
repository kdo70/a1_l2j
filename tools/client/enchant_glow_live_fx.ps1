<#
.SYNOPSIS
	Live editor for the EnchantGlow effects : save an edit file, see the effect change in the running client.

.DESCRIPTION
	Takes the same edit file enchant_glow_fx.ps1 -Apply bakes into EnchantGlow.u, and writes its values straight
	into the memory of the running client instead - into the emitter templates the package loaded AND into the
	emitters of every effect already burning. Save the file, look at the sword ; when it looks right, close the
	client and bake the very same file with enchant_glow_fx.ps1.

	    [enchant17_004t.SpriteEmitter12]
	    StartLocationRange=(X=(Min=-13,Max=13),Y=(Min=-0.4,Max=0.4),Z=(Min=-0.4,Max=0.4))
	    Opacity=0.6

	**How it finds the emitters.** Every object the engine loaded from a package keeps a pointer to that package's
	loader and its export index (_Linker, _LinkerIndex at +0x10 / +0x14), and the index names the emitter in
	EnchantGlow.u exactly. One emitter is found first by its start location bytes, which gives the loader ; every
	other template of the package is then the object carrying that loader and an emitter index. A live effect
	holds copies of the templates (no loader, index -1, same class) ; a copy is matched to its template by the
	fields a copy never changes : start location, lifetime, draw style, texture, spawn rate.

	**Where the fields are.** tools/client/enchant_glow_layout.tsv - the ParticleEmitter / SpriteEmitter /
	MeshEmitter layout computed from the property declarations in the client's engine.u, 0x34 in (the L2 object
	header is 12 bytes longer than stock Unreal's). Checked against a live emitter : ColorScale +0xA8, Opacity
	+0xD0, MaxParticles +0x10C, StartLocationRange +0x158, StartSizeRange +0x2CC, DrawStyle +0x344, Texture
	+0x348, LifetimeRange +0x380, Particles +0x42C, object size 0x500. See docs/enchant-glow.md.

	What a live write cannot do, and the edit file still can once baked :
	- a property left out of a section is not reset - live only writes the lines it is given ;
	- an array (ColorScale, SizeScale...) cannot grow past what the emitter has allocated ;
	- MaxParticles on a burning copy cannot grow past its particle pool - the template takes the new value, and
	  the next effect built from it (re-equip) gets the bigger pool ;
	- a texture or mesh can only be switched to one the client has loaded ;
	- a string (Name) is not written.

	A copy that runs scaled (the weapongrp / live scale doubles particle sizes, say) keeps its ratio : each float
	is written as template value times the ratio the copy had before the write.

	The client runs elevated (L2.exe asks for administrator in its manifest), so this has to as well.

.PARAMETER SystemDir
	The client's system directory. EnchantGlow.u there has to be the package the client loaded.

.PARAMETER Edit
	The edit file to apply, and to watch unless -Once is given.

.PARAMETER Once
	Apply once and exit.

.PARAMETER Show
	Wildcard over emitter paths (enchant17_004t.*) : print what those loaded templates hold right now, in edit
	file syntax, and exit.

.EXAMPLE
	# elevated
	.\enchant_glow_live_fx.ps1 -SystemDir "<client>\system" -Edit .\my_glow.txt
#>
param(
	[string] $SystemDir,
	[string] $Edit,
	[switch] $Once,
	[string] $Show,
	[string] $ProcessName = 'l2'
)

$ErrorActionPreference = 'Stop'
# glow_studio.ps1 dot-sources this file (with -SystemDir) for the process, layout and emitter search, and
# sets this first ; then only the modes at the bottom are skipped.
if (-not $SystemDir) { throw '-SystemDir is required.' }
if (-not $ENCHANT_GLOW_LIVE_LIBRARY -and -not $Edit -and -not $Show) { throw 'Pass -Edit <file> or -Show <emitter wildcard>.' }

$packagePath = Join-Path $SystemDir 'EnchantGlow.u'
$layoutPath = Join-Path $PSScriptRoot 'enchant_glow_layout.tsv'
if (-not (Test-Path $packagePath)) { throw "No $packagePath." }
if (-not (Test-Path $layoutPath)) { throw "No $layoutPath." }
if ($Edit) { $Edit = (Resolve-Path $Edit).Path }

# The reader, the edit file parser and the property schema of enchant_glow_fx.ps1.
$ENCHANT_GLOW_FX_LIBRARY = $true
. (Join-Path $PSScriptRoot 'enchant_glow_fx.ps1')

$HEADER_LINKER = 0x10
$HEADER_LINKER_INDEX = 0x14
$HEADER_CLASS = 0x24
$OBJECT_SIZE = 0x500
$ELEMENT_SIZES = @{ 'ColorScale' = 8; 'SizeScale' = 8; 'VelocityScale' = 16; 'RevolutionScale' = 16 }

# ----------------------------------------------------------------------------------------------- process

function New-Kernel32
{
	$asm = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName 'L2GlowLive'), 'Run')
	$mod = $asm.DefineDynamicModule('M', $false)
	$type = $mod.DefineType('L2GlowLive.K32', 'Public, Class')
	$apis = @(
		@('OpenProcess', [IntPtr], @([int], [bool], [int])),
		@('VirtualQueryEx', [IntPtr], @([IntPtr], [IntPtr], [byte[]], [IntPtr])),
		@('ReadProcessMemory', [bool], @([IntPtr], [IntPtr], [byte[]], [IntPtr], [IntPtr])),
		@('WriteProcessMemory', [bool], @([IntPtr], [IntPtr], [byte[]], [IntPtr], [IntPtr])),
		@('CloseHandle', [bool], @([IntPtr]))
	)
	foreach ($a in $apis)
	{
		$m = $type.DefinePInvokeMethod($a[0], 'kernel32.dll', 'Public, Static, PinvokeImpl', 'Standard', $a[1], $a[2], 'Winapi', 'Auto')
		$m.SetImplementationFlags('PreserveSig')
	}
	return $type.CreateType()
}

$K32 = New-Kernel32
$proc = @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)[0]
if (-not $proc) { throw "No $ProcessName process - start the client first." }
# VM_READ | VM_WRITE | VM_OPERATION | QUERY_INFORMATION
$hProc = $K32::OpenProcess(0x0438, $false, $proc.Id)
if ($hProc -eq [IntPtr]::Zero)
{
	$elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	throw "Cannot open $ProcessName ($($proc.Id)) for writing. This shell is elevated : $elevated - the client runs as administrator, so this has to too."
}

function Read-Mem([long] $addr, [int] $count)
{
	$buf = New-Object byte[] $count
	if (-not $K32::ReadProcessMemory($hProc, [IntPtr]$addr, $buf, [IntPtr]$count, [IntPtr]::Zero)) { return $null }
	return , $buf
}

function Write-Mem([long] $addr, [byte[]] $bytes)
{
	if (-not $K32::WriteProcessMemory($hProc, [IntPtr]$addr, $bytes, [IntPtr]$bytes.Length, [IntPtr]::Zero)) { throw ('WriteProcessMemory failed at 0x{0:X8}.' -f $addr) }
}

function Get-U32([long] $addr) { $b = Read-Mem $addr 4; if (-not $b) { return $null }; return [BitConverter]::ToUInt32($b, 0) }

# Writable committed memory below 2 GB, as (base, bytes) - the client is a 32 bit process.
function Get-Regions
{
	$mbi = New-Object byte[] 48
	$addr = [long]0x10000
	$list = New-Object System.Collections.ArrayList
	while ($addr -lt 0x7FFF0000)
	{
		if ($K32::VirtualQueryEx($hProc, [IntPtr]$addr, $mbi, [IntPtr]48) -eq [IntPtr]::Zero) { break }
		$base = [BitConverter]::ToInt64($mbi, 0)
		$size = [BitConverter]::ToInt64($mbi, 24)
		$state = [BitConverter]::ToInt32($mbi, 32)
		$protect = [BitConverter]::ToInt32($mbi, 36)
		$writable = ($state -eq 0x1000) -and (($protect -band 0xCC) -ne 0) -and (($protect -band 0x100) -eq 0)
		if ($writable -and $size -lt 512MB) { [void]$list.Add(@($base, [int]$size)) }
		$addr = $base + [Math]::Max($size, 4096)
	}
	return , $list
}

$LATIN1 = [Text.Encoding]::GetEncoding(28591)

# Every address in writable memory holding these bytes.
function Find-Bytes([byte[]] $needleBytes, $regions)
{
	$needle = $LATIN1.GetString($needleBytes)
	$hits = New-Object System.Collections.Generic.List[long]
	foreach ($r in $regions)
	{
		$buf = Read-Mem $r[0] $r[1]
		if (-not $buf) { continue }
		$hay = $LATIN1.GetString($buf)
		$at = $hay.IndexOf($needle, [StringComparison]::Ordinal)
		while ($at -ge 0)
		{
			$hits.Add($r[0] + $at)
			$at = $hay.IndexOf($needle, $at + 1, [StringComparison]::Ordinal)
		}
	}
	return , $hits
}

# ----------------------------------------------------------------------------------------------- layout

$LAYOUT = @{}
foreach ($row in (Import-Csv -Path $layoutPath -Delimiter "`t"))
{
	$entry = @{ Offset = [Convert]::ToInt32($row.offset.Substring(2), 16); Type = $row.type; Bit = -1 }
	if ($row.type -match '^bool bit (\d+)$') { $entry.Bit = [int]$Matches[1] }
	$LAYOUT["$($row.class).$($row.property)"] = $entry
}

function Get-Field([string] $class, [string] $name)
{
	if ($LAYOUT.ContainsKey("$class.$name")) { return $LAYOUT["$class.$name"] }
	if ($LAYOUT.ContainsKey("ParticleEmitter.$name")) { return $LAYOUT["ParticleEmitter.$name"] }
	return $null
}

# Raw member layouts of the structs an emitter holds, in memory order.
$MEMORY_STRUCTS = @{
	'Vector'                  = @(@('X', 'f', 0), @('Y', 'f', 4), @('Z', 'f', 8))
	'Rotator'                 = @(@('Pitch', 'i', 0), @('Yaw', 'i', 4), @('Roll', 'i', 8))
	'Color'                   = @(@('B', 'b', 0), @('G', 'b', 1), @('R', 'b', 2), @('A', 'b', 3))
	'Plane'                   = @(@('X', 'f', 0), @('Y', 'f', 4), @('Z', 'f', 8), @('W', 'f', 12))
	'Range'                   = @(@('Min', 'f', 0), @('Max', 'f', 4))
	'RangeVector'             = @(@('X', 'Range', 0), @('Y', 'Range', 8), @('Z', 'Range', 16))
	'ParticleColorScale'      = @(@('RelativeTime', 'f', 0), @('Color', 'Color', 4))
	'ParticleTimeScale'       = @(@('RelativeTime', 'f', 0), @('RelativeSize', 'f', 4))
	'ParticleVelocityScale'   = @(@('RelativeTime', 'f', 0), @('RelativeVelocity', 'Vector', 4))
	'ParticleRevolutionScale' = @(@('RelativeTime', 'f', 0), @('RelativeRevolution', 'Vector', 4))
}
$MEMORY_STRUCT_SIZES = @{ 'Vector' = 12; 'Rotator' = 12; 'Color' = 4; 'Plane' = 16; 'Range' = 8; 'RangeVector' = 24; 'ParticleColorScale' = 8; 'ParticleTimeScale' = 8; 'ParticleVelocityScale' = 16; 'ParticleRevolutionScale' = 16 }

# Fills $buf at $at with a struct value given as (Member=...,...) ; members left out stay as they are in $buf,
# and the offsets of the floats written are recorded in $floats so the scaled copies can keep their ratio.
function Set-StructBytes([byte[]] $buf, [int] $at, [string] $struct, $ast, [string] $what, $floats)
{
	if (-not $MEMORY_STRUCTS.ContainsKey($struct)) { throw "$what : a $struct cannot be written live." }
	if (-not $ast.ContainsKey('Items')) { throw "$what is a $struct and takes (Member=value,...)." }
	$members = @{}
	foreach ($m in $MEMORY_STRUCTS[$struct]) { $members[$m[0]] = $m }
	foreach ($item in $ast.Items)
	{
		if (-not $item.Key -or -not $members.ContainsKey($item.Key)) { throw "$what : $struct has no member '$($item.Key)'." }
		$m = $members[$item.Key]
		$pos = $at + $m[2]
		switch ($m[1])
		{
			'f' { [BitConverter]::GetBytes([single](Convert-Number (Get-Atom $item.Value $what) $what)).CopyTo($buf, $pos); [void]$floats.Add($pos) }
			'i' { [BitConverter]::GetBytes([int](Convert-Number (Get-Atom $item.Value $what) $what)).CopyTo($buf, $pos) }
			'b' { $buf[$pos] = [byte](Convert-Number (Get-Atom $item.Value $what) $what) }
			default { Set-StructBytes $buf $pos $m[1] $item.Value "$what.$($item.Key)" $floats }
		}
	}
}

# ----------------------------------------------------------------------------------------------- package side

$pkg = Read-Package $packagePath
Initialize-Schema $pkg
$emitterExports = @{}
foreach ($e in (Get-Emitters $pkg)) { $emitterExports[$e.Index - 1] = $e }

# What the package itself says for the properties of an export, as the text a section line would carry.
function Get-PackageValues($exp)
{
	$values = @{}
	foreach ($line in (Format-Emitter $pkg $exp))
	{
		if ($line -match '^(\w+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
	}
	return $values
}

function Get-Ast([string] $text)
{
	$tk = @{ T = (Split-Value $text); P = 0 }
	$ast = Read-ValueAst $tk
	if ($tk.P -ne $tk.T.Count) { throw "Trailing text after '$text'." }
	return $ast
}

# The 36 bytes at +0x14C : StartLocationOffset and StartLocationRange as the package gives them.
function Get-LocationFingerprint($exp)
{
	$values = Get-PackageValues $exp
	if (-not $values.ContainsKey('StartLocationRange')) { return $null }
	$buf = New-Object byte[] 36
	$floats = New-Object System.Collections.ArrayList
	if ($values.ContainsKey('StartLocationOffset')) { Set-StructBytes $buf 0 'Vector' (Get-Ast $values['StartLocationOffset']) 'fingerprint' $floats }
	Set-StructBytes $buf 12 'RangeVector' (Get-Ast $values['StartLocationRange']) 'fingerprint' $floats
	$nonZero = $false
	foreach ($b in $buf) { if ($b) { $nonZero = $true; break } }
	if (-not $nonZero) { return $null }
	return , $buf
}

# ----------------------------------------------------------------------------------------------- memory side

$script:Linker = 0
$script:Templates = @{}      # export index (0 based) -> address, emitters only
$script:Loaded = @{}         # export index (0 based) -> address, every loaded object of the package
$script:Regions = $null

# The emitters of the effect in hand, from the cave's report (<system>\enchantglow.state, written by a
# -Live engine build) : the outcome at +12 carries the slot in its upper bits, slot = shape * 7 + rung,
# in the order patch_engine_enchant_glow.ps1 lays the names out. Those are surely loaded, so the loader
# is found on the first scan instead of trying the emitters of the package in turn.
function Get-HeldEffectEmitters
{
	$statePath = Join-Path $SystemDir 'enchantglow.state'
	if (-not (Test-Path $statePath)) { return @() }
	try { $raw = [IO.File]::ReadAllBytes($statePath) } catch { return @() }
	if ($raw.Length -lt 16) { return @() }
	$outcome = [BitConverter]::ToInt32($raw, 12)
	if (($outcome -band 0xFF) -ne 3) { return @() }
	$slot = $outcome -shr 8
	$shapes = @('001t', '002t', '004t', '005t', '006t', '007t', '008t', '010t')
	$rungs = @(4, 7, 10, 12, 14, 15, 17)
	$shape = [int][Math]::Floor($slot / $rungs.Count)
	if ($shape -ge $shapes.Count) { return @() }
	$class = "enchant$($rungs[$slot % $rungs.Count])_$($shapes[$shape])"
	return @($emitterExports.Keys | Where-Object { $pkg.Exports[$pkg.Exports[$_].Outer - 1].Path -eq $class })
}

function Find-Linker([int[]] $preferred)
{
	$preferred = @($preferred) + @(Get-HeldEffectEmitters | Where-Object { $preferred -notcontains $_ })
	# Every try is a full pass over the client's memory (seconds), so the whole package is not tried : the
	# effect in hand and the ones asked for, and a handful of others when neither is known.
	$order = @($preferred)
	if ($order.Count -lt 4) { $order += @($emitterExports.Keys | Where-Object { $preferred -notcontains $_ } | Select-Object -First (4 - $order.Count)) }
	$field = Get-Field 'ParticleEmitter' 'StartLocationOffset'
	foreach ($index in $order)
	{
		$fp = Get-LocationFingerprint $emitterExports[$index]
		if (-not $fp) { continue }
		foreach ($hit in (Find-Bytes $fp $script:Regions))
		{
			$base = $hit - $field.Offset
			$linker = Get-U32 ($base + $HEADER_LINKER)
			$linkerIndex = Get-U32 ($base + $HEADER_LINKER_INDEX)
			if ($linker -and $linkerIndex -eq $index) { return $linker }
		}
	}
	return 0
}

# Every loaded object of the package (textures and meshes too, for pointing a Texture= at them) ; the
# emitters among them are the templates.
function Get-TemplatesOf([long] $linker)
{
	$found = @{}
	$script:Loaded = @{}
	foreach ($hit in (Find-Bytes ([BitConverter]::GetBytes([uint32]$linker)) $script:Regions))
	{
		if (($hit % 4) -ne 0) { continue }
		$base = $hit - $HEADER_LINKER
		$index = Get-U32 ($base + $HEADER_LINKER_INDEX)
		if ($null -eq $index -or $index -ge $pkg.ExportCount) { continue }
		if (-not (Get-U32 ($base + $HEADER_CLASS))) { continue }
		$script:Loaded[[int]$index] = $base
		if ($emitterExports.ContainsKey([int]$index)) { $found[[int]$index] = $base }
	}
	return $found
}

# The effect class a burning copy belongs to : copy -> Owner (the Emitter actor) -> its class, a class the
# loader of the package brought in. @{ Linker ; Index (export of the class) }, or $null.
function Get-CopyEffect([long] $base)
{
	$actor = Get-U32 ($base + (Get-Field 'ParticleEmitter' 'Owner').Offset)
	if (-not $actor) { return $null }
	$cls = Get-U32 ($actor + $HEADER_CLASS)
	if (-not $cls) { return $null }
	$linker = Get-U32 ($cls + $HEADER_LINKER)
	$index = Get-U32 ($cls + $HEADER_LINKER_INDEX)
	if (-not $linker -or $null -eq $index -or $index -ge $pkg.ExportCount) { return $null }
	if ($pkg.Exports[$index].ClassName -ne 'Class') { return $null }
	return @{ Linker = [long]$linker; Index = [int]$index }
}

# Every burning copy of these emitter classes : no loader, index -1.
function Find-BurningCopies([uint32[]] $classPtrs)
{
	$list = New-Object System.Collections.ArrayList
	foreach ($classPtr in $classPtrs)
	{
		foreach ($hit in (Find-Bytes ([BitConverter]::GetBytes([uint32]$classPtr)) $script:Regions))
		{
			if (($hit % 4) -ne 0) { continue }
			$base = $hit - $HEADER_CLASS
			if ((Get-U32 ($base + $HEADER_LINKER)) -ne 0) { continue }
			if ((Get-U32 ($base + $HEADER_LINKER_INDEX)) -ne [uint32]::MaxValue) { continue }
			[void]$list.Add($base)
		}
	}
	return , $list
}

# The loader the burning glow was built from, 0 when nothing burns. A loader of some other package that
# happens to own a class at the same export index is ruled out : it has to hold emitters of that class.
function Find-LiveLinker([uint32[]] $classPtrs)
{
	$keep = $script:Loaded
	$checked = @{}
	try
	{
		foreach ($base in (Find-BurningCopies $classPtrs))
		{
			$owner = Get-CopyEffect $base
			if (-not $owner) { continue }
			if ($owner.Linker -eq $script:Linker) { return $owner.Linker }
			if ($checked.ContainsKey($owner.Linker)) { continue }
			$checked[$owner.Linker] = $true
			$found = Get-TemplatesOf $owner.Linker
			foreach ($index in $found.Keys)
			{
				if ($pkg.Exports[$index].Outer - 1 -eq $owner.Index) { return $owner.Linker }
			}
		}
		return 0
	}
	finally { $script:Loaded = $keep }
}

# The loader is found once per client run and kept in <system>\enchantglow.fxlive : after the first live
# write the start location bytes no longer match the package, so they cannot find it a second time.
function Update-Templates([int[]] $preferred)
{
	$script:Regions = Get-Regions
	$stateFile = Join-Path $SystemDir 'enchantglow.fxlive'
	if (-not $script:Linker -and (Test-Path $stateFile))
	{
		$saved = (Get-Content $stateFile -Raw).Trim() -split '\s+'
		if ($saved.Count -eq 2 -and [int]$saved[0] -eq $proc.Id) { $script:Linker = [long]$saved[1] }
	}
	if ($script:Linker)
	{
		$script:Templates = Get-TemplatesOf $script:Linker
		if (-not $script:Templates.Count) { $script:Linker = 0 }
	}
	if (-not $script:Linker)
	{
		$script:Linker = Find-Linker $preferred
		if (-not $script:Linker) { throw 'The glow in hand is not loaded yet - take a glowing weapon (ALT+1..7 in dev mode) and try again.' }
		$script:Templates = Get-TemplatesOf $script:Linker
		Set-Content -Path $stateFile -Value "$($proc.Id) $($script:Linker)"
	}
	# The client loads EnchantGlow again now and then while it runs : the loader kept from before then holds
	# templates nothing is built from any more, still in memory until they are collected. The burning
	# effects name the loader they came from.
	$classes = @($script:Templates.Values | ForEach-Object { Get-U32 ($_ + $HEADER_CLASS) } | Where-Object { $_ } | Sort-Object -Unique)
	if ($classes.Count -and $classes.Count -le 4)
	{
		$live = Find-LiveLinker $classes
		if ($live -and $live -ne $script:Linker)
		{
			Write-Host ("loader 0x{0:X8} is stale, the burning effects come from 0x{1:X8}" -f $script:Linker, $live)
			$script:Linker = $live
			$script:Templates = Get-TemplatesOf $script:Linker
			Set-Content -Path $stateFile -Value "$($proc.Id) $($script:Linker)"
		}
	}
	Write-Host ("loader 0x{0:X8} : {1} emitter template(s) of EnchantGlow loaded" -f $script:Linker, $script:Templates.Count)
	$media = @($script:Loaded.Keys | ForEach-Object { $pkg.Exports[$_] } | Where-Object { $_.ClassName -in 'Texture', 'StaticMesh' } | ForEach-Object { $_.Path } | Sort-Object)
	Write-Host "loaded textures and meshes : $($media -join ', ')"
}

# The fields a live copy shares with its template no matter how it is scaled. Not Opacity : hiding a layer
# writes it, and a copy built while its template was hidden would no longer match.
$SIGNATURE_FIELDS = @('StartLocationOffset', 'StartLocationRange', 'LifetimeRange', 'InitialParticlesPerSecond', 'DrawStyle', 'Texture')

function Get-Signature([long] $base)
{
	$sb = New-Object System.Text.StringBuilder
	foreach ($name in $SIGNATURE_FIELDS)
	{
		$f = Get-Field 'ParticleEmitter' $name
		$len = 4
		if ($f.Type -eq 'Struct<RangeVector>') { $len = 24 }
		elseif ($f.Type -eq 'Struct<Vector>') { $len = 12 }
		elseif ($f.Type -eq 'Struct<Range>') { $len = 8 }
		elseif ($f.Type -like 'Byte*') { $len = 1 }
		$b = Read-Mem ($base + $f.Offset) $len
		if (-not $b) { return $null }
		[void]$sb.Append([BitConverter]::ToString($b))
	}
	return $sb.ToString()
}

# Live copies of the given templates : same class, no loader, index -1. A copy whose effect is known (its
# Owner) goes to the template of that effect with its class - by signature when the effect has several ;
# one whose effect is not known goes by signature alone. Signatures drift once a field of them is written
# while its copies were not found, which is why the effect comes first.
function Find-Copies([hashtable] $templateAddrs)
{
	$copies = @{}
	$wanted = @{}
	$classes = @{}
	$byEffect = @{}      # "<class export>.<emitter class ptr>" -> template indices
	$sigs = @{}
	foreach ($index in $templateAddrs.Keys)
	{
		$base = $templateAddrs[$index]
		$classPtr = Get-U32 ($base + $HEADER_CLASS)
		$sig = Get-Signature $base
		if ($null -eq $classPtr -or -not $sig) { continue }
		$wanted[$sig] = $index
		$sigs[$index] = $sig
		$classes[[uint32]$classPtr] = $true
		$copies[$index] = New-Object System.Collections.ArrayList
		$key = "$($pkg.Exports[$index].Outer - 1).$classPtr"
		if (-not $byEffect.ContainsKey($key)) { $byEffect[$key] = New-Object System.Collections.ArrayList }
		[void]$byEffect[$key].Add($index)
	}
	foreach ($base in (Find-BurningCopies @($classes.Keys)))
	{
		$sig = Get-Signature $base
		$owner = Get-CopyEffect $base
		$target = $null
		if ($owner -and $owner.Linker -eq $script:Linker)
		{
			$group = $byEffect["$($owner.Index).$(Get-U32 ($base + $HEADER_CLASS))"]
			if ($group)
			{
				if ($group.Count -eq 1) { $target = $group[0] }
				else { foreach ($i in $group) { if ($sigs[$i] -eq $sig) { $target = $i } } }
			}
		}
		elseif (-not $owner -and $sig -and $wanted.ContainsKey($sig)) { $target = $wanted[$sig] }
		if ($null -ne $target) { [void]$copies[$target].Add($base) }
	}
	return $copies
}

# ----------------------------------------------------------------------------------------------- writing

# Writes one edit line into one object ; returns a note when it could not do all of it.
function Write-Line([long] $base, [string] $class, [string] $key, [string] $valueText, [string] $what, [long] $template)
{
	$f = Get-Field $class $key
	if (-not $f) { return "$what : no such field on a $class" }
	$ast = Get-Ast $valueText
	$type = $f.Type
	$addr = $base + $f.Offset

	if ($f.Bit -ge 0)
	{
		$a = Get-Atom $ast $what
		if ($a -notin 'True', 'False') { throw "$what is True or False." }
		$v = [long](Get-U32 $addr)
		$mask = [long]1 -shl $f.Bit
		if ($a -eq 'True') { $v = $v -bor $mask } else { $v = $v -band (0xFFFFFFFFL -bxor $mask) }
		Write-Mem $addr ([BitConverter]::GetBytes([uint32]$v))
		return $null
	}
	switch -Regex ($type)
	{
		'^Float$'
		{
			$value = [single](Convert-Number (Get-Atom $ast $what) $what)
			Write-Scaled $addr ([BitConverter]::GetBytes($value)) @(0) $base $template $f.Offset
			return $null
		}
		'^Int$'
		{
			$value = [int](Convert-Number (Get-Atom $ast $what) $what)
			if ($key -eq 'MaxParticles' -and $base -ne $template)
			{
				$pool = Get-Field 'ParticleEmitter' 'Particles'
				$num = [int](Get-U32 ($base + $pool.Offset + 4))
				if ($value -gt $num) { Write-Mem $addr ([BitConverter]::GetBytes($num)); return "$what : a burning copy has a pool of $num, kept at $num - re-equip for $value" }
			}
			Write-Mem $addr ([BitConverter]::GetBytes($value))
			return $null
		}
		'^Byte'
		{
			$a = Get-Atom $ast $what
			$byte = $null
			if ($ENUMS.ContainsKey($key))
			{
				for ($i = 0; $i -lt $ENUMS[$key].Count; $i++) { if ($ENUMS[$key][$i] -eq $a) { $byte = [byte]$i } }
			}
			if ($null -eq $byte) { $byte = [byte](Convert-Number $a $what) }
			Write-Mem $addr ([byte[]]@($byte))
			return $null
		}
		'^Object<'
		{
			$name = Get-Atom $ast $what
			$ptr = Resolve-LoadedObject $name $key
			if ($null -eq $ptr) { return "$what : $name is not loaded in the client, it cannot be pointed at live" }
			Write-Mem $addr ([BitConverter]::GetBytes([uint32]$ptr))
			return $null
		}
		'^Struct<(\w+)>$'
		{
			$struct = $Matches[1]
			$size = $MEMORY_STRUCT_SIZES[$struct]
			if (-not $size) { return "$what : a $struct cannot be written live" }
			$buf = Read-Mem ($base + $f.Offset) $size
			$floats = New-Object System.Collections.ArrayList
			Set-StructBytes $buf 0 $struct $ast $what $floats
			Write-Scaled $addr $buf @($floats) $base $template $f.Offset
			return $null
		}
		'^Array<'
		{
			if (-not $ELEMENT_SIZES.ContainsKey($key)) { return "$what : this array cannot be written live" }
			if (-not $ast.ContainsKey('Items')) { throw "$what is an array and takes (element,...)." }
			$elementSize = $ELEMENT_SIZES[$key]
			$data = Get-U32 $addr
			$max = [int](Get-U32 ($addr + 8))
			$count = $ast.Items.Count
			if ($count -gt $max -or -not $data) { return "$what : $count element(s) do not fit the $max allocated - bake it" }
			$buf = Read-Mem $data ($elementSize * $count)
			$floats = New-Object System.Collections.ArrayList
			for ($i = 0; $i -lt $count; $i++) { Set-StructBytes $buf ($i * $elementSize) $ARRAY_ELEMENTS[$key] $ast.Items[$i].Value "$what[$i]" $floats }
			Write-Mem $data $buf
			Write-Mem ($addr + 4) ([BitConverter]::GetBytes([int]$count))
			return $null
		}
		default { return "$what : a $type field is not written live" }
	}
}

# A copy keeps the ratio it had to its template before the write, float by float (a scaled weapon doubles
# sizes, for one) ; a template is written as given.
function Write-Scaled([long] $addr, [byte[]] $bytes, $floatOffsets, [long] $base, [long] $template, [int] $fieldOffset)
{
	if ($base -ne $template)
	{
		$old = Read-Mem $addr $bytes.Length
		$tpl = $script:TemplateBefore[$template]
		foreach ($o in $floatOffsets)
		{
			$t = [BitConverter]::ToSingle($tpl, $fieldOffset + $o)
			$c = [BitConverter]::ToSingle($old, $o)
			if ([Math]::Abs($t) -gt 1e-6 -and [Math]::Abs($c - $t) -gt 1e-6)
			{
				$ratio = $c / $t
				[BitConverter]::GetBytes([single]([BitConverter]::ToSingle($bytes, $o) * $ratio)).CopyTo($bytes, $o)
			}
		}
	}
	Write-Mem $addr $bytes
}

# A texture or mesh of the package, if the client has it loaded - it does once any loaded effect uses it.
function Resolve-LoadedObject([string] $name, [string] $key)
{
	$k = $name.ToLowerInvariant()
	if ($pkg.ByPath.ContainsKey($k))
	{
		$index = $pkg.ByPath[$k].Index - 1
		if ($script:Loaded.ContainsKey($index)) { return $script:Loaded[$index] }
	}
	return $null
}

function Invoke-Apply
{
	$sections = Read-EditFile $Edit
	$targets = @()
	foreach ($s in $sections)
	{
		$key = $s.Path.ToLowerInvariant()
		if (-not $pkg.ByPath.ContainsKey($key)) { throw "${Edit}:$($s.Line) : no export $($s.Path) in $packagePath." }
		$targets += ($pkg.ByPath[$key].Index - 1)
	}
	if (-not $script:Templates.Count -or @($targets | Where-Object { -not $script:Templates.ContainsKey($_) }).Count) { Update-Templates $targets }

	$present = @{}
	foreach ($t in $targets) { if ($script:Templates.ContainsKey($t)) { $present[$t] = $script:Templates[$t] } }
	$copies = Find-Copies $present
	$script:TemplateBefore = @{}
	foreach ($t in $present.Keys) { $script:TemplateBefore[$present[$t]] = Read-Mem $present[$t] $OBJECT_SIZE }

	$written = 0; $notes = New-Object System.Collections.ArrayList
	foreach ($s in $sections)
	{
		$exp = $pkg.ByPath[$s.Path.ToLowerInvariant()]
		$index = $exp.Index - 1
		if (-not $present.ContainsKey($index)) { [void]$notes.Add("$($s.Path) : not loaded in the client - skipped"); continue }
		$template = $present[$index]
		$burning = @()
		if ($copies.ContainsKey($index)) { $burning = @($copies[$index]) }
		$objects = $burning + @($template)
		foreach ($base in $objects)
		{
			foreach ($l in $s.Lines)
			{
				$what = "$($s.Path) $($l.Key)"
				try { $note = Write-Line $base $exp.ClassName $l.Key $l.Value $what $template }
				catch { $note = "$what : $($_.Exception.Message)" }
				if ($note -and -not $notes.Contains($note)) { [void]$notes.Add($note) }
			}
		}
		$written++
		Write-Host ("  {0,-34} template 0x{1:X8}, {2} burning cop{3}" -f $s.Path, $template, $burning.Count, $(if ($burning.Count -eq 1) { 'y' } else { 'ies' }))
	}
	foreach ($n in $notes) { Write-Host "  ! $n" }
	Write-Host ("{0:HH:mm:ss} applied {1} section(s)" -f (Get-Date), $written)
}

# ----------------------------------------------------------------------------------------------- modes

if ($ENCHANT_GLOW_LIVE_LIBRARY) { return }

try
{
	Write-Host "client  : $ProcessName pid $($proc.Id)"
	if ($Show)
	{
		$want = @($emitterExports.Keys | Where-Object { $emitterExports[$_].Path -like $Show })
		Update-Templates $want
		foreach ($index in ($want | Sort-Object))
		{
			if (-not $script:Templates.ContainsKey($index)) { continue }
			$exp = $emitterExports[$index]
			$base = $script:Templates[$index]
			Write-Output "[$($exp.Path)]"
			foreach ($name in (Get-PackageValues $exp).Keys | Sort-Object)
			{
				$f = Get-Field $exp.ClassName $name
				if (-not $f) { continue }
				$b = Read-Mem ($base + $f.Offset) 24
				$text = switch -Regex ($f.Type)
				{
					'^bool' { if ((([BitConverter]::ToUInt32($b, 0)) -shr $f.Bit) -band 1) { 'True' } else { 'False' } }
					'^Float$' { Format-Float ([BitConverter]::ToSingle($b, 0)) }
					'^Int$' { [string][BitConverter]::ToInt32($b, 0) }
					'^Byte' { [string]$b[0] }
					'^Struct<Vector>$' { '(X={0},Y={1},Z={2})' -f (Format-Float ([BitConverter]::ToSingle($b, 0))), (Format-Float ([BitConverter]::ToSingle($b, 4))), (Format-Float ([BitConverter]::ToSingle($b, 8))) }
					'^Struct<Range>$' { '(Min={0},Max={1})' -f (Format-Float ([BitConverter]::ToSingle($b, 0))), (Format-Float ([BitConverter]::ToSingle($b, 4))) }
					'^Struct<RangeVector>$' { '(X=(Min={0},Max={1}),Y=(Min={2},Max={3}),Z=(Min={4},Max={5}))' -f @(0..5 | ForEach-Object { Format-Float ([BitConverter]::ToSingle($b, $_ * 4)) }) }
					default { "; $($f.Type) not shown" }
				}
				Write-Output "$name=$text"
			}
			Write-Output ''
		}
		return
	}

	if ($Once) { Invoke-Apply; return }
	# Watching starts even when nothing is loaded yet (no glowing weapon in hand) : the next save tries again.
	try { Invoke-Apply }
	catch { Write-Host "  ! $($_.Exception.Message)" -ForegroundColor Yellow }
	Write-Host "watching $Edit - save it to apply, Ctrl+C to stop"
	$last = (Get-Item $Edit).LastWriteTimeUtc
	while ($true)
	{
		Start-Sleep -Milliseconds 400
		if ($proc.HasExited) { Write-Host 'client closed.'; break }
		$now = (Get-Item $Edit).LastWriteTimeUtc
		if ($now -ne $last)
		{
			$last = $now
			Start-Sleep -Milliseconds 150
			try { Invoke-Apply }
			catch { Write-Host "  ! $($_.Exception.Message)" -ForegroundColor Red }
		}
	}
}
finally { [void]$K32::CloseHandle($hProc) }
