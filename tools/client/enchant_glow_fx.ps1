<#
.SYNOPSIS
	Reads the particle effects of EnchantGlow.u out as text, and writes edited text back into the package.

.DESCRIPTION
	Every effect of EnchantGlow.u is a class (enchant17_004t) holding a handful of emitter subobjects
	(enchant17_004t.SpriteEmitter10, ...MeshEmitter47). An emitter is nothing but a tagged property list -
	where the particles are born, how many, how big, what colour over their life, which texture - and that
	list is what this script turns into text and back:

	    [enchant17_004t.SpriteEmitter10]
	    ; SpriteEmitter
	    MaxParticles=30
	    StartLocationOffset=(X=10,Y=0,Z=0)
	    StartLocationRange=(X=(Min=-1.13,Max=13.6),Y=(Min=-0.5,Max=0.5),Z=(Min=-0.5,Max=0.5))
	    ColorScale=((RelativeTime=0,Color=(B=21,G=189,R=185,A=255)),(RelativeTime=1,Color=(B=255,G=139,R=77,A=255)))
	    DrawStyle=PTDS_AlphaBlend
	    Texture=fx_m_t6292

	A section is the WHOLE property list of its emitter : a property left out of it is dropped from the
	emitter, which then falls back to the engine default. Emitters with no section are not touched.

	**How the package survives the edit.** Textures keep absolute file offsets of their mip data inside
	(TLazyArray), so no texture may move - see docs/enchant-glow.md. An emitter that comes out the same size
	is written back in place ; one that grew or shrank is appended after the last export data, and only its
	row of the export table changes. The import and export tables sit behind all export data in this package,
	so they are simply written again behind the appended blobs. A name the edit needs and the package lacks
	(a property it never used, like StartLocationShape) moves the name table to the end as well. Nothing that
	holds a texture, a mesh or a class is ever moved, and the script checks that before it writes.

	Always apply against the untouched package (EnchantGlow.u.plain.bak) : an edit file carries only the
	emitters it changes, so applying it to the pristine package is repeatable, while applying it again and
	again to its own output only piles up dead blobs.

.PARAMETER Package
	The package to read. Stays untouched unless -OutFile is left out on -Apply.

.PARAMETER List
	Lists every effect class and its emitters with the few properties that tell them apart.

.PARAMETER Export
	Wildcard over effect class names (enchant17_004t, enchant*_004t, *). Writes the emitters of the matching
	classes as text, to -OutFile or to the console.

.PARAMETER Apply
	Text file of sections to write into the package.

.PARAMETER OutFile
	Where -Export writes the text and -Apply writes the package. -Apply without it rewrites -Package in place,
	keeping <package>.fx.bak the first time.

.PARAMETER SelfTest
	Turns every emitter of the package into text and back and demands the same bytes, then rebuilds the whole
	package with no edits and demands the same file. Run it before trusting the script on another package.

.EXAMPLE
	.\enchant_glow_fx.ps1 -Package "<client>\system\EnchantGlow.u.plain.bak" -Export enchant17_004t -OutFile fire.txt
	# ... edit fire.txt ...
	.\enchant_glow_fx.ps1 -Package "<client>\system\EnchantGlow.u.plain.bak" -Apply fire.txt -OutFile "<client>\system\EnchantGlow.u"
