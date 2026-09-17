<#
.SYNOPSIS
	Glow Studio : a window of sliders for the EnchantGlow effects, written straight into the running client.

.DESCRIPTION
	Pick an effect the client has loaded (the glow of the weapon in hand), pick one of its layers - an emitter -
	and drag : where the particles are born, how many, how long they live, which texture, colour over their
	life, how they move. Every change lands in the client's memory at once, in the emitter template and in every
	copy already burning, so the weapon in hand shows it on the next frame.

	- Disabled : the layer stops spawning (that goes into the package when baked) and is hidden at once by an
	  Opacity of 0 - the engine draws particles already alive until they die, and a layer with ForcedLifeTime
	  keeps them for good. Its real opacity is kept aside, shown by the slider, saved, and put back.
	- Solo : hides every other layer of the effect (by opacity only) while held.
	- Ctrl+Z : undoes the last change.
	- Reset layer / Reset effect : back to what the package EnchantGlow.u says.
	- Save : writes glow_fx\<effect>.txt, the edit file format of enchant_glow_fx.ps1 - the package lines of
	  every layer with the values the studio touched taken from memory.
	- Load from file : reads glow_fx\<effect>.txt back into memory - what Save wrote. A property the file
	  leaves out goes back to the package value ; one that differs from the package counts as touched.
	- Bake : with the client closed, applies every glow_fx\enchant*_*t.txt onto EnchantGlow.u.plain.bak and
	  writes EnchantGlow.u.

	Built on enchant_glow_live_fx.ps1 (finding templates and burning copies, the field layout) and
	enchant_glow_fx.ps1 (the package, the edit file format). Its limits are theirs : the layers an effect has are
	the layers it has, a texture can only be switched to one the client has loaded, an array keeps its length,
	a burning copy keeps its particle pool. See docs/enchant-glow.md.

	The client runs elevated (L2.exe asks for administrator in its manifest), so this has to as well. Keep the
	game windowed to have the studio next to it.

.PARAMETER SystemDir
	The client's system directory.

.EXAMPLE
	# elevated
	powershell -ExecutionPolicy Bypass -File tools\client\glow_studio.ps1 -SystemDir "<client>\system"
#>
param(
	[string] $SystemDir,
	[string] $ProcessName = 'l2'
)

$ErrorActionPreference = 'Stop'
if (-not $SystemDir) { throw '-SystemDir is required.' }
$studioRoot = $PSScriptRoot
$glowDir = Join-Path $studioRoot 'glow_fx'
$previewDir = Join-Path $glowDir 'textures'

$ENCHANT_GLOW_LIVE_LIBRARY = $true
. (Join-Path $studioRoot 'enchant_glow_live_fx.ps1') -SystemDir $SystemDir -ProcessName $ProcessName

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ----------------------------------------------------------------------------------------------- what is edited

$TEXTURE_LABELS = @{
	'fx_m_t6290' = 'клубы огня (4x4)'
	'fx_m_t5030' = 'языки пламени (2x2)'
	'fx_m_t2033' = 'искры-звёздочки (4x4)'
	'fx_m_t5004' = 'вспышки-звёзды (2x2)'
	'fx_m_t6292' = 'огонь с прозрачностью (4x4)'
	'fx_m_t0137' = 'голубые свечения (4x2)'
	'fx_m_t4163' = 'голубой луч'
	'fx_m_t4147' = 'голубой крест-луч'
	'fx_m_t0042' = 'молния 1'
	'fx_m_t0043' = 'молния 2'
	'fx_m_t0044' = 'молния 3'
	'fx_m_t0045' = 'молния 4'
}

$ENUM_LABELS = @{
	'DrawStyle'          = @('обычный', 'альфа-смешение', 'модуляция', 'прозрачный', 'альфа-модуляция', 'затемнение (дым)', 'свечение (сложение)')
	'UseDirectionAs'     = @('лицом к камере', 'вдоль движения', 'вправо', 'вперёд', 'по нормали', 'вдоль движения + нормаль', 'вправо + нормаль', 'масштаб по скорости')
	'StartLocationShape' = @('коробка', 'сфера', 'полярная')
}

function New-Desc([string] $group, [string] $label, [string] $kind, [string] $prop, [int] $member = 0, [double] $min = 0, [double] $max = 1, [double] $step = 0.01, [string] $only = '')
{
	return @{ Group = $group; Label = $label; Kind = $kind; Prop = $prop; Member = $member; Min = $min; Max = $max; Step = $step; Only = $only }
}

# Kinds : float - a float ; center / half - the middle / the half width of a Range, keeping the other ;
# both - Min = Max of a Range ; all3 - Min = Max on X, Y and Z of a RangeVector ; int ; enum ; bool ;
# object (texture or mesh) ; colors / sizes - the points of ColorScale / SizeScale.
$DESCS = @(
	(New-Desc 'Слой' 'Выключен' 'bool' 'Disabled')

	(New-Desc 'Где рождаются' 'Сдвиг вдоль клинка (X)' 'float' 'StartLocationOffset' 0 -40 60 0.5)
	(New-Desc 'Где рождаются' 'Сдвиг поперёк (Y)' 'float' 'StartLocationOffset' 4 -20 20 0.1)
	(New-Desc 'Где рождаются' 'Сдвиг поперёк (Z)' 'float' 'StartLocationOffset' 8 -20 20 0.1)
	(New-Desc 'Где рождаются' 'Длина зоны вдоль клинка (±)' 'half' 'StartLocationRange' 0 0 40 0.25)
	(New-Desc 'Где рождаются' 'Центр зоны вдоль клинка' 'center' 'StartLocationRange' 0 -40 40 0.25)
	(New-Desc 'Где рождаются' 'Толщина зоны Y (±)' 'half' 'StartLocationRange' 8 0 10 0.05)
	(New-Desc 'Где рождаются' 'Толщина зоны Z (±)' 'half' 'StartLocationRange' 16 0 10 0.05)
	(New-Desc 'Где рождаются' 'Форма зоны' 'enum' 'StartLocationShape')
	(New-Desc 'Где рождаются' 'Радиус сферы' 'both' 'SphereRadiusRange' 0 0 40 0.25)

	(New-Desc 'Сколько' 'Максимум частиц' 'int' 'MaxParticles' 0 0 200 1)
	(New-Desc 'Сколько' 'Частиц в секунду' 'float' 'InitialParticlesPerSecond' 0 0 400 1)
	(New-Desc 'Сколько' 'Время жизни, с' 'center' 'LifetimeRange' 0 0 5 0.05)
	(New-Desc 'Сколько' 'Разброс времени жизни (±)' 'half' 'LifetimeRange' 0 0 3 0.05)

	(New-Desc 'Вид' 'Текстура' 'object' 'Texture' 0 0 0 0 'SpriteEmitter')
	(New-Desc 'Вид' 'Меш' 'object' 'StaticMesh' 0 0 0 0 'MeshEmitter')
	(New-Desc 'Вид' 'Режим отрисовки' 'enum' 'DrawStyle')
	(New-Desc 'Вид' 'Ориентация спрайта' 'enum' 'UseDirectionAs' 0 0 0 0 'SpriteEmitter')
	(New-Desc 'Вид' 'Прозрачность' 'float' 'Opacity' 0 0 1 0.01)
	(New-Desc 'Вид' 'Кадров по горизонтали' 'int' 'TextureUSubdivisions' 0 1 8 1 'SpriteEmitter')
	(New-Desc 'Вид' 'Кадров по вертикали' 'int' 'TextureVSubdivisions' 0 1 8 1 'SpriteEmitter')
	(New-Desc 'Вид' 'Первый кадр' 'int' 'SubdivisionStart' 0 0 63 1 'SpriteEmitter')
	(New-Desc 'Вид' 'Последний кадр' 'int' 'SubdivisionEnd' 0 0 63 1 'SpriteEmitter')
	(New-Desc 'Вид' 'Случайный кадр' 'bool' 'UseRandomSubdivision' 0 0 0 0 'SpriteEmitter')
	(New-Desc 'Вид' 'Плавная смена кадров' 'bool' 'BlendBetweenSubdivisions' 0 0 0 0 'SpriteEmitter')

	(New-Desc 'Размер' 'Одинаковый по осям' 'bool' 'UniformSize')
	(New-Desc 'Размер' 'Размер / ширина (X)' 'center' 'StartSizeRange' 0 0 20 0.05)
	(New-Desc 'Размер' 'Разброс ширины (±)' 'half' 'StartSizeRange' 0 0 10 0.05)
	(New-Desc 'Размер' 'Длина (Y, если размер разный)' 'center' 'StartSizeRange' 8 0 40 0.05)
	(New-Desc 'Размер' 'Разброс длины (±)' 'half' 'StartSizeRange' 8 0 20 0.05)
	(New-Desc 'Размер' 'Размер меняется по жизни' 'bool' 'UseSizeScale')
	(New-Desc 'Размер' 'Точки размера по жизни' 'sizes' 'SizeScale')
	(New-Desc 'Размер' 'Повторов размера' 'float' 'SizeScaleRepeats' 0 0 30 0.5)

	(New-Desc 'Цвет и появление' 'Цвет меняется по жизни' 'bool' 'UseColorScale')
	(New-Desc 'Цвет и появление' 'Точки цвета по жизни' 'colors' 'ColorScale')
	(New-Desc 'Цвет и появление' 'Повторов цвета' 'float' 'ColorScaleRepeats' 0 0 30 0.5)
	(New-Desc 'Цвет и появление' 'Проявление' 'bool' 'FadeIn')
	(New-Desc 'Цвет и появление' 'Проявление до, с' 'float' 'FadeInEndTime' 0 0 3 0.01)
	(New-Desc 'Цвет и появление' 'Угасание' 'bool' 'FadeOut')
	(New-Desc 'Цвет и появление' 'Угасание с, с' 'float' 'FadeOutStartTime' 0 0 3 0.01)

	(New-Desc 'Движение' 'Скорость вдоль клинка' 'center' 'StartVelocityRange' 0 -60 60 0.25)
	(New-Desc 'Движение' 'Разброс скорости вдоль (±)' 'half' 'StartVelocityRange' 0 0 60 0.25)
	(New-Desc 'Движение' 'Скорость поперёк Y' 'center' 'StartVelocityRange' 8 -60 60 0.25)
	(New-Desc 'Движение' 'Разлёт поперёк Y (±)' 'half' 'StartVelocityRange' 8 0 60 0.25)
	(New-Desc 'Движение' 'Скорость поперёк Z' 'center' 'StartVelocityRange' 16 -60 60 0.25)
	(New-Desc 'Движение' 'Разлёт поперёк Z (±)' 'half' 'StartVelocityRange' 16 0 60 0.25)
	(New-Desc 'Движение' 'Торможение' 'all3' 'VelocityLossRange' 0 0 20 0.1)
	(New-Desc 'Движение' 'Ускорение X' 'float' 'Acceleration' 0 -60 60 0.5)
	(New-Desc 'Движение' 'Ускорение Y' 'float' 'Acceleration' 4 -60 60 0.5)
	(New-Desc 'Движение' 'Ускорение Z' 'float' 'Acceleration' 8 -60 60 0.5)
	(New-Desc 'Движение' 'Вращать частицы' 'bool' 'SpinParticles')
	(New-Desc 'Движение' 'Вращение, об/с' 'center' 'SpinsPerSecondRange' 0 -3 3 0.05)
	(New-Desc 'Движение' 'Разброс вращения (±)' 'half' 'SpinsPerSecondRange' 0 0 3 0.05)
	(New-Desc 'Движение' 'Кружить вокруг центра' 'bool' 'UseRevolution')
	(New-Desc 'Движение' 'Кружение вокруг X, об/с' 'center' 'RevolutionsPerSecondRange' 0 -3 3 0.05)
)

