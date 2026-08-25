<#
.SYNOPSIS
    Patches an Interlude client's system\interface.u so the enchant window survives an enchant attempt.

.DESCRIPTION
    Goes with the server side "EnchantWindowMode = KEEP" setting (config\players.properties).

    The stock client class ItemEnchantWnd (kept as readable UnrealScript inside interface.u) reacts to the
    EnchantResult packet like this:

        function HandleEnchantResult(string param)
        {
            Me.HideWindow();
            Clear();
        }

    Clear() empties the item list of the window, so any item the player had selected is lost - and reopening the
    window from the server (ChooseInventoryItem) doesn't help either, because HandleEnchantShow() starts with
    Clear() as well. This patch neutralizes HandleEnchantResult so the window and its selection stay alive, which
    lets the player consume scroll after scroll by pressing "Enchant" only.

    interface.u is a stock Unreal package (version 123, licensee 30) wrapped in the "Lineage2Ver111" container:
    a 28 byte UTF-16 header, the package XOR'ed with 0xAC, then a 20 byte plain trailer. Since the cipher is a
    constant XOR, we patch the encrypted bytes in place and the file length never changes.

    Two edits, both inside export 5321 (HandleEnchantResult, package offset 312035, 44 bytes):
      - the UStruct ScriptSize field (memory size of the bytecode) : 23 -> 15
      - the bytecode itself : "Me.HideWindow(); Clear();" -> EX_Return / EX_Nothing, padded with EX_Nothing

    The script refuses to run if the bytes aren't exactly the ones it expects, and it is idempotent.

.PARAMETER SystemDir
    The client's "system" directory, the one holding interface.u.

.PARAMETER Revert
    Restore interface.u from the backup made on the first run.

.EXAMPLE
    .\patch_enchant_window.ps1 -SystemDir 'C:\Lineage2\system'
    .\patch_enchant_window.ps1 -SystemDir 'C:\Lineage2\system' -Revert
#>
param(
    [Parameter(Mandatory = $true)][string]$SystemDir,
    [switch]$Revert
)

$ErrorActionPreference = 'Stop'

$target = Join-Path $SystemDir 'interface.u'
$backup = Join-Path $SystemDir 'interface.u.orig.bak'

if (-not (Test-Path $target)) { throw "not found: $target" }

if ($Revert) {
    if (-not (Test-Path $backup)) { throw "no backup to restore: $backup" }
    Copy-Item $backup $target -Force
    Write-Output "restored $target from $backup"
    return
}

$KEY = 0xAC
$HDR = 28
$PKG_OFF = 312035          # export 5321, ItemEnchantWnd.HandleEnchantResult
$SCRIPTSIZE_AT = $PKG_OFF + 18   # int32 ScriptSize
$SCRIPT_AT = $PKG_OFF + 22   # bytecode

# Me.HideWindow(); Clear();
$origSize = [byte[]](0x17, 0x00, 0x00, 0x00)
$origCode = [byte[]](0x19, 0x01, 0x53, 0x0A, 0x06, 0x00, 0x00, 0x1C, 0x9A, 0x16, 0x1B, 0x05, 0x16, 0x04, 0x0B)

# return; (padded so the bytecode keeps its 15 bytes on disk)
$newSize = [byte[]](0x0F, 0x00, 0x00, 0x00)
$newCode = [byte[]](0x04, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B, 0x0B)

$b = [System.IO.File]::ReadAllBytes($target)

$magic = [System.Text.Encoding]::Unicode.GetString($b, 0, $HDR)
if ($magic -ne 'Lineage2Ver111') { throw "unexpected container header '$magic', this script only handles Lineage2Ver111" }

function Plain($off, $len) {
    $r = New-Object byte[] $len
    for ($i = 0; $i -lt $len; $i++) { $r[$i] = [byte]($b[$HDR + $off + $i] -bxor $KEY) }
    return $r
}
function Poke($off, [byte[]]$vals) {
    for ($i = 0; $i -lt $vals.Length; $i++) { $b[$HDR + $off + $i] = [byte]($vals[$i] -bxor $KEY) }
}
function Hex([byte[]]$a) { return (($a | ForEach-Object { $_.ToString('X2') }) -join ' ') }

$curSize = Plain $SCRIPTSIZE_AT 4
$curCode = Plain $SCRIPT_AT 15

if ((Hex $curSize) -eq (Hex $newSize) -and (Hex $curCode) -eq (Hex $newCode)) {
    Write-Output "already patched, nothing to do"
    return
}
if ((Hex $curSize) -ne (Hex $origSize)) { throw "unexpected ScriptSize $(Hex $curSize), refusing to patch" }
if ((Hex $curCode) -ne (Hex $origCode)) { throw "unexpected bytecode $(Hex $curCode), refusing to patch" }

if (-not (Test-Path $backup)) {
    Copy-Item $target $backup
    Write-Output "backup: $backup"
}

Poke $SCRIPTSIZE_AT $newSize
Poke $SCRIPT_AT $newCode
[System.IO.File]::WriteAllBytes($target, $b)

Write-Output "patched: $target"
Write-Output ("  ScriptSize {0} -> {1}" -f (Hex $origSize), (Hex $newSize))
Write-Output ("  bytecode   {0} -> {1}" -f (Hex $origCode), (Hex $newCode))