#>
param(
	[string] $Package,
	[switch] $List,
	[string] $Export,
	[string] $Apply,
	[string] $OutFile,
	[switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
# enchant_glow_live_fx.ps1 dot-sources this file for its reader, parser and schema, and sets this first.
if (-not $ENCHANT_GLOW_FX_LIBRARY)
{
	if (-not $Package) { throw '-Package is required.' }
	if (-not (Test-Path $Package)) { throw "No such file: $Package" }
	$Package = (Resolve-Path $Package).Path
}

$INV = [Globalization.CultureInfo]::InvariantCulture
$UTF8 = New-Object System.Text.UTF8Encoding $false

# Classes whose exports are a bare tagged property list, and so can be edited as text.
$EMITTER_CLASSES = @('SpriteEmitter', 'MeshEmitter', 'BeamEmitter', 'SparkEmitter', 'ParticleEmitter')

# Structs the engine serializes natively, member by member, instead of as a tagged list.
$RAW_STRUCTS = @{
	'Vector'  = @(@('X', 'f'), @('Y', 'f'), @('Z', 'f'))
	'Rotator' = @(@('Pitch', 'i'), @('Yaw', 'i'), @('Roll', 'i'))
	'Color'   = @(@('B', 'b'), @('G', 'b'), @('R', 'b'), @('A', 'b'))
}

# Properties EnchantGlow.u never writes but LineageEffect.u does, with the tags it writes them with - so an
# edit can add them. Type : 1 byte, 2 int, 3 bool, 4 float, 9 array, 10 struct.
$EXTRA_PROPS = @{
	'StartLocationShape'          = @(1, $null)
	'SphereRadiusRange'           = @(10, 'Range')
	'InitialDelayRange'           = @(10, 'Range')
	'InitialTimeRange'            = @(10, 'Range')
	'CoordinateSystem'            = @(1, $null)
	'UseRotationFrom'             = @(1, $null)
	'RotationNormal'              = @(10, 'Vector')
	'MaxAbsVelocity'              = @(10, 'Vector')
	'UseVelocityScale'            = @(3, $null)
	'VelocityScale'               = @(9, $null)
	'VelocityScaleRepeats'        = @(4, $null)
	'UseRevolutionScale'          = @(3, $null)
	'RevolutionScale'             = @(9, $null)
	'RevolutionScaleRepeats'      = @(4, $null)
	'RespawnDeadParticles'        = @(3, $null)
	'ResetAfterChange'            = @(3, $null)
	'ForcedMaxParticles'          = @(3, $null)
	'AutoDestroy'                 = @(3, $null)
	'Disabled'                    = @(3, $null)
	'ZWrite'                      = @(3, $null)
	'ZTest'                       = @(3, $null)
	'UseActorForces'              = @(3, $null)
	'SecondsBeforeInactive'       = @(4, $null)
	'AddLocationFromOtherEmitter' = @(2, $null)
	'AddVelocityFromOtherEmitter' = @(2, $null)
	'MeshSpawning'                = @(1, $null)
}
$EXTRA_MEMBERS = @{
	'Range.Min'                                  = @(4, $null)
	'Range.Max'                                  = @(4, $null)
	'ParticleVelocityScale.RelativeTime'         = @(4, $null)
	'ParticleVelocityScale.RelativeVelocity'     = @(10, 'Vector')
	'ParticleRevolutionScale.RelativeTime'       = @(4, $null)
	'ParticleRevolutionScale.RelativeRevolution' = @(10, 'Vector')
}

# What the elements of a dynamic array are. A tag says "array", never of what.
$ARRAY_ELEMENTS = @{
	'ColorScale'      = 'ParticleColorScale'
	'SizeScale'       = 'ParticleTimeScale'
	'VelocityScale'   = 'ParticleVelocityScale'
	'RevolutionScale' = 'ParticleRevolutionScale'
	'CustomMaterials' = '#object'
}

# Byte properties that are enums, with the value lists read out of the client's engine.u.
$ENUMS = @{
	'DrawStyle'                = @('PTDS_Regular', 'PTDS_AlphaBlend', 'PTDS_Modulated', 'PTDS_Translucent', 'PTDS_AlphaModulate_MightNotFogCorrectly', 'PTDS_Darken', 'PTDS_Brighten')
	'UseDirectionAs'           = @('PTDU_None', 'PTDU_Up', 'PTDU_Right', 'PTDU_Forward', 'PTDU_Normal', 'PTDU_UpAndNormal', 'PTDU_RightAndNormal', 'PTDU_Scale')
	'StartLocationShape'       = @('PTLS_Box', 'PTLS_Sphere', 'PTLS_Polar', 'PTLS_All')
	'GetVelocityDirectionFrom' = @('PTVD_None', 'PTVD_StartPositionAndOwner', 'PTVD_OwnerAndStartPosition', 'PTVD_AddRadial')
	'MeshSpawning'             = @('PTMS_None', 'PTMS_Linear', 'PTMS_Random')
	'EffectAxis'               = @('PTEA_NegativeX', 'PTEA_PositiveZ')
	'UseRotationFrom'          = @('PTRS_None', 'PTRS_Actor', 'PTRS_Offset', 'PTRS_Normal')
	'CoordinateSystem'         = @('PTCS_Independent', 'PTCS_Relative', 'PTCS_Absolute', 'PTCS_RelativeRotation', 'PTCS_Spray')
	'UseSkeletalLocationAs'    = @('PTSU_None', 'PTSU_SpawnOffset', 'PTSU_Location')
	'UseCollisionSound'        = @('PTSC_None', 'PTSC_LinearGlobal', 'PTSC_LinearLocal', 'PTSC_Random')
}

$T_BYTE = 1; $T_INT = 2; $T_BOOL = 3; $T_FLOAT = 4; $T_OBJECT = 5; $T_NAME = 6
$T_CLASS = 8; $T_ARRAY = 9; $T_STRUCT = 10

# ----------------------------------------------------------------------------------------------- bytes

function Read-U8($r) { $v = [int]$r.B[$r.P]; $r.P += 1; return $v }
function Read-I32($r) { $v = [BitConverter]::ToInt32($r.B, $r.P); $r.P += 4; return $v }

# Unreal's compact index : sign in bit 7 and 6 value bits in the first byte, 7 bits in each next one.
function Read-CIdx($r)
{
	$b0 = Read-U8 $r
	$v = $b0 -band 0x3F
	if ($b0 -band 0x40)
	{
		$shift = 6
		do
		{
			$c = Read-U8 $r
			$v = $v -bor (($c -band 0x7F) -shl $shift)
			$shift += 7
		} while (($c -band 0x80) -and $shift -lt 32)
	}
	if ($b0 -band 0x80) { return -$v }
	return $v
}

function Get-CIdxBytes([int] $value)
{
	$out = New-Object System.Collections.Generic.List[byte]
	$v = [long][Math]::Abs([long]$value)
	$b0 = [int]($v -band 0x3F)
	if ($value -lt 0) { $b0 = $b0 -bor 0x80 }
	$v = $v -shr 6
	if ($v -gt 0) { $b0 = $b0 -bor 0x40 }
	$out.Add([byte]$b0)
	while ($v -gt 0)
	{
		$c = [int]($v -band 0x7F)
		$v = $v -shr 7
		if ($v -gt 0) { $c = $c -bor 0x80 }
		$out.Add([byte]$c)
	}
	return , $out.ToArray()
}

# ----------------------------------------------------------------------------------------------- package

function Read-Package([string] $path, [byte[]] $bytes)
{
	if (-not $bytes) { $bytes = [IO.File]::ReadAllBytes($path) }
	if ($bytes.Length -gt 28 -and [Text.Encoding]::Unicode.GetString($bytes, 0, 22) -eq 'Lineage2Ve')
	{
		throw "$path is wrapped in a Lineage2Ver container. EnchantGlow.u lives in system\ plain - see docs/enchant-glow.md."
	}
	$r = @{ B = $bytes; P = 0 }
	if ((Read-I32 $r) -ne -1641380927) { throw "$path is not an Unreal package." }
	$pkg = @{ Path = $path; Bytes = $bytes }
	$pkg.Version = [BitConverter]::ToUInt16($bytes, 4)
	$pkg.Licensee = [BitConverter]::ToUInt16($bytes, 6)
	$r.P = 12
	$pkg.NameCount = Read-I32 $r; $pkg.NameOffset = Read-I32 $r
	$pkg.ExportCount = Read-I32 $r; $pkg.ExportOffset = Read-I32 $r
	$pkg.ImportCount = Read-I32 $r; $pkg.ImportOffset = Read-I32 $r
	$pkg.GenerationCount = [BitConverter]::ToInt32($bytes, 52)

	$pkg.Names = New-Object System.Collections.ArrayList
	$pkg.NameIndex = @{}
	$r.P = $pkg.NameOffset
	for ($i = 0; $i -lt $pkg.NameCount; $i++)
	{
		$len = Read-CIdx $r
		$name = [Text.Encoding]::ASCII.GetString($bytes, $r.P, [Math]::Max(0, $len - 1))
		$r.P += $len
		$flags = Read-I32 $r
		[void]$pkg.Names.Add(@{ Name = $name; Flags = $flags })
		if (-not $pkg.NameIndex.ContainsKey($name)) { $pkg.NameIndex[$name] = $i }
	}
	$pkg.NameTableEnd = $r.P

	$pkg.Imports = New-Object System.Collections.ArrayList
	$r.P = $pkg.ImportOffset
	for ($i = 0; $i -lt $pkg.ImportCount; $i++)
	{
		$imp = @{ ClassPackage = (Read-CIdx $r); ClassName = (Read-CIdx $r); Outer = (Read-I32 $r); Name = (Read-CIdx $r) }
		[void]$pkg.Imports.Add($imp)
	}
	$pkg.ImportTableEnd = $r.P

	$pkg.Exports = New-Object System.Collections.ArrayList
	$r.P = $pkg.ExportOffset
	for ($i = 0; $i -lt $pkg.ExportCount; $i++)
	{
		$exp = @{ Class = (Read-CIdx $r); Super = (Read-CIdx $r); Outer = (Read-I32 $r); Name = (Read-CIdx $r) }
		$exp.Flags = Read-I32 $r
		$exp.Size = Read-CIdx $r
		$exp.Offset = 0
		if ($exp.Size -gt 0) { $exp.Offset = Read-CIdx $r }
		[void]$pkg.Exports.Add($exp)
	}
	$pkg.ExportTableEnd = $r.P

	$pkg.ByPath = @{}
	for ($i = 0; $i -lt $pkg.ExportCount; $i++)
	{
		$exp = $pkg.Exports[$i]
		$exp.Index = $i + 1
		$exp.Path = Get-ExportPath $pkg ($i + 1)
		$exp.ClassName = Get-ClassName $pkg $exp
		$pkg.ByPath[$exp.Path.ToLowerInvariant()] = $exp
	}
	return $pkg
}

function Get-ExportPath($pkg, [int] $index)
{
	$exp = $pkg.Exports[$index - 1]
	$path = $pkg.Names[$exp.Name].Name
	if ($exp.Outer -gt 0) { $path = (Get-ExportPath $pkg $exp.Outer) + '.' + $path }
	return $path
}

function Get-ClassName($pkg, $exp)
{
	if ($exp.Class -eq 0) { return 'Class' }
	if ($exp.Class -lt 0) { return $pkg.Names[$pkg.Imports[-$exp.Class - 1].Name].Name }
	return $pkg.Names[$pkg.Exports[$exp.Class - 1].Name].Name
}

function Get-NameIndex($pkg, [string] $name)
{
	if ($pkg.NameIndex.ContainsKey($name)) { return $pkg.NameIndex[$name] }
	# A new name takes the flags the package gives the names its properties already use.
	$flags = $pkg.Names[$pkg.NameIndex['MaxParticles']].Flags
	$i = $pkg.Names.Count
	[void]$pkg.Names.Add(@{ Name = $name; Flags = $flags })
	$pkg.NameIndex[$name] = $i
	return $i
}

function Format-ObjectRef($pkg, [int] $ref)
{
	if ($ref -eq 0) { return 'None' }
	if ($ref -gt 0) { return $pkg.Exports[$ref - 1].Path }
	return 'import:' + $pkg.Names[$pkg.Imports[-$ref - 1].Name].Name
}

function Resolve-ObjectRef($pkg, [string] $text)
{
	if ($text -eq 'None') { return 0 }
	if ($text.StartsWith('import:'))
	{
		$want = $text.Substring(7)
		for ($i = 0; $i -lt $pkg.Imports.Count; $i++)
		{
			if ($pkg.Names[$pkg.Imports[$i].Name].Name -eq $want) { return -($i + 1) }
		}
		throw "No import named $want in the package."
	}
	$key = $text.ToLowerInvariant()
	if (-not $pkg.ByPath.ContainsKey($key)) { throw "No object $text in the package - only its own exports and imports can be referenced." }
	return $pkg.ByPath[$key].Index
}

# ----------------------------------------------------------------------------------------------- schema
# What a property or a struct member is, learned from the tags the package itself carries : the text does
# not say whether "1" is a byte, an int or a float, and the bytes have to come out exactly as the engine
# wrote them.

$SCHEMA = @{ Props = @{}; Members = @{} }

function Add-Schema([string] $key, [hashtable] $table, $tag)
{
	if (-not $table.ContainsKey($key)) { $table[$key] = @{ Type = $tag.Type; Struct = $tag.Struct } }
}

# ----------------------------------------------------------------------------------------------- tags

function Get-SizeFromCode($r, [int] $code)
{
	switch ($code)
	{
		0 { return 1 }
		1 { return 2 }
		2 { return 4 }
		3 { return 12 }
		4 { return 16 }
		5 { return (Read-U8 $r) }
		6 { $v = [int][BitConverter]::ToUInt16($r.B, $r.P); $r.P += 2; return $v }
		7 { return (Read-I32 $r) }
	}
}

# Reads a tagged property list up to its None. Each tag keeps its value bytes, so formatting is separate.
function Read-Tags($pkg, $r, [int] $end, [string] $owner)
{
	$tags = New-Object System.Collections.ArrayList
	while ($true)
	{
		if ($r.P -ge $end) { throw "Property list of $owner runs past its end without a None." }
		$nameIdx = Read-CIdx $r
		$name = $pkg.Names[$nameIdx].Name
		if ($name -eq 'None') { break }
		$info = Read-U8 $r
		$tag = @{ Name = $name; Type = ($info -band 0x0F); SizeCode = (($info -shr 4) -band 7); Struct = $null; Index = 0 }
		$arrayBit = ($info -band 0x80) -ne 0
		if ($tag.Type -eq $T_STRUCT) { $tag.Struct = $pkg.Names[(Read-CIdx $r)].Name }
		$size = Get-SizeFromCode $r $tag.SizeCode
		if ($arrayBit -and $tag.Type -ne $T_BOOL)
		{
			$b = Read-U8 $r
			if (($b -band 0x80) -eq 0) { $tag.Index = $b }
			elseif (($b -band 0xC0) -eq 0x80) { $tag.Index = (($b -band 0x7F) -shl 8) -bor (Read-U8 $r) }
			else { $tag.Index = (($b -band 0x3F) -shl 24) -bor ((Read-U8 $r) -shl 16) -bor ((Read-U8 $r) -shl 8) -bor (Read-U8 $r) }
		}
		if ($tag.Type -eq $T_BOOL) { $tag.Bool = $arrayBit; $tag.Size = 0 }
		else
		{
			$tag.Size = $size
			$tag.Start = $r.P
			$r.P += $size
		}
		[void]$tags.Add($tag)
	}
	return , $tags
}

function Format-Float([single] $f)
{
	$bits = [BitConverter]::ToInt32([BitConverter]::GetBytes($f), 0)
	foreach ($digits in 6..9)
	{
		$s = $f.ToString("G$digits", $INV)
		if ([BitConverter]::ToInt32([BitConverter]::GetBytes([single]::Parse($s, $INV)), 0) -eq $bits) { return $s }
	}
	return $f.ToString('G9', $INV)
}

function Format-Hex([byte[]] $bytes, [int] $start, [int] $count)
{
	$sb = New-Object System.Text.StringBuilder
	for ($i = 0; $i -lt $count; $i++) { [void]$sb.Append($bytes[$start + $i].ToString('x2')) }
	return 'raw:' + $sb.ToString()
}

# One struct's tagged member list, as "(A=..,B=..)", learning the member types on the way.
function Format-TaggedStruct($pkg, $r, [int] $end, [string] $struct)
{
	$tags = Read-Tags $pkg $r $end $struct
	$parts = foreach ($t in $tags)
	{
		Add-Schema "$struct.$($t.Name)" $SCHEMA.Members $t
		$label = $t.Name
		if ($t.Index -ne 0) { $label += "[$($t.Index)]" }
		"$label=" + (Format-TagValue $pkg $t)
	}
	return '(' + ($parts -join ',') + ')'
}

function Format-TagValue($pkg, $tag)
{
	$b = $pkg.Bytes
	$s = $tag.Start
	switch ($tag.Type)
	{
		$T_BOOL { if ($tag.Bool) { return 'True' } else { return 'False' } }
		$T_BYTE
		{
			$v = [int]$b[$s]
			if ($ENUMS.ContainsKey($tag.Name) -and $v -lt $ENUMS[$tag.Name].Count) { return $ENUMS[$tag.Name][$v] }
			return [string]$v
		}
		$T_INT { return [string][BitConverter]::ToInt32($b, $s) }
		$T_FLOAT { return (Format-Float ([BitConverter]::ToSingle($b, $s))) }
		{ $_ -eq $T_OBJECT -or $_ -eq $T_CLASS }
		{
			$r = @{ B = $b; P = $s }
			return (Format-ObjectRef $pkg (Read-CIdx $r))
		}
		$T_NAME
		{
			$r = @{ B = $b; P = $s }
			return $pkg.Names[(Read-CIdx $r)].Name
		}
		$T_STRUCT
		{
			if ($RAW_STRUCTS.ContainsKey($tag.Struct))
			{
				$layout = $RAW_STRUCTS[$tag.Struct]
				$want = 0
				foreach ($m in $layout) { $want += @{ f = 4; i = 4; b = 1 }[$m[1]] }
				if ($want -ne $tag.Size) { return (Format-Hex $b $s $tag.Size) }
				$at = $s
				$parts = foreach ($m in $layout)
				{
					switch ($m[1])
					{
						'f' { "$($m[0])=" + (Format-Float ([BitConverter]::ToSingle($b, $at))); $at += 4 }
						'i' { "$($m[0])=" + [BitConverter]::ToInt32($b, $at); $at += 4 }
						'b' { "$($m[0])=" + $b[$at]; $at += 1 }
					}
				}
				return '(' + ($parts -join ',') + ')'
			}
			$r = @{ B = $b; P = $s }
			$text = Format-TaggedStruct $pkg $r ($s + $tag.Size) $tag.Struct
			if ($r.P -ne $s + $tag.Size) { return (Format-Hex $b $s $tag.Size) }
			return $text
		}
		$T_ARRAY
		{
			if (-not $ARRAY_ELEMENTS.ContainsKey($tag.Name)) { return (Format-Hex $b $s $tag.Size) }
			$element = $ARRAY_ELEMENTS[$tag.Name]
			$r = @{ B = $b; P = $s }
			$end = $s + $tag.Size
			$count = Read-CIdx $r
			$parts = for ($i = 0; $i -lt $count; $i++)
			{
				if ($element -eq '#object') { Format-ObjectRef $pkg (Read-CIdx $r) }
				else { Format-TaggedStruct $pkg $r $end $element }
			}
			if ($r.P -ne $end) { return (Format-Hex $b $s $tag.Size) }
			return '(' + ($parts -join ',') + ')'
		}
		default { return (Format-Hex $b $s $tag.Size) }
	}
}

# An emitter as text : one "Prop=value" line per tag, in the order the package has them.
function Format-Emitter($pkg, $exp)
{
	$r = @{ B = $pkg.Bytes; P = $exp.Offset }
	$end = $exp.Offset + $exp.Size
	$tags = Read-Tags $pkg $r $end $exp.Path
	if ($r.P -ne $end) { throw "$($exp.Path) carries $($end - $r.P) byte(s) behind its property list - not an editable emitter." }
	$lines = New-Object System.Collections.ArrayList
	[void]$lines.Add("[$($exp.Path)]")
	[void]$lines.Add("; $($exp.ClassName)")
	foreach ($t in $tags)
	{
		Add-Schema $t.Name $SCHEMA.Props $t
		$label = $t.Name
		if ($t.Index -ne 0) { $label += "[$($t.Index)]" }
		[void]$lines.Add("$label=" + (Format-TagValue $pkg $t))
	}
	return , $lines
}

# ----------------------------------------------------------------------------------------------- text in

function Split-Value([string] $text)
{
	$tokens = New-Object System.Collections.ArrayList
	$i = 0
	while ($i -lt $text.Length)
	{
		$c = $text[$i]
		if ([char]::IsWhiteSpace($c)) { $i++; continue }
		if ('(),='.Contains([string]$c)) { [void]$tokens.Add([string]$c); $i++; continue }
		if ($c -eq '"')
		{
			$j = $text.IndexOf('"', $i + 1)
			if ($j -lt 0) { throw "Unterminated string in: $text" }
			[void]$tokens.Add($text.Substring($i, $j - $i + 1))
			$i = $j + 1
			continue
		}
		$j = $i
		while ($j -lt $text.Length -and -not '(),='.Contains([string]$text[$j]) -and -not [char]::IsWhiteSpace($text[$j])) { $j++ }
		[void]$tokens.Add($text.Substring($i, $j - $i))
		$i = $j
	}
	return , $tokens
}

# value := atom | "(" [item {"," item}] ")" ; item := atom "=" value | value
function Read-ValueAst($tk)
{
	if ($tk.P -ge $tk.T.Count) { throw 'Value ends too early.' }
	$t = $tk.T[$tk.P]
	if ($t -ne '(')
	{
		if ($t -in ')', ',', '=') { throw "Unexpected '$t'." }
		$tk.P += 1
		return @{ Atom = $t }
	}
	$tk.P += 1
	$items = New-Object System.Collections.ArrayList
	if ($tk.T[$tk.P] -eq ')') { $tk.P += 1; return @{ Items = $items } }
	while ($true)
	{
		$key = $null
		if ($tk.P + 1 -lt $tk.T.Count -and $tk.T[$tk.P + 1] -eq '=' -and $tk.T[$tk.P] -notin '(', ')', ',')
		{
			$key = $tk.T[$tk.P]
			$tk.P += 2
		}
		[void]$items.Add(@{ Key = $key; Value = (Read-ValueAst $tk) })
		$t = $tk.T[$tk.P]
		$tk.P += 1
		if ($t -eq ')') { break }
		if ($t -ne ',') { throw "Expected ',' or ')', got '$t'." }
	}
	return @{ Items = $items }
}

function Get-Atom($ast, [string] $what)
{
	if (-not $ast.ContainsKey('Atom')) { throw "$what takes a single value, not a list." }
	return $ast.Atom
}

function Convert-Number([string] $text, [string] $what)
{
	$v = 0.0
	if (-not [double]::TryParse($text, [Globalization.NumberStyles]::Float, $INV, [ref]$v)) { throw "$what : '$text' is not a number." }
	return $v
}

function Get-TagBytes($pkg, [string] $name, [int] $type, [string] $struct, [int] $index, [bool] $bool, [byte[]] $value)
{
	$out = New-Object System.Collections.Generic.List[byte]
	$out.AddRange((Get-CIdxBytes (Get-NameIndex $pkg $name)))
	$size = 0
	if ($type -ne $T_BOOL) { $size = $value.Length }
	$code = switch ($size)
	{
		1 { 0 }
		2 { 1 }
		4 { 2 }
		12 { 3 }
		16 { 4 }
		default { if ($size -lt 256) { 5 } elseif ($size -lt 65536) { 6 } else { 7 } }
	}
	# A bool carries its value in the array bit and has no payload, yet this package writes it with a
	# one-byte size of 0 all the same (info 0x53 / 0xD3, then 00) - and so must we, or nothing matches.
	if ($type -eq $T_BOOL) { $code = 5 }
	$info = $type -bor ($code -shl 4)
	if (($type -eq $T_BOOL -and $bool) -or ($type -ne $T_BOOL -and $index -ne 0)) { $info = $info -bor 0x80 }
	$out.Add([byte]$info)
	if ($type -eq $T_STRUCT) { $out.AddRange((Get-CIdxBytes (Get-NameIndex $pkg $struct))) }
	switch ($code)
	{
		5 { $out.Add([byte]$size) }
		6 { $out.AddRange([BitConverter]::GetBytes([uint16]$size)) }
		7 { $out.AddRange([BitConverter]::GetBytes([int]$size)) }
	}
	if ($type -ne $T_BOOL -and $index -ne 0)
	{
		if ($index -lt 128) { $out.Add([byte]$index) }
		elseif ($index -lt 16384) { $out.Add([byte](($index -shr 8) -bor 0x80)); $out.Add([byte]($index -band 0xFF)) }
		else { $out.AddRange([byte[]]@((($index -shr 24) -bor 0xC0), (($index -shr 16) -band 0xFF), (($index -shr 8) -band 0xFF), ($index -band 0xFF))) }
	}
	if ($type -ne $T_BOOL) { $out.AddRange($value) }
	return , $out.ToArray()
}

function Get-TaggedStructBytes($pkg, [string] $struct, $ast, [string] $what)
{
	if (-not $ast.ContainsKey('Items')) { throw "$what is a $struct and takes (Member=value,...)." }
	$out = New-Object System.Collections.Generic.List[byte]
	foreach ($item in $ast.Items)
	{
		if (-not $item.Key) { throw "$what : every member of a $struct needs a name." }
		$key = $item.Key
		$index = 0
		if ($key -match '^(\w+)\[(\d+)\]$') { $key = $Matches[1]; $index = [int]$Matches[2] }
		$schemaKey = "$struct.$key"
		if (-not $SCHEMA.Members.ContainsKey($schemaKey)) { throw "$what : $struct has no member $key that this package ever wrote, so its type is unknown." }
		$m = $SCHEMA.Members[$schemaKey]
		$out.AddRange((Get-PropertyBytes $pkg $key $m.Type $m.Struct $index $item.Value "$what.$key"))
	}
	$out.AddRange((Get-CIdxBytes (Get-NameIndex $pkg 'None')))
	return , $out.ToArray()
}

function Get-ValueBytes($pkg, [string] $name, [int] $type, [string] $struct, $ast, [string] $what)
{
	if ($ast.ContainsKey('Atom') -and $ast.Atom.StartsWith('raw:'))
	{
		$hex = $ast.Atom.Substring(4)
		$bytes = New-Object byte[] ($hex.Length / 2)
		for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
		return , $bytes
	}
	switch ($type)
	{
		$T_BYTE
		{
			$a = Get-Atom $ast $what
			if ($ENUMS.ContainsKey($name))
			{
				for ($i = 0; $i -lt $ENUMS[$name].Count; $i++) { if ($ENUMS[$name][$i] -eq $a) { return , [byte[]]@([byte]$i) } }
			}
			return , [byte[]]@([byte](Convert-Number $a $what))
		}
		$T_INT { return , [BitConverter]::GetBytes([int](Convert-Number (Get-Atom $ast $what) $what)) }
		$T_FLOAT { return , [BitConverter]::GetBytes([single](Convert-Number (Get-Atom $ast $what) $what)) }
		{ $_ -eq $T_OBJECT -or $_ -eq $T_CLASS } { return , (Get-CIdxBytes (Resolve-ObjectRef $pkg (Get-Atom $ast $what))) }
		$T_NAME { return , (Get-CIdxBytes (Get-NameIndex $pkg (Get-Atom $ast $what))) }
		$T_STRUCT
		{
			if (-not $RAW_STRUCTS.ContainsKey($struct)) { return , (Get-TaggedStructBytes $pkg $struct $ast $what) }
			if (-not $ast.ContainsKey('Items')) { throw "$what is a $struct and takes (Member=value,...)." }
			$given = @{}
			foreach ($item in $ast.Items) { $given[$item.Key] = Get-Atom $item.Value "$what.$($item.Key)" }
			$out = New-Object System.Collections.Generic.List[byte]
			foreach ($m in $RAW_STRUCTS[$struct])
			{
				$v = 0.0
				if ($given.ContainsKey($m[0])) { $v = Convert-Number $given[$m[0]] "$what.$($m[0])"; $given.Remove($m[0]) }
				switch ($m[1])
				{
					'f' { $out.AddRange([BitConverter]::GetBytes([single]$v)) }
					'i' { $out.AddRange([BitConverter]::GetBytes([int]$v)) }
					'b' { $out.Add([byte]$v) }
				}
			}
			if ($given.Count) { throw "$what : $struct has no member $(@($given.Keys) -join ', ')." }
			return , $out.ToArray()
		}
		$T_ARRAY
		{
			if (-not $ARRAY_ELEMENTS.ContainsKey($name)) { throw "$what : the elements of $name are unknown, it can only be given as raw:." }
			if (-not $ast.ContainsKey('Items')) { throw "$what is an array and takes (element,element,...)." }
			$element = $ARRAY_ELEMENTS[$name]
			$out = New-Object System.Collections.Generic.List[byte]
			$out.AddRange((Get-CIdxBytes $ast.Items.Count))
			$i = 0
			foreach ($item in $ast.Items)
			{
				if ($element -eq '#object') { $out.AddRange((Get-CIdxBytes (Resolve-ObjectRef $pkg (Get-Atom $item.Value "$what[$i]")))) }
				else { $out.AddRange((Get-TaggedStructBytes $pkg $element $item.Value "$what[$i]")) }
				$i++
			}
			return , $out.ToArray()
		}
		default { throw "$what : a property of type $type can only be given as raw:." }
	}
}

function Get-PropertyBytes($pkg, [string] $name, [int] $type, [string] $struct, [int] $index, $ast, [string] $what)
{
	if ($type -eq $T_BOOL)
	{
		$a = Get-Atom $ast $what
		if ($a -notin 'True', 'False') { throw "$what is True or False, not '$a'." }
		return , (Get-TagBytes $pkg $name $T_BOOL $null $index ($a -eq 'True') $null)
	}
	$value = Get-ValueBytes $pkg $name $type $struct $ast $what
	return , (Get-TagBytes $pkg $name $type $struct $index $false $value)
}

# Sections of an edit file : [path] followed by Prop=value lines. ';' starts a comment outside quotes.
function Read-EditFile([string] $path)
{
	$sections = New-Object System.Collections.ArrayList
	$current = $null
	$lineNo = 0
	foreach ($raw in [IO.File]::ReadAllLines($path, $UTF8))
	{
		$lineNo++
		$line = $raw
		$quoted = $false
		for ($i = 0; $i -lt $line.Length; $i++)
		{
			if ($line[$i] -eq '"') { $quoted = -not $quoted }
			elseif ($line[$i] -eq ';' -and -not $quoted) { $line = $line.Substring(0, $i); break }
		}
		$line = $line.Trim()
		if ($line -eq '') { continue }
		if ($line -match '^\[(.+)\]$')
		{
			$current = @{ Path = $Matches[1].Trim(); Lines = (New-Object System.Collections.ArrayList); Line = $lineNo }
			[void]$sections.Add($current)
			continue
		}
		if (-not $current) { throw "${path}:$lineNo : a property before any [section]." }
		$eq = $line.IndexOf('=')
		if ($eq -lt 1) { throw "${path}:$lineNo : expected Prop=value." }
		[void]$current.Lines.Add(@{ Key = $line.Substring(0, $eq).Trim(); Value = $line.Substring($eq + 1).Trim(); Line = $lineNo })
	}
	return , $sections
}

function Get-EmitterBytes($pkg, $section, [string] $source)
{
	$out = New-Object System.Collections.Generic.List[byte]
	foreach ($l in $section.Lines)
	{
		$what = "${source}:$($l.Line) $($l.Key)"
		$key = $l.Key
		$index = 0
		if ($key -match '^(\w+)\[(\d+)\]$') { $key = $Matches[1]; $index = [int]$Matches[2] }
		if (-not $SCHEMA.Props.ContainsKey($key)) { throw "$what : no emitter in this package ever wrote $key, so its type is unknown." }
		$p = $SCHEMA.Props[$key]
		$tk = @{ T = (Split-Value $l.Value); P = 0 }
		try
		{
			$ast = Read-ValueAst $tk
			if ($tk.P -ne $tk.T.Count) { throw 'Trailing text after the value.' }
		}
		catch { throw "$what : $($_.Exception.Message)" }
		$out.AddRange((Get-PropertyBytes $pkg $key $p.Type $p.Struct $index $ast $what))
	}
	$out.AddRange((Get-CIdxBytes (Get-NameIndex $pkg 'None')))
	return , $out.ToArray()
}

# ----------------------------------------------------------------------------------------------- package out

function Get-Emitters($pkg)
{
	return @($pkg.Exports | Where-Object { $_.Size -gt 0 -and $EMITTER_CLASSES -contains $_.ClassName })
}

# Learns every property and struct member the package's emitters use, by formatting them once.
function Initialize-Schema($pkg)
{
	foreach ($e in (Get-Emitters $pkg)) { [void](Format-Emitter $pkg $e) }
	foreach ($k in $EXTRA_PROPS.Keys) { Add-Schema $k $SCHEMA.Props @{ Type = $EXTRA_PROPS[$k][0]; Struct = $EXTRA_PROPS[$k][1] } }
	foreach ($k in $EXTRA_MEMBERS.Keys) { Add-Schema $k $SCHEMA.Members @{ Type = $EXTRA_MEMBERS[$k][0]; Struct = $EXTRA_MEMBERS[$k][1] } }
}

function Write-Package($pkg, [hashtable] $blobs, [string] $path)
{
	$orig = $pkg.Bytes
	$dataStart = [int]::MaxValue
	$dataEnd = 0
	foreach ($e in $pkg.Exports)
	{
		if ($e.Size -le 0) { continue }
		$dataStart = [Math]::Min($dataStart, $e.Offset)
		$dataEnd = [Math]::Max($dataEnd, $e.Offset + $e.Size)
	}
	# The layout this relies on : all export data, then imports, then exports, then nothing. The name table
	# is either in front of the data (as shipped) or behind it (after an edit that added names).
	$namesClear = ($pkg.NameTableEnd -le $dataStart) -or ($pkg.NameOffset -ge $dataEnd -and $pkg.NameTableEnd -le $pkg.ImportOffset)
	if (-not $namesClear -or $pkg.ImportOffset -lt $dataEnd -or $pkg.ExportOffset -lt $pkg.ImportTableEnd -or $pkg.ExportTableEnd -ne $orig.Length)
	{
		throw "$($pkg.Path) is not laid out as names / export data / imports / exports - refusing to rewrite it."
	}

	$ms = New-Object System.IO.MemoryStream
	$ms.Write($orig, 0, $pkg.ImportOffset)
	$rows = @{}
	foreach ($index in @($blobs.Keys | Sort-Object))
	{
		$e = $pkg.Exports[$index - 1]
		if ($EMITTER_CLASSES -notcontains $e.ClassName) { throw "Refusing to rewrite $($e.Path), a $($e.ClassName)." }
		$blob = [byte[]]$blobs[$index]
		if ($blob.Length -eq $e.Size)
		{
			$ms.Position = $e.Offset
			$ms.Write($blob, 0, $blob.Length)
			$ms.Position = $ms.Length
			$rows[$index] = @($e.Size, $e.Offset)
		}
		else
		{
			$rows[$index] = @($blob.Length, [int]$ms.Length)
			$ms.Write($blob, 0, $blob.Length)
		}
	}

	$nameOffset = $pkg.NameOffset
	if ($pkg.Names.Count -ne $pkg.NameCount)
	{
		$nameOffset = [int]$ms.Length
		foreach ($n in $pkg.Names)
		{
			$ascii = [Text.Encoding]::ASCII.GetBytes($n.Name)
			$len = Get-CIdxBytes ($ascii.Length + 1)
			$ms.Write($len, 0, $len.Length)
			$ms.Write($ascii, 0, $ascii.Length)
			$ms.WriteByte(0)
			$ms.Write([BitConverter]::GetBytes([int]$n.Flags), 0, 4)
		}
	}

	$importOffset = [int]$ms.Length
	foreach ($imp in $pkg.Imports)
	{
		foreach ($part in @((Get-CIdxBytes $imp.ClassPackage), (Get-CIdxBytes $imp.ClassName), ([BitConverter]::GetBytes([int]$imp.Outer)), (Get-CIdxBytes $imp.Name)))
		{
			$ms.Write($part, 0, $part.Length)
		}
	}

	$exportOffset = [int]$ms.Length
	foreach ($e in $pkg.Exports)
	{
		$size = $e.Size
		$offset = $e.Offset
		if ($rows.ContainsKey($e.Index)) { $size = $rows[$e.Index][0]; $offset = $rows[$e.Index][1] }
		$parts = @((Get-CIdxBytes $e.Class), (Get-CIdxBytes $e.Super), ([BitConverter]::GetBytes([int]$e.Outer)), (Get-CIdxBytes $e.Name), ([BitConverter]::GetBytes([int]$e.Flags)), (Get-CIdxBytes $size))
		if ($size -gt 0) { $parts += , (Get-CIdxBytes $offset) }
		foreach ($part in $parts) { $ms.Write($part, 0, $part.Length) }
	}

	$out = $ms.ToArray()
	[BitConverter]::GetBytes([int]$pkg.Names.Count).CopyTo($out, 12)
	[BitConverter]::GetBytes($nameOffset).CopyTo($out, 16)
	[BitConverter]::GetBytes($exportOffset).CopyTo($out, 24)
	[BitConverter]::GetBytes($importOffset).CopyTo($out, 32)
	if ($pkg.GenerationCount -gt 0)
	{
		# The newest generation records the name count the package was saved with.
		[BitConverter]::GetBytes([int]$pkg.Names.Count).CopyTo($out, 56 + 8 * ($pkg.GenerationCount - 1) + 4)
	}

	Test-Unmoved $pkg $out
	if ($path) { [IO.File]::WriteAllBytes($path, $out) }
	return , $out
}

# Reads the rewritten package back : every export but the emitters has to sit exactly where it did - that
# is what keeps the lazy mip offsets of the textures true.
function Test-Unmoved($pkg, [byte[]] $out)
{
	$re = Read-Package "$($pkg.Path) (rewritten)" $out
	if ($re.ExportCount -ne $pkg.ExportCount -or $re.ImportCount -ne $pkg.ImportCount) { throw 'Internal error : the rewritten package lost or gained objects.' }
	for ($i = 0; $i -lt $pkg.ExportCount; $i++)
	{
		$a = $pkg.Exports[$i]
		$b = $re.Exports[$i]
		if ($a.Path -ne $b.Path) { throw "Internal error : export $($i + 1) reads back as $($b.Path), not $($a.Path)." }
		if ($EMITTER_CLASSES -contains $a.ClassName) { continue }
		if ($a.Size -ne $b.Size -or $a.Offset -ne $b.Offset) { throw "Internal error : $($a.Path) moved." }
	}
}

# ----------------------------------------------------------------------------------------------- modes

if ($ENCHANT_GLOW_FX_LIBRARY) { return }

$pkg = Read-Package $Package
Write-Host ("package : {0}  (version {1}, licensee {2} : {3} names, {4} imports, {5} exports)" -f $Package, $pkg.Version, $pkg.Licensee, $pkg.NameCount, $pkg.ImportCount, $pkg.ExportCount)
$emitters = Get-Emitters $pkg

if ($List)
{
	$byClass = $emitters | Group-Object { $pkg.Exports[$_.Outer - 1].Path } | Sort-Object Name
	foreach ($g in $byClass)
	{
		Write-Output $g.Name
		foreach ($e in $g.Group)
		{
			$lines = Format-Emitter $pkg $e
			$pick = @($lines | Where-Object { $_ -match '^(MaxParticles|Texture|StaticMesh|DrawStyle)=' }) -join '  '
			Write-Output ("    {0,-18} {1}" -f $pkg.Names[$e.Name].Name, $pick)
		}
	}
	return
}

if ($SelfTest)
{
	Initialize-Schema $pkg
	$bad = 0
	foreach ($e in $emitters)
	{
		$lines = Format-Emitter $pkg $e
		$tmp = [IO.Path]::GetTempFileName()
		try
		{
			[IO.File]::WriteAllLines($tmp, [string[]]$lines, $UTF8)
			$section = (Read-EditFile $tmp)[0]
		}
		finally { Remove-Item -LiteralPath $tmp -Force }
		$blob = Get-EmitterBytes $pkg $section $e.Path
		$same = $blob.Length -eq $e.Size
		if ($same)
		{
			for ($i = 0; $i -lt $blob.Length; $i++) { if ($blob[$i] -ne $pkg.Bytes[$e.Offset + $i]) { $same = $false; break } }
		}
		if (-not $same)
		{
			$bad++
			$at = 0
			while ($at -lt [Math]::Min($blob.Length, $e.Size) -and $blob[$at] -eq $pkg.Bytes[$e.Offset + $at]) { $at++ }
			$n = [Math]::Min(20, [Math]::Min($blob.Length, $e.Size) - $at)
			Write-Warning ("{0} : text -> bytes does not reproduce the package ({1} vs {2} bytes), first difference at +{3} : package {4} / text {5}" -f $e.Path, $blob.Length, $e.Size, $at, (Format-Hex $pkg.Bytes ($e.Offset + $at) $n), (Format-Hex $blob $at $n))
		}
	}
	Write-Host "emitters : $($emitters.Count) round-tripped, $bad mismatch(es)"
	if ($pkg.Names.Count -ne $pkg.NameCount) { throw "Round trip added $($pkg.Names.Count - $pkg.NameCount) name(s) - it must not need any." }
	$out = Write-Package $pkg @{} $null
	$same = $out.Length -eq $pkg.Bytes.Length
	if ($same) { for ($i = 0; $i -lt $out.Length; $i++) { if ($out[$i] -ne $pkg.Bytes[$i]) { $same = $false; break } } }
	Write-Host "rewrite  : $(if ($same) { 'byte exact' } else { 'DIFFERS' })"
	if ($bad -or -not $same) { exit 1 }
	return
}

if ($Export)
{
	$classes = @($pkg.Exports | Where-Object { $_.ClassName -eq 'Class' -and $pkg.Names[$_.Name].Name -like $Export } | Sort-Object Path)
	if (-not $classes) { throw "No effect class matches $Export." }
	$text = New-Object System.Collections.ArrayList
	foreach ($c in $classes)
	{
		[void]$text.Add("; ===== $($c.Path)")
		foreach ($e in ($emitters | Where-Object { $_.Outer -eq $c.Index }))
		{
			$text.AddRange((Format-Emitter $pkg $e))
			[void]$text.Add('')
		}
	}
	if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$text, $UTF8); Write-Host "written : $OutFile ($($classes.Count) class(es))" }
	else { $text }
	return
}