# ----------------------------------------------------------------------------------------------- state

$S = @{
	Layers    = New-Object System.Collections.ArrayList   # emitters of the current effect
	Current   = $null
	Loading   = $false
	Undo      = New-Object System.Collections.ArrayList
	Touched   = @{}      # export index -> hashtable of property names
	Solo      = $null    # set while solo is on
	Rows      = New-Object System.Collections.ArrayList
	Seen      = @{}      # export index -> layer, kept across effect switches so snapshots survive
	LastScan  = [DateTime]::MinValue
}

function Get-EffectPath([int] $index) { return $pkg.Exports[$pkg.Exports[$index].Outer - 1].Path }

# What "reset" returns to : the template as it sits in memory, with every field the package itself names
# put back to the package value - memory alone is not trusted, an earlier session may have changed it (a
# hidden layer's Opacity 0, say). Opacity the package leaves out is the engine default, 1.
function New-PackageSnapshot($layer)
{
	$values = Get-PackageValues $layer.Exp
	if (-not $values.ContainsKey('Opacity')) { $values['Opacity'] = '1' }
	$state = ConvertTo-LayerState $layer $values (Read-Mem $layer.Template $OBJECT_SIZE) $false
	$layer.Snapshot = $state.Buf
	foreach ($prop in 'ColorScale', 'SizeScale')
	{
		$f = Get-Field 'ParticleEmitter' $prop
		$live = Get-ArrayPoints $layer $f.Offset
		# the live array keeps its length : take the package points only when they fit
		if ($state.Arrays.ContainsKey($prop) -and $state.Arrays[$prop].Count -le $live.Count) { $layer.SnapArrays[$prop] = $state.Arrays[$prop] }
		else { $layer.SnapArrays[$prop] = $live }
	}
}

# Text values (Prop -> package text) laid over a copy of $base, the way the object holds them in memory.
# Arrays come back aside ; objects (textures, meshes) only with $objects, and only ones the client has loaded.
# Skipped lists the properties that could not be taken.
function ConvertTo-LayerState($layer, [hashtable] $values, [byte[]] $base, [bool] $objects)
{
	$buf = [byte[]]$base.Clone()
	$arrays = @{}
	$skipped = New-Object System.Collections.ArrayList
	foreach ($prop in $values.Keys)
	{
		$f = Get-Field $layer.Class $prop
		if (-not $f) { continue }
		try
		{
			if ($f.Type -like 'Object<*')
			{
				if (-not $objects) { continue }
				$ptr = Resolve-LoadedObject $values[$prop] $prop
				if ($null -eq $ptr) { [void]$skipped.Add("$prop=$($values[$prop]) (не загружен клиентом)"); continue }
				[BitConverter]::GetBytes([uint32]$ptr).CopyTo($buf, $f.Offset)
				continue
			}
			$ast = Get-Ast $values[$prop]
			if ($f.Bit -ge 0)
			{
				$v = [long][BitConverter]::ToUInt32($buf, $f.Offset)
				$mask = [long]1 -shl $f.Bit
				if ((Get-Atom $ast $prop) -eq 'True') { $v = $v -bor $mask } else { $v = $v -band (0xFFFFFFFFL -bxor $mask) }
				[BitConverter]::GetBytes([uint32]$v).CopyTo($buf, $f.Offset)
			}
			elseif ($f.Type -eq 'Float') { [BitConverter]::GetBytes([single](Convert-Number (Get-Atom $ast $prop) $prop)).CopyTo($buf, $f.Offset) }
			elseif ($f.Type -eq 'Int') { [BitConverter]::GetBytes([int](Convert-Number (Get-Atom $ast $prop) $prop)).CopyTo($buf, $f.Offset) }
			elseif ($f.Type -like 'Byte*')
			{
				$a = Get-Atom $ast $prop
				$byte = $null
				if ($ENUMS.ContainsKey($prop)) { for ($i = 0; $i -lt $ENUMS[$prop].Count; $i++) { if ($ENUMS[$prop][$i] -eq $a) { $byte = $i } } }
				if ($null -eq $byte) { $byte = [int](Convert-Number $a $prop) }
				$buf[$f.Offset] = [byte]$byte
			}
			elseif ($f.Type -match '^Struct<(\w+)>$' -and $MEMORY_STRUCTS.ContainsKey($Matches[1]))
			{
				$floats = New-Object System.Collections.ArrayList
				Set-StructBytes $buf $f.Offset $Matches[1] $ast $prop $floats
			}
			elseif ($prop -in 'ColorScale', 'SizeScale' -and $ast.ContainsKey('Items'))
			{
				$bytes = New-Object byte[] (8 * $ast.Items.Count)
				$floats = New-Object System.Collections.ArrayList
				for ($i = 0; $i -lt $ast.Items.Count; $i++) { Set-StructBytes $bytes (8 * $i) $ARRAY_ELEMENTS[$prop] $ast.Items[$i].Value $prop $floats }
				$arrays[$prop] = @{ Count = $ast.Items.Count; Bytes = $bytes }
			}
		}
		catch { [void]$skipped.Add("$prop ($($_.Exception.Message))") }
	}
	return @{ Buf = $buf; Arrays = $arrays; Skipped = $skipped }
}

function Get-Offset($layer, $desc)
{
	return (Get-Field $layer.Class $desc.Prop)
}

# ----------------------------------------------------------------------------------------------- memory access

function Get-LiveCopies($layer)
{
	$valid = @($layer.Copies | Where-Object { (Get-U32 ($_ + $HEADER_CLASS)) -eq $layer.ClassPtr -and (Get-U32 ($_ + $HEADER_LINKER)) -eq 0 })
	if ($valid.Count -lt $layer.Copies.Count -and ((Get-Date) - $S.LastScan).TotalSeconds -gt 3)
	{
		# a copy died - the weapon was re-equipped : look for the new ones
		Update-Copies $true
		$valid = @($layer.Copies)
	}
	return $valid
}

function Set-Float($layer, [int] $offset, [double] $value)
{
	$t = [BitConverter]::ToSingle((Read-Mem ($layer.Template + $offset) 4), 0)
	foreach ($c in (Get-LiveCopies $layer))
	{
		$cur = [BitConverter]::ToSingle((Read-Mem ($c + $offset) 4), 0)
		$w = $value
		# a copy running scaled (sizes doubled by the weapon's scale, say) keeps its ratio
		if ([Math]::Abs($t) -gt 1e-6 -and [Math]::Abs($cur - $t) -gt 1e-5) { $w = $value * $cur / $t }
		Write-Mem ($c + $offset) ([BitConverter]::GetBytes([single]$w))
	}
	Write-Mem ($layer.Template + $offset) ([BitConverter]::GetBytes([single]$value))
}

function Set-Raw($layer, [int] $offset, [byte[]] $bytes)
{
	foreach ($c in (Get-LiveCopies $layer)) { Write-Mem ($c + $offset) $bytes }
	Write-Mem ($layer.Template + $offset) $bytes
}

function Set-Bit($layer, [int] $offset, [int] $bit, [bool] $on)
{
	foreach ($addr in @(Get-LiveCopies $layer) + @($layer.Template))
	{
		$v = [long](Get-U32 ($addr + $offset))
		$mask = [long]1 -shl $bit
		if ($on) { $v = $v -bor $mask } else { $v = $v -band (0xFFFFFFFFL -bxor $mask) }
		Write-Mem ($addr + $offset) ([BitConverter]::GetBytes([uint32]$v))
	}
}

function Set-MaxParticles($layer, [int] $offset, [int] $value)
{
	$pool = (Get-Field 'ParticleEmitter' 'Particles').Offset
	$capped = $false
	foreach ($c in (Get-LiveCopies $layer))
	{
		$num = [int](Get-U32 ($c + $pool + 4))
		$w = $value
		if ($w -gt $num) { $w = $num; $capped = $true }
		Write-Mem ($c + $offset) ([BitConverter]::GetBytes([int]$w))
	}
	Write-Mem ($layer.Template + $offset) ([BitConverter]::GetBytes([int]$value))
	if ($capped) { Set-Status "Горящий эффект держит пул меньше $value частиц - переодень оружие, чтобы получить больше." }
}

# Point $i of an array of 8-byte elements : writes $bytes at $memberOffset inside the element, on every object.
function Set-ArrayPoint($layer, [int] $offset, [int] $i, [int] $memberOffset, [byte[]] $bytes)
{
	foreach ($addr in @(Get-LiveCopies $layer) + @($layer.Template))
	{
		$data = Get-U32 ($addr + $offset)
		$num = [int](Get-U32 ($addr + $offset + 4))
		if ($data -and $i -lt $num) { Write-Mem ($data + 8 * $i + $memberOffset) $bytes }
	}
}

function Get-ArrayPoints($layer, [int] $offset)
{
	$data = Get-U32 ($layer.Template + $offset)
	$num = [int](Get-U32 ($layer.Template + $offset + 4))
	if (-not $data -or $num -le 0 -or $num -gt 64) { return @{ Count = 0; Bytes = (New-Object byte[] 0) } }
	return @{ Count = $num; Bytes = (Read-Mem $data (8 * $num)) }
}

# ----------------------------------------------------------------------------------------------- hiding
# Disabled only stops a layer from spawning : particles already alive stay, and a layer with ForcedLifeTime
# keeps them for good. Opacity is applied at draw time, so a layer is hidden by writing Opacity 0 - its real
# opacity is kept on the side, shown by the slider and saved, and written back when the layer shows again.
# Reasons : 'disabled' (the Disabled box) and 'solo' (another layer is soloed).

function Add-Hide($layer, [string] $why)
{
	if (-not $layer.Hide.Count)
	{
		$f = Get-Field 'ParticleEmitter' 'Opacity'
		$layer.HiddenOpacity = [BitConverter]::ToSingle((Read-Mem ($layer.Template + $f.Offset) 4), 0)
		Set-Float $layer $f.Offset 0
	}
	$layer.Hide[$why] = $true
}

function Remove-Hide($layer, [string] $why)
{
	if (-not $layer.Hide.ContainsKey($why)) { return }
	$layer.Hide.Remove($why)
	if (-not $layer.Hide.Count)
	{
		$f = Get-Field 'ParticleEmitter' 'Opacity'
		Set-Float $layer $f.Offset $layer.HiddenOpacity
		$layer.HiddenOpacity = $null
	}
}

# ----------------------------------------------------------------------------------------------- values

function Get-Value($layer, $desc, [byte[]] $buf)
{
	$f = Get-Offset $layer $desc
	if (-not $f) { return $null }
	if ($desc.Prop -eq 'Opacity' -and $layer.Hide.Count) { return $layer.HiddenOpacity }
	$o = $f.Offset + $desc.Member
	switch ($desc.Kind)
	{
		'float' { return [BitConverter]::ToSingle($buf, $o) }
		'int' { return [BitConverter]::ToInt32($buf, $o) }
		'enum' { return [int]$buf[$o] }
		'bool' { return ((([BitConverter]::ToUInt32($buf, $f.Offset)) -shr $f.Bit) -band 1) -eq 1 }
		'object' { return [BitConverter]::ToUInt32($buf, $o) }
		'center' { return ([BitConverter]::ToSingle($buf, $o) + [BitConverter]::ToSingle($buf, $o + 4)) / 2 }
		'half' { return ([BitConverter]::ToSingle($buf, $o + 4) - [BitConverter]::ToSingle($buf, $o)) / 2 }
		'both' { return [BitConverter]::ToSingle($buf, $o + 4) }
		'all3' { return [BitConverter]::ToSingle($buf, $o + 4) }
	}
	return $null
}

function Set-Value($layer, $desc, $value)
{
	$f = Get-Offset $layer $desc
	if (-not $f) { return }
	$o = $f.Offset + $desc.Member
	$touched = $S.Touched[$layer.Index]
	if (-not $touched) { $touched = @{}; $S.Touched[$layer.Index] = $touched }
	$touched[$desc.Prop] = $true
	if ($desc.Prop -eq 'Opacity' -and $layer.Hide.Count) { $layer.HiddenOpacity = [single]$value; return }
	if ($desc.Prop -eq 'Disabled')
	{
		Set-Bit $layer $f.Offset $f.Bit ([bool]$value)
		if ($value) { Add-Hide $layer 'disabled' } else { Remove-Hide $layer 'disabled' }
		return
	}
	$t = Read-Mem $layer.Template $OBJECT_SIZE
	switch ($desc.Kind)
	{
		'float' { Set-Float $layer $o $value }
		'int'
		{
			if ($desc.Prop -eq 'MaxParticles') { Set-MaxParticles $layer $o ([int]$value) }
			else { Set-Raw $layer $o ([BitConverter]::GetBytes([int]$value)) }
		}
		'enum' { Set-Raw $layer $o ([byte[]]@([byte]$value)) }
		'bool' { Set-Bit $layer $f.Offset $f.Bit ([bool]$value) }
		'object' { Set-Raw $layer $o ([BitConverter]::GetBytes([uint32]$value)) }
		'center'
		{
			$half = ([BitConverter]::ToSingle($t, $o + 4) - [BitConverter]::ToSingle($t, $o)) / 2
			Set-Float $layer $o ($value - $half)
			Set-Float $layer ($o + 4) ($value + $half)
		}
		'half'
		{
			$mid = ([BitConverter]::ToSingle($t, $o + 4) + [BitConverter]::ToSingle($t, $o)) / 2
			Set-Float $layer $o ($mid - $value)
			Set-Float $layer ($o + 4) ($mid + $value)
		}
		'both' { Set-Float $layer $o $value; Set-Float $layer ($o + 4) $value }
		'all3' { foreach ($k in 0, 8, 16) { Set-Float $layer ($o + $k) $value; Set-Float $layer ($o + $k + 4) $value } }
	}
}