if ($Apply)
{
	Initialize-Schema $pkg
	$sections = Read-EditFile $Apply
	$blobs = @{}
	foreach ($s in $sections)
	{
		$key = $s.Path.ToLowerInvariant()
		if (-not $pkg.ByPath.ContainsKey($key)) { throw "${Apply}:$($s.Line) : no export $($s.Path) in the package." }
		$e = $pkg.ByPath[$key]
		if ($EMITTER_CLASSES -notcontains $e.ClassName) { throw "${Apply}:$($s.Line) : $($s.Path) is a $($e.ClassName), only emitters can be edited." }
		if ($blobs.ContainsKey($e.Index)) { throw "${Apply}:$($s.Line) : $($s.Path) is given twice." }
		$blobs[$e.Index] = Get-EmitterBytes $pkg $s $Apply
	}
	$target = $OutFile
	if (-not $target)
	{
		$target = $Package
		$backup = "$Package.fx.bak"
		if (-not (Test-Path $backup)) { Copy-Item -LiteralPath $Package -Destination $backup; Write-Host "backup  : $backup" }
	}
	$inPlace = 0; $moved = 0; $same = 0
	foreach ($index in $blobs.Keys)
	{
		$e = $pkg.Exports[$index - 1]
		$blob = $blobs[$index]
		if ($blob.Length -ne $e.Size) { $moved++; continue }
		$diff = $false
		for ($i = 0; $i -lt $blob.Length; $i++) { if ($blob[$i] -ne $pkg.Bytes[$e.Offset + $i]) { $diff = $true; break } }
		if ($diff) { $inPlace++ } else { $same++ }
	}
	$added = $pkg.Names.Count - $pkg.NameCount
	$out = Write-Package $pkg $blobs $target
	Write-Host "emitters : $inPlace rewritten in place, $moved moved behind the data, $same unchanged"
	if ($added) { Write-Host "names   : $added added ($(@($pkg.Names | Select-Object -Skip $pkg.NameCount | ForEach-Object { $_.Name }) -join ', ')) - name table moved to the end" }
	Write-Host "written : $target ($($out.Length) bytes, was $($pkg.Bytes.Length))"
	return
}

throw 'Nothing to do : pass -List, -Export, -Apply or -SelfTest.'