# ----------------------------------------------------------------------------------------------- scanning

function Update-Copies([bool] $everywhere)
{
	Set-Status 'Ищу горящие эффекты...'
	$all = Get-Regions
	if ($everywhere) { $script:Regions = $all }
	else
	{
		$near = New-Object System.Collections.ArrayList
		foreach ($r in $all)
		{
			foreach ($l in $S.Layers) { if ($l.Template -ge $r[0] -and $l.Template -lt $r[0] + $r[1]) { [void]$near.Add($r); break } }
		}
		$script:Regions = $near
	}
	$addrs = @{}
	foreach ($l in $S.Layers) { $addrs[$l.Index] = $l.Template }
	$found = Find-Copies $addrs
	foreach ($l in $S.Layers)
	{
		$l.Copies = New-Object System.Collections.ArrayList
		if ($found.ContainsKey($l.Index)) { foreach ($c in $found[$l.Index]) { [void]$l.Copies.Add($c) } }
	}
	$S.LastScan = Get-Date
	$burning = ($S.Layers | ForEach-Object { $_.Copies.Count } | Measure-Object -Sum).Sum
	Set-Status "Слоёв: $($S.Layers.Count), горящих копий: $burning"
}

function Update-Effects
{
	Set-Status 'Ищу загруженные эффекты...'
	$form.Cursor = 'WaitCursor'
	try
	{
		Update-Templates @()
		$effects = @($script:Templates.Keys | ForEach-Object { Get-EffectPath $_ } | Sort-Object -Unique)
		$keep = $effectBox.SelectedItem
		# the effect of the weapon in hand, as the engine reports it - the one whose edits show
		$held = @(Get-HeldEffectEmitters | ForEach-Object { Get-EffectPath $_ } | Select-Object -First 1)
		$effectBox.Items.Clear()
		foreach ($e in $effects) { [void]$effectBox.Items.Add($e) }
		if ($held.Count -and $effects -contains $held[0]) { $effectBox.SelectedItem = $held[0] }
		elseif ($keep -and $effects -contains $keep) { $effectBox.SelectedItem = $keep }
		elseif ($effects.Count) { $effectBox.SelectedIndex = 0 }
		$inHand = if ($held.Count) { ", в руке: $($held[0])" } else { '' }
		Set-Status "Загруженных эффектов: $($effects.Count)$inHand"
	}
	catch { Set-Status $_.Exception.Message }
	finally { $form.Cursor = 'Default' }
}

function Select-Effect([string] $path)
{
	$form.Cursor = 'WaitCursor'
	try
	{
		Stop-Solo
		$S.Layers.Clear()
		foreach ($index in ($script:Templates.Keys | Sort-Object))
		{
			if ((Get-EffectPath $index) -ne $path) { continue }
			$layer = $S.Seen[$index]
			if (-not $layer -or $layer.Template -ne $script:Templates[$index])
			{
				$exp = $pkg.Exports[$index]
				$layer = @{
					Index         = $index
					Exp           = $exp
					Class         = $exp.ClassName
					Name          = $pkg.Names[$exp.Name].Name
					Template      = $script:Templates[$index]
					ClassPtr      = (Get-U32 ($script:Templates[$index] + $HEADER_CLASS))
					Copies        = (New-Object System.Collections.ArrayList)
					Snapshot      = $null
					SnapArrays    = @{}
					Hide          = @{}
					HiddenOpacity = $null
				}
				New-PackageSnapshot $layer
				$S.Seen[$index] = $layer
			}
			[void]$S.Layers.Add($layer)
		}
		Update-Copies $true
		# a layer already switched off (an earlier session, or the package) is hidden like the box would hide it
		$disabledDesc = $DESCS[0]
		foreach ($l in $S.Layers)
		{
			if (-not $l.Hide.Count -and (Get-Value $l $disabledDesc (Read-Mem $l.Template $OBJECT_SIZE)))
			{
				Add-Hide $l 'disabled'
				# memory may already say 0 - hidden by an earlier session : the real opacity is the package's
				if ($l.HiddenOpacity -eq 0) { $l.HiddenOpacity = [BitConverter]::ToSingle($l.Snapshot, (Get-Field 'ParticleEmitter' 'Opacity').Offset) }
			}
		}
		$layerBox.Items.Clear()
		foreach ($l in $S.Layers) { [void]$layerBox.Items.Add((Get-LayerTitle $l)) }
		if ($S.Layers.Count) { $layerBox.SelectedIndex = 0 }
	}
	finally { $form.Cursor = 'Default' }
}

function Get-LayerTitle($layer)
{
	$buf = Read-Mem $layer.Template $OBJECT_SIZE
	$what = ''
	if ($layer.Class -eq 'MeshEmitter') { $what = 'меш ' + (Get-ObjectName ([BitConverter]::ToUInt32($buf, (Get-Field 'MeshEmitter' 'StaticMesh').Offset))) }
	else
	{
		$tex = Get-ObjectName ([BitConverter]::ToUInt32($buf, (Get-Field 'ParticleEmitter' 'Texture').Offset))
		$what = $tex
		if ($TEXTURE_LABELS.ContainsKey($tex.ToLowerInvariant())) { $what = $TEXTURE_LABELS[$tex.ToLowerInvariant()] }
	}
	$disabled = (Get-Value $layer $DESCS[0] $buf)
	return ('{0}{1} - {2}' -f $(if ($disabled) { '[выкл] ' } else { '' }), $layer.Name, $what)
}

function Get-ObjectName([uint32] $ptr)
{
	if ($ptr -eq 0) { return 'нет' }
	foreach ($index in $script:Loaded.Keys) { if ($script:Loaded[$index] -eq $ptr) { return $pkg.Exports[$index].Path } }
	return ('0x{0:X8}' -f $ptr)
}

# ----------------------------------------------------------------------------------------------- solo / undo / reset

function Start-Solo
{
	if ($S.Solo -or -not $S.Current) { return }
	$S.Solo = @{}
	foreach ($l in $S.Layers)
	{
		if ($l.Index -eq $S.Current.Index) { Remove-Hide $l 'solo' } else { Add-Hide $l 'solo' }
		$S.Solo[$l.Index] = $true
	}
	$soloButton.Text = 'Соло: вкл'
	$soloButton.BackColor = [Drawing.Color]::Gold
}

function Stop-Solo
{
	if (-not $S.Solo) { return }
	foreach ($l in $S.Layers) { Remove-Hide $l 'solo' }
	$S.Solo = $null
	$soloButton.Text = 'Соло'
	$soloButton.UseVisualStyleBackColor = $true
}

function Push-Undo($layer, $desc, $old, [string] $key)
{
	$last = $null
	if ($S.Undo.Count) { $last = $S.Undo[$S.Undo.Count - 1] }
	# one entry per drag : a run of changes on the same control within a second keeps its first old value
	if ($last -and $last.Key -eq $key -and ((Get-Date) - $last.Time).TotalSeconds -lt 1) { $last.Time = Get-Date; return }
	[void]$S.Undo.Add(@{ Layer = $layer; Desc = $desc; Old = $old; Key = $key; Time = (Get-Date) })
	if ($S.Undo.Count -gt 300) { $S.Undo.RemoveAt(0) }
}

function Invoke-Undo
{
	if (-not $S.Undo.Count) { Set-Status 'Отменять нечего.'; return }
	$e = $S.Undo[$S.Undo.Count - 1]
	$S.Undo.RemoveAt($S.Undo.Count - 1)
	if ($e.Desc.Kind -eq 'point') { Set-ArrayPoint $e.Layer $e.Desc.Offset $e.Desc.Point $e.Desc.MemberOffset $e.Old }
	else { Set-Value $e.Layer $e.Desc $e.Old }
	Update-Rows
	Update-LayerTitles
	Set-Status "Отменено: $($e.Desc.Label)"
}

# Puts every studio value of $buf (an object image) and the points of $arrays onto the layer.
function Set-LayerState($layer, [byte[]] $buf, [hashtable] $arrays)
{
	foreach ($why in @($layer.Hide.Keys)) { Remove-Hide $layer $why }
	# read everything first : once Disabled hides the layer, Get-Value answers Opacity from the side value
	$todo = New-Object System.Collections.ArrayList
	foreach ($d in $DESCS)
	{
		if ($d.Only -and $d.Only -ne $layer.Class) { continue }
		if ($d.Kind -in 'colors', 'sizes') { continue }
		if (-not (Get-Offset $layer $d)) { continue }
		[void]$todo.Add(@($d, (Get-Value $layer $d $buf)))
	}
	# centre before half : each keeps the other as it stands
	foreach ($t in $todo) { Set-Value $layer $t[0] $t[1] }
	foreach ($prop in 'ColorScale', 'SizeScale')
	{
		$pts = $arrays[$prop]
		if (-not $pts) { continue }
		$f = Get-Field 'ParticleEmitter' $prop
		for ($i = 0; $i -lt $pts.Count; $i++)
		{
			$elem = New-Object byte[] 8
			[Array]::Copy($pts.Bytes, 8 * $i, $elem, 0, 8)
			Set-ArrayPoint $layer $f.Offset $i 0 $elem
		}
	}
}

function Reset-Layer($layer)
{
	Set-LayerState $layer $layer.Snapshot $layer.SnapArrays
	$S.Touched.Remove($layer.Index)
}

# The other way round from Save-Effect : glow_fx\<effect>.txt back into memory. What the file leaves out is
# the package value ; what it says differently from the package counts as touched, so a later save keeps it.
function Import-Effect
{
	if (-not $S.Layers.Count) { return }
	$effect = Get-EffectPath $S.Layers[0].Index
	$path = Join-Path $glowDir "$effect.txt"
	if (-not (Test-Path $path)) { Set-Status "Нет файла: $path"; return }
	$sections = @{}
	foreach ($sec in (Read-EditFile $path)) { $sections[$sec.Path.ToLowerInvariant()] = $sec }
	Stop-Solo
	$loaded = 0
	$notes = New-Object System.Collections.ArrayList
	foreach ($l in $S.Layers)
	{
		$sec = $sections[$l.Exp.Path.ToLowerInvariant()]
		if (-not $sec) { [void]$notes.Add("$($l.Name): нет в файле"); continue }
		# the snapshot already holds the package : only what the file says differently is laid over it
		$package = Get-PackageValues $l.Exp
		$values = @{}
		foreach ($line in $sec.Lines) { if ($package[$line.Key] -ne $line.Value) { $values[$line.Key] = $line.Value } }
		$state = ConvertTo-LayerState $l $values $l.Snapshot $true
		$arrays = @{}
		foreach ($prop in 'ColorScale', 'SizeScale')
		{
			$live = Get-ArrayPoints $l (Get-Field 'ParticleEmitter' $prop).Offset
			if (-not $state.Arrays.ContainsKey($prop)) { $arrays[$prop] = $l.SnapArrays[$prop] }
			elseif ($state.Arrays[$prop].Count -le $live.Count) { $arrays[$prop] = $state.Arrays[$prop] }
			else
			{
				$arrays[$prop] = $l.SnapArrays[$prop]
				[void]$notes.Add("$($l.Name): $prop - в файле $($state.Arrays[$prop].Count) точек, в памяти место под $($live.Count)")
			}
		}
		Set-LayerState $l $state.Buf $arrays
		$touched = @{}
		foreach ($prop in $values.Keys) { if (Get-Field $l.Class $prop) { $touched[$prop] = $true } }
		if ($touched.Count) { $S.Touched[$l.Index] = $touched } else { $S.Touched.Remove($l.Index) }
		foreach ($s in $state.Skipped) { [void]$notes.Add("$($l.Name): $s") }
		$loaded++
	}
	Update-Rows
	Update-LayerTitles
	$text = "Загружено слоёв: $loaded из $($S.Layers.Count) ($path)"
	if ($notes.Count) { $text += '. Пропущено: ' + ($notes -join '; ') }
	Set-Status $text
}

# ----------------------------------------------------------------------------------------------- saving / baking

function Format-MemValue($layer, [string] $prop, [byte[]] $buf)
{
	$f = Get-Field $layer.Class $prop
	$o = $f.Offset
	if ($prop -eq 'Opacity' -and $layer.Hide.Count) { return (Format-Float ([single]$layer.HiddenOpacity)) }
	if ($f.Bit -ge 0) { if (((([BitConverter]::ToUInt32($buf, $o)) -shr $f.Bit) -band 1) -eq 1) { return 'True' } else { return 'False' } }
	$fl = { param($at) Format-Float ([BitConverter]::ToSingle($buf, $at)) }
	switch -Regex ($f.Type)
	{
		'^Float$' { return (& $fl $o) }
		'^Int$' { return [string][BitConverter]::ToInt32($buf, $o) }
		'^Byte'
		{
			$v = [int]$buf[$o]
			if ($ENUMS.ContainsKey($prop) -and $v -lt $ENUMS[$prop].Count) { return $ENUMS[$prop][$v] }
			return [string]$v
		}
		'^Object<' { return (Get-ObjectName ([BitConverter]::ToUInt32($buf, $o))) }
		'^Struct<Vector>$' { return ('(X={0},Y={1},Z={2})' -f (& $fl $o), (& $fl ($o + 4)), (& $fl ($o + 8))) }
		'^Struct<Range>$' { return ('(Min={0},Max={1})' -f (& $fl $o), (& $fl ($o + 4))) }
		'^Struct<RangeVector>$' { return ('(X=(Min={0},Max={1}),Y=(Min={2},Max={3}),Z=(Min={4},Max={5}))' -f @(0..5 | ForEach-Object { & $fl ($o + 4 * $_) })) }
		'^Array<'
		{
			$pts = Get-ArrayPoints $layer $o
			$items = for ($i = 0; $i -lt $pts.Count; $i++)
			{
				$tm = Format-Float ([BitConverter]::ToSingle($pts.Bytes, 8 * $i))
				if ($prop -eq 'ColorScale')
				{
					$b = $pts.Bytes
					'(RelativeTime={0},Color=(B={1},G={2},R={3},A={4}))' -f $tm, $b[8 * $i + 4], $b[8 * $i + 5], $b[8 * $i + 6], $b[8 * $i + 7]
				}
				else { '(RelativeTime={0},RelativeSize={1})' -f $tm, (Format-Float ([BitConverter]::ToSingle($pts.Bytes, 8 * $i + 4))) }
			}
			return '(' + ($items -join ',') + ')'
		}
	}
	return $null
}

function Save-Effect
{
	if (-not $S.Layers.Count) { return }
	$effect = Get-EffectPath $S.Layers[0].Index
	if (-not (Test-Path $glowDir)) { New-Item -ItemType Directory -Path $glowDir | Out-Null }
	$path = Join-Path $glowDir "$effect.txt"
	$lines = New-Object System.Collections.ArrayList
	[void]$lines.Add("; $effect - сохранено из Glow Studio $(Get-Date -Format 'yyyy-MM-dd HH:mm').")
	[void]$lines.Add('; Строки пакета каждого слоя, значения, тронутые в студии, - из памяти клиента.')
	[void]$lines.Add('; Запекается кнопкой «Запечь» или enchant_glow_fx.ps1 -Apply поверх EnchantGlow.u.plain.bak.')
	[void]$lines.Add('')
	foreach ($l in $S.Layers)
	{
		$buf = Read-Mem $l.Template $OBJECT_SIZE
		$ordered = New-Object System.Collections.Specialized.OrderedDictionary
		foreach ($line in (Format-Emitter $pkg $l.Exp))
		{
			if ($line -match '^(\w+)=(.*)$') { $ordered[$Matches[1]] = $Matches[2] }
		}
		$touched = $S.Touched[$l.Index]
		if ($touched)
		{
			foreach ($prop in $touched.Keys)
			{
				$text = Format-MemValue $l $prop $buf
				if ($null -ne $text -and -not $text.StartsWith('0x')) { $ordered[$prop] = $text }
			}
		}
		[void]$lines.Add("[$($l.Exp.Path)]")
		[void]$lines.Add("; $($l.Class)")
		foreach ($k in $ordered.Keys) { [void]$lines.Add("$k=$($ordered[$k])") }
		[void]$lines.Add('')
	}
	[IO.File]::WriteAllLines($path, [string[]]$lines, (New-Object System.Text.UTF8Encoding $false))
	Set-Status "Сохранено: $path"
}

function Invoke-Bake
{
	if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
	{
		[Windows.Forms.MessageBox]::Show('Сначала сохрани эффект и закрой клиент: пакет, открытый клиентом, не перезаписать.', 'Glow Studio') | Out-Null
		return
	}
	$files = @(Get-ChildItem $glowDir -Filter '*.txt' -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^enchant\d+_\d+t\.txt$' })
	if (-not $files) { [Windows.Forms.MessageBox]::Show('В glow_fx нет сохранённых эффектов (enchant*_*t.txt).', 'Glow Studio') | Out-Null; return }
	$merged = Join-Path ([IO.Path]::GetTempPath()) 'glow_studio_bake.txt'
	[IO.File]::WriteAllLines($merged, [string[]]@($files | ForEach-Object { [IO.File]::ReadAllLines($_.FullName, [Text.Encoding]::UTF8) }), (New-Object System.Text.UTF8Encoding $false))
	$plain = Join-Path $SystemDir 'EnchantGlow.u.plain.bak'
	$out = & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $studioRoot 'enchant_glow_fx.ps1') -Package $plain -Apply $merged -OutFile $packagePath 2>&1 | Out-String
	[Windows.Forms.MessageBox]::Show("Запечено из: $(($files | ForEach-Object Name) -join ', ')`n`n$out", 'Glow Studio') | Out-Null
}

# ----------------------------------------------------------------------------------------------- window

$form = New-Object Windows.Forms.Form
$form.Text = 'Glow Studio - EnchantGlow'
$form.Size = New-Object Drawing.Size(900, 960)
$form.StartPosition = 'Manual'
$form.Location = New-Object Drawing.Point(20, 20)
$form.TopMost = $true
$form.KeyPreview = $true
$form.Font = New-Object Drawing.Font('Segoe UI', 9)

$left = New-Object Windows.Forms.Panel
$left.Dock = 'Left'
$left.Width = 300
$left.Padding = New-Object Windows.Forms.Padding(8)
$form.Controls.Add($left)

$status = New-Object Windows.Forms.StatusStrip
$statusLabel = New-Object Windows.Forms.ToolStripStatusLabel
$statusLabel.Spring = $true
$statusLabel.TextAlign = 'MiddleLeft'
[void]$status.Items.Add($statusLabel)
$form.Controls.Add($status)
function Set-Status([string] $text) { $statusLabel.Text = $text; $form.Refresh() }

# The client may be closed while the studio stays open (to bake, say) : memory reads then come back empty.
# Every handler goes through this, so a failure lands in the status line instead of a WinForms crash box.
function Test-Client
{
	$proc.Refresh()
	if (-not $proc.HasExited) { return $true }
	Set-Status 'Клиент закрыт - правки в память не идут. «Запечь в пакет» работает; для правок запусти клиент и студию заново.'
	return $false
}

function Show-Failure($err)
{
	if (Test-Client) { Set-Status $err.Exception.Message }
}

$right = New-Object Windows.Forms.Panel
$right.Dock = 'Fill'
$right.AutoScroll = $true
$right.Padding = New-Object Windows.Forms.Padding(6)
$form.Controls.Add($right)
$right.BringToFront()

function New-Button([string] $text, [int] $x, [int] $y, [int] $w, [scriptblock] $onClick)
{
	$b = New-Object Windows.Forms.Button
	$b.Text = $text
	$b.Location = New-Object Drawing.Point($x, $y)
	$b.Size = New-Object Drawing.Size($w, 30)
	$b.Tag = $onClick
	$b.Add_Click({ try { & $this.Tag } catch { Show-Failure $_ } })
	$left.Controls.Add($b)
	return $b
}

$effectLabel = New-Object Windows.Forms.Label
$effectLabel.Text = 'Эффект (загруженные в клиенте):'
$effectLabel.Location = New-Object Drawing.Point(8, 8)
$effectLabel.AutoSize = $true
$left.Controls.Add($effectLabel)

$effectBox = New-Object Windows.Forms.ComboBox
$effectBox.DropDownStyle = 'DropDownList'
$effectBox.Location = New-Object Drawing.Point(8, 28)
$effectBox.Width = 280
$effectBox.Add_SelectedIndexChanged({
		if (-not $effectBox.SelectedItem -or -not (Test-Client)) { return }
		try { Select-Effect ([string]$effectBox.SelectedItem) } catch { Show-Failure $_ }
	})
$left.Controls.Add($effectBox)

[void](New-Button 'Обновить список эффектов' 8 58 280 { Update-Effects })

$layerLabel = New-Object Windows.Forms.Label
$layerLabel.Text = 'Слои эффекта:'
$layerLabel.Location = New-Object Drawing.Point(8, 98)
$layerLabel.AutoSize = $true
$left.Controls.Add($layerLabel)

$layerBox = New-Object Windows.Forms.ListBox
$layerBox.Location = New-Object Drawing.Point(8, 118)
$layerBox.Size = New-Object Drawing.Size(280, 200)
$layerBox.Add_SelectedIndexChanged({
		if ($S.Loading -or -not (Test-Client)) { return }
		if ($layerBox.SelectedIndex -ge 0 -and $layerBox.SelectedIndex -lt $S.Layers.Count)
		{
			try
			{
				$S.Current = $S.Layers[$layerBox.SelectedIndex]
				if ($S.Solo) { Stop-Solo; Start-Solo }
				Build-Rows
			}
			catch { Show-Failure $_ }
		}
	})
$left.Controls.Add($layerBox)

$soloButton = New-Button 'Соло' 8 326 136 { if ($S.Solo) { Stop-Solo } else { Start-Solo }; Update-LayerTitles }
[void](New-Button 'Отменить (Ctrl+Z)' 152 326 136 { Invoke-Undo })
[void](New-Button 'Сбросить слой' 8 362 136 { if ($S.Current) { Reset-Layer $S.Current; Update-Rows; Update-LayerTitles; Set-Status 'Слой сброшен к пакету.' } })
[void](New-Button 'Сбросить эффект' 152 362 136 { Stop-Solo; foreach ($l in $S.Layers) { Reset-Layer $l }; Update-Rows; Update-LayerTitles; Set-Status 'Эффект сброшен к пакету.' })
# the client may have loaded the package again : templates are looked up anew along with the copies
[void](New-Button 'Найти горящие копии заново' 8 398 280 { Update-Effects })
[void](New-Button 'Сохранить в файл' 8 446 136 { Save-Effect })
[void](New-Button 'Запечь в пакет' 152 446 136 { Invoke-Bake })
[void](New-Button 'Получить из файла' 8 482 280 { Import-Effect })

$help = New-Object Windows.Forms.Label
$help.Location = New-Object Drawing.Point(8, 526)
$help.Size = New-Object Drawing.Size(280, 330)
$help.Text = @'
Оси: X - вдоль клинка к острию, Y и Z - поперёк.

Тяни ползунок или впиши число - оружие в руке меняется сразу.

Соло - погасить остальные слои, чтобы видеть один.

Если эффект пересоздался (переоделся, сменил ступень) и правки перестали быть видны - «Найти горящие копии заново»: клиент мог загрузить пакет заново, и студия ищет его снова.

Больше частиц, чем было, горящий эффект не примет - переоденься, новый эффект возьмёт новое число.

Текстуру можно поставить только из загруженных в клиенте.

«Сохранить» пишет glow_fx\<эффект>.txt, «Запечь» (клиент закрыт) собирает из таких файлов EnchantGlow.u.
'@
$left.Controls.Add($help)

$form.Add_KeyDown({
		if ($_.Control -and $_.KeyCode -eq 'Z')
		{
			$_.Handled = $true
			try { Invoke-Undo } catch { Show-Failure $_ }
		}
	})

function Update-LayerTitles
{
	$S.Loading = $true
	try { for ($i = 0; $i -lt $S.Layers.Count; $i++) { $layerBox.Items[$i] = Get-LayerTitle $S.Layers[$i] } }
	finally { $S.Loading = $false }
}

# ----------------------------------------------------------------------------------------------- rows

$ROW_Y = 0

function Add-Heading([string] $text)
{
	$l = New-Object Windows.Forms.Label
	$l.Text = $text
	$l.Font = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
	$l.Location = New-Object Drawing.Point(6, ($script:ROW_Y + 6))
	$l.AutoSize = $true
	$right.Controls.Add($l)
	$script:ROW_Y += 32
}

function Add-Label([string] $text)
{
	$l = New-Object Windows.Forms.Label
	$l.Text = $text
	$l.Location = New-Object Drawing.Point(12, ($script:ROW_Y + 4))
	$l.Size = New-Object Drawing.Size(210, 20)
	$right.Controls.Add($l)
}

function Get-Decimals([double] $step) { if ($step -ge 1) { return 0 } elseif ($step -ge 0.1) { return 1 } elseif ($step -ge 0.01) { return 2 } else { return 3 } }

function Add-NumberRow($desc, $layer)
{
	Add-Label $desc.Label
	$ticks = [int][Math]::Round(($desc.Max - $desc.Min) / $desc.Step)
	$bar = New-Object Windows.Forms.TrackBar
	$bar.Location = New-Object Drawing.Point(224, $script:ROW_Y)
	$bar.Size = New-Object Drawing.Size(250, 30)
	$bar.Minimum = 0
	$bar.Maximum = [Math]::Max(1, $ticks)
	$bar.TickStyle = 'None'
	$bar.AutoSize = $false
	$num = New-Object Windows.Forms.NumericUpDown
	$num.Location = New-Object Drawing.Point(480, ($script:ROW_Y + 2))
	$num.Width = 80
	$num.DecimalPlaces = Get-Decimals $desc.Step
	$num.Increment = [decimal]$desc.Step
	$num.Minimum = [decimal]-100000
	$num.Maximum = [decimal]100000
	$row = @{ Desc = $desc; Bar = $bar; Num = $num; Kind = 'number' }
	$bar.Tag = $row
	$num.Tag = $row
	$bar.Add_Scroll({
			$r = $this.Tag
			if ($S.Loading) { return }
			$v = $r.Desc.Min + $this.Value * $r.Desc.Step
			$r.Num.Value = [decimal][Math]::Round($v, $r.Num.DecimalPlaces)
		})
	$num.Add_ValueChanged({
			$r = $this.Tag
			if ($S.Loading -or -not $S.Current -or -not (Test-Client)) { return }
			$v = [double]$this.Value
			try
			{
				$old = Get-Value $S.Current $r.Desc (Read-Mem $S.Current.Template $OBJECT_SIZE)
				Push-Undo $S.Current $r.Desc $old ("$($S.Current.Index).$($r.Desc.Label)")
				Set-Value $S.Current $r.Desc $v
			}
			catch { Show-Failure $_ }
			$S.Loading = $true
			$r.Bar.Value = [int][Math]::Min($r.Bar.Maximum, [Math]::Max(0, [Math]::Round(($v - $r.Desc.Min) / $r.Desc.Step)))
			$S.Loading = $false
		})
	$right.Controls.Add($bar)
	$right.Controls.Add($num)
	[void]$S.Rows.Add($row)
	$script:ROW_Y += 32
}

function Add-BoolRow($desc)
{
	$box = New-Object Windows.Forms.CheckBox
	$box.Text = $desc.Label
	$box.Location = New-Object Drawing.Point(12, ($script:ROW_Y + 2))
	$box.AutoSize = $true
	$row = @{ Desc = $desc; Box = $box; Kind = 'bool' }
	$box.Tag = $row
	$box.Add_CheckedChanged({
			$r = $this.Tag
			if ($S.Loading -or -not $S.Current -or -not (Test-Client)) { return }
			try
			{
				$old = Get-Value $S.Current $r.Desc (Read-Mem $S.Current.Template $OBJECT_SIZE)
				Push-Undo $S.Current $r.Desc $old ("$($S.Current.Index).$($r.Desc.Label)")
				Set-Value $S.Current $r.Desc $this.Checked
				if ($r.Desc.Prop -eq 'Disabled') { Update-LayerTitles }
			}
			catch { Show-Failure $_ }
		})
	$right.Controls.Add($box)
	[void]$S.Rows.Add($row)
	$script:ROW_Y += 26
}

function Add-ChoiceRow($desc, $layer)
{
	Add-Label $desc.Label
	$combo = New-Object Windows.Forms.ComboBox
	$combo.DropDownStyle = 'DropDownList'
	$combo.Location = New-Object Drawing.Point(224, ($script:ROW_Y + 2))
	$combo.Width = 250
	$values = New-Object System.Collections.ArrayList
	if ($desc.Kind -eq 'enum')
	{
		$labels = $ENUM_LABELS[$desc.Prop]
		if (-not $labels) { $labels = $ENUMS[$desc.Prop] }
		for ($i = 0; $i -lt $labels.Count; $i++) { [void]$combo.Items.Add($labels[$i]); [void]$values.Add($i) }
	}
	else
	{
		$want = if ($desc.Prop -eq 'Texture') { 'Texture' } else { 'StaticMesh' }
		foreach ($index in ($script:Loaded.Keys | Sort-Object))
		{
			$exp = $pkg.Exports[$index]
			if ($exp.ClassName -ne $want) { continue }
			$label = $exp.Path
			if ($TEXTURE_LABELS.ContainsKey($exp.Path.ToLowerInvariant())) { $label = "$($exp.Path) - $($TEXTURE_LABELS[$exp.Path.ToLowerInvariant()])" }
			[void]$combo.Items.Add($label)
			[void]$values.Add([uint32]$script:Loaded[$index])
		}
	}
	$row = @{ Desc = $desc; Combo = $combo; Values = $values; Kind = 'choice'; Preview = $null }
	if ($desc.Prop -eq 'Texture')
	{
		$pic = New-Object Windows.Forms.PictureBox
		$pic.Location = New-Object Drawing.Point(480, $script:ROW_Y)
		$pic.Size = New-Object Drawing.Size(80, 80)
		$pic.SizeMode = 'Zoom'
		$pic.BackColor = [Drawing.Color]::Black
		$right.Controls.Add($pic)
		$row.Preview = $pic
	}
	$combo.Tag = $row
	$combo.Add_SelectedIndexChanged({
			$r = $this.Tag
			if ($r.Preview) { Set-Preview $r }
			if ($S.Loading -or -not $S.Current -or $this.SelectedIndex -lt 0 -or -not (Test-Client)) { return }
			try
			{
				$old = Get-Value $S.Current $r.Desc (Read-Mem $S.Current.Template $OBJECT_SIZE)
				Push-Undo $S.Current $r.Desc $old ("$($S.Current.Index).$($r.Desc.Label)")
				Set-Value $S.Current $r.Desc $r.Values[$this.SelectedIndex]
				if ($r.Desc.Prop -in 'Texture', 'StaticMesh') { Update-LayerTitles }
			}
			catch { Show-Failure $_ }
		})
	$right.Controls.Add($combo)
	[void]$S.Rows.Add($row)
	$script:ROW_Y += $(if ($row.Preview) { 84 } else { 32 })
}

function Set-Preview($row)
{
	$row.Preview.Image = $null
	if ($row.Combo.SelectedIndex -lt 0) { return }
	$name = ([string]$row.Combo.SelectedItem).Split(' ')[0].ToLowerInvariant()
	$file = Join-Path $previewDir "$name.png"
	if (Test-Path $file) { $row.Preview.Image = [Drawing.Image]::FromFile($file) }
}

function Add-PointRows($desc, $layer)
{
	$f = Get-Field 'ParticleEmitter' $desc.Prop
	$pts = Get-ArrayPoints $layer $f.Offset
	if (-not $pts.Count)
	{
		Add-Label "$($desc.Label): у слоя нет точек"
		$script:ROW_Y += 26
		return
	}
	for ($i = 0; $i -lt $pts.Count; $i++)
	{
		Add-Label ("  точка {0}: время" -f ($i + 1))
		$time = New-Object Windows.Forms.NumericUpDown
		$time.Location = New-Object Drawing.Point(224, ($script:ROW_Y + 2))
		$time.Width = 70
		$time.DecimalPlaces = 2
		$time.Increment = [decimal]0.05
		$time.Minimum = 0
		$time.Maximum = 1
		$timeDesc = @{ Kind = 'point'; Label = "$($desc.Label) - время $($i + 1)"; Prop = $desc.Prop; Offset = $f.Offset; Point = $i; MemberOffset = 0 }
		$timeRow = @{ Desc = $timeDesc; Kind = 'pointTime'; Control = $time }
		$time.Tag = $timeRow
		$time.Add_ValueChanged({
				if ($S.Loading -or -not $S.Current -or -not (Test-Client)) { return }
				$d = $this.Tag.Desc
				try
				{
					$old = Read-Mem ((Get-U32 ($S.Current.Template + $d.Offset)) + 8 * $d.Point) 4
					Push-Undo $S.Current $d $old ("$($S.Current.Index).$($d.Label)")
					Set-ArrayPoint $S.Current $d.Offset $d.Point 0 ([BitConverter]::GetBytes([single]$this.Value))
					Set-Touched $d.Prop
				}
				catch { Show-Failure $_ }
			})
		$right.Controls.Add($time)
		[void]$S.Rows.Add($timeRow)
		$valueDesc = @{ Kind = 'point'; Label = "$($desc.Label) - значение $($i + 1)"; Prop = $desc.Prop; Offset = $f.Offset; Point = $i; MemberOffset = 4 }
		if ($desc.Kind -eq 'colors')
		{
			$btn = New-Object Windows.Forms.Button
			$btn.Location = New-Object Drawing.Point(300, $script:ROW_Y)
			$btn.Size = New-Object Drawing.Size(120, 28)
			$btn.Text = 'цвет...'
			$btn.Tag = @{ Desc = $valueDesc; Kind = 'pointColor'; Control = $btn }
			$btn.Add_Click({
					if (-not $S.Current -or -not (Test-Client)) { return }
					$d = $this.Tag.Desc
					try
					{
						$old = Read-Mem ((Get-U32 ($S.Current.Template + $d.Offset)) + 8 * $d.Point + 4) 4
						$dlg = New-Object Windows.Forms.ColorDialog
						$dlg.FullOpen = $true
						$dlg.Color = [Drawing.Color]::FromArgb($old[2], $old[1], $old[0])
						if ($dlg.ShowDialog() -ne 'OK') { return }
						Push-Undo $S.Current $d $old ("$($S.Current.Index).$($d.Label).$(Get-Random)")
						$c = $dlg.Color
						Set-ArrayPoint $S.Current $d.Offset $d.Point 4 ([byte[]]@($c.B, $c.G, $c.R, $old[3]))
						Set-Touched $d.Prop
						$this.BackColor = $c
					}
					catch { Show-Failure $_ }
				})
			$right.Controls.Add($btn)
			[void]$S.Rows.Add($btn.Tag)
		}
		else
		{
			$size = New-Object Windows.Forms.NumericUpDown
			$size.Location = New-Object Drawing.Point(300, ($script:ROW_Y + 2))
			$size.Width = 70
			$size.DecimalPlaces = 2
			$size.Increment = [decimal]0.1
			$size.Minimum = 0
			$size.Maximum = 50
			$size.Tag = @{ Desc = $valueDesc; Kind = 'pointSize'; Control = $size }
			$size.Add_ValueChanged({
					if ($S.Loading -or -not $S.Current -or -not (Test-Client)) { return }
					$d = $this.Tag.Desc
					try
					{
						$old = Read-Mem ((Get-U32 ($S.Current.Template + $d.Offset)) + 8 * $d.Point + 4) 4
						Push-Undo $S.Current $d $old ("$($S.Current.Index).$($d.Label)")
						Set-ArrayPoint $S.Current $d.Offset $d.Point 4 ([BitConverter]::GetBytes([single]$this.Value))
						Set-Touched $d.Prop
					}
					catch { Show-Failure $_ }
				})
			$right.Controls.Add($size)
			[void]$S.Rows.Add($size.Tag)
		}
		$script:ROW_Y += 32
	}
}

function Set-Touched([string] $prop)
{
	$touched = $S.Touched[$S.Current.Index]
	if (-not $touched) { $touched = @{}; $S.Touched[$S.Current.Index] = $touched }
	$touched[$prop] = $true
}

function Build-Rows
{
	$right.SuspendLayout()
	foreach ($c in @($right.Controls)) { $c.Dispose() }
	$right.Controls.Clear()
	$S.Rows.Clear()
	$script:ROW_Y = $right.AutoScrollPosition.Y
	$layer = $S.Current
	if (-not $layer) { $right.ResumeLayout(); return }
	Add-Heading "$($layer.Exp.Path)  ($($layer.Class))"
	$group = ''
	foreach ($d in $DESCS)
	{
		if ($d.Only -and $d.Only -ne $layer.Class) { continue }
		if (-not (Get-Offset $layer $d)) { continue }
		if ($d.Group -ne $group) { $group = $d.Group; Add-Heading $group }
		switch ($d.Kind)
		{
			'bool' { Add-BoolRow $d }
			{ $_ -in 'enum', 'object' } { Add-ChoiceRow $d $layer }
			{ $_ -in 'colors', 'sizes' } { Add-PointRows $d $layer }
			default { Add-NumberRow $d $layer }
		}
	}
	$right.ResumeLayout()
	Update-Rows
}

# Reads the template and puts its values into every control, without writing anything back.
function Update-Rows
{
	if (-not $S.Current) { return }
	$S.Loading = $true
	try
	{
		$buf = Read-Mem $S.Current.Template $OBJECT_SIZE
		foreach ($r in $S.Rows)
		{
			switch ($r.Kind)
			{
				'number'
				{
					$v = [double](Get-Value $S.Current $r.Desc $buf)
					$r.Num.Value = [decimal][Math]::Max(-100000, [Math]::Min(100000, [Math]::Round($v, $r.Num.DecimalPlaces)))
					$r.Bar.Value = [int][Math]::Min($r.Bar.Maximum, [Math]::Max(0, [Math]::Round(($v - $r.Desc.Min) / $r.Desc.Step)))
				}
				'bool' { $r.Box.Checked = [bool](Get-Value $S.Current $r.Desc $buf) }
				'choice'
				{
					$v = Get-Value $S.Current $r.Desc $buf
					$at = -1
					for ($i = 0; $i -lt $r.Values.Count; $i++) { if ([uint32]$r.Values[$i] -eq [uint32]$v) { $at = $i } }
					$r.Combo.SelectedIndex = $at
					if ($r.Preview) { Set-Preview $r }
				}
				'pointTime'
				{
					$pts = Get-ArrayPoints $S.Current $r.Desc.Offset
					if ($r.Desc.Point -lt $pts.Count) { $r.Control.Value = [decimal][Math]::Max(0, [Math]::Min(1, [Math]::Round([BitConverter]::ToSingle($pts.Bytes, 8 * $r.Desc.Point), 2))) }
				}
				'pointColor'
				{
					$pts = Get-ArrayPoints $S.Current $r.Desc.Offset
					$o = 8 * $r.Desc.Point + 4
					if ($r.Desc.Point -lt $pts.Count) { $r.Control.BackColor = [Drawing.Color]::FromArgb($pts.Bytes[$o + 2], $pts.Bytes[$o + 1], $pts.Bytes[$o]) }
				}
				'pointSize'
				{
					$pts = Get-ArrayPoints $S.Current $r.Desc.Offset
					if ($r.Desc.Point -lt $pts.Count) { $r.Control.Value = [decimal][Math]::Max(0, [Math]::Min(50, [Math]::Round([BitConverter]::ToSingle($pts.Bytes, 8 * $r.Desc.Point + 4), 2))) }
				}
			}
		}
	}
	finally { $S.Loading = $false }
}

# ----------------------------------------------------------------------------------------------- run

$form.Add_Shown({ Update-Effects })
$form.Add_FormClosing({ try { Stop-Solo } catch { } })
try { [void]$form.ShowDialog() }
finally { [void]$K32::CloseHandle($hProc) }
