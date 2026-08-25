<#
.SYNOPSIS
    Rebuilds the client's interface.u from the sources in .\Interface\Classes using an L2-capable ucc.

.DESCRIPTION
    Sets up a throwaway build tree, so neither the client nor the editor kit is touched:

        <Work>\System\      ucc + the engine dlls from the kit, plus every .u from the client
        <Work>\Interface\Classes\*.uc   the sources to compile
        <Work>\System\build.ini         generated, points ucc at the packages above

    The client's own packages are copied in encrypted - this ucc carries Lineage2111WindowsFileReader and
    reads the Lineage2Ver111 container by itself. interface.u is deliberately NOT copied: ucc refuses to
    overwrite an existing package, and that is the one we are producing.

    The result lands in <Work>\System\Interface.u. It is NOT installed anywhere - check the log, then wrap
    and copy it yourself (see README.md).

.PARAMETER KitDir
    The editor kit holding UCC.exe, Core.dll, Engine.dll, Editor.dll...

.PARAMETER ClientSystemDir
    The client's system folder, the source of the .u packages to compile against.

.PARAMETER Work
    Build tree location. Wiped and recreated on every run. Defaults to .\_build next to this script.

.EXAMPLE
    .\build_interface.ps1 -KitDir 'C:\Users\Me\Desktop\L2Editor' -ClientSystemDir 'C:\Lineage2\system'
#>
param(
    [Parameter(Mandatory = $true)][string]$KitDir,
    [Parameter(Mandatory = $true)][string]$ClientSystemDir,
    [string]$Work,
    # Files pulled from the client because the kit has no equivalent. Everything else must come from the kit:
    # its Core.dll/Engine.dll only bind against its own packages, and mixing the two ends in
    # "Can't find 'intUObjectexecRotator2Vector' in 'Core.dll'".
    [string[]]$FromClient = @('uwindow.u'),
    # Packages compiled from the .uc sources in this folder. NWindow is rebuilt rather than loaded from the
    # client because the kit's engine crashes on the client's binary nwindow.u ; only the names its classes
    # export matter here, and those come from the client's own sources.
    # Core is rebuilt from the kit's own class sources plus ParamStack, which Interlude's Core has and the
    # kit's does not. Rebuilding it there rather than shimming it elsewhere is what makes the compiled
    # Interface import Core.ParamStack - the name the real client resolves at runtime.
    [string[]]$SourcePackages = @('Core', 'NWindow', 'Interface'),
    [string[]]$EditPackages = @('Core', 'Engine', 'Fire', 'Editor', 'UWindow', 'NWindow', 'Interface'),
    # Class modifiers this ucc predates and rejects with "Missing ';' in 'Class'". Dropped from the sources
    # on the way into the build tree ; the originals under this folder are left alone.
    [string[]]$StripModifiers = @('dynamicrecompile', 'constructive'),
    # Packages whose `native` keywords are dropped, giving every declaration an empty body. Binding natives
    # needs the package's dll, and the client's nwindow.dll cannot load here - it is linked against the
    # client's core/engine, not the kit's. Interface only imports NWindow by name and signature, and those
    # are unchanged, so the throwaway NWindow.u this produces is good enough to compile against.
    [string[]]$DenativizePackages = @('NWindow'),
    # Same treatment, single class. ParamStack's natives live in the client's core.dll, not the kit's ; its
    # functions are unnumbered natives, so calls to them compile to the same opcodes either way.
    [string[]]$DenativizeClasses = @('ParamStack')
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Work) { $Work = Join-Path $here '_build' }

foreach ($pkg in $SourcePackages) {
    $d = Join-Path $here "$pkg\Classes"
    if (-not (Test-Path $d)) { throw "sources not found: $d (run extract_interface_source.ps1 first)" }
}

# ucc and the kit dlls are 32 bit and link against the VC++ 2013 runtime.
$hasRuntime = @('C:\Windows\SysWOW64\msvcr120.dll', 'C:\Windows\System32\msvcr120.dll', (Join-Path $KitDir 'msvcr120.dll')) |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $hasRuntime) {
    throw "msvcr120.dll is missing - install the Visual C++ Redistributable Packages for Visual Studio 2013, x86 (vcredist_x86.exe). Without it ucc dies with 0xC0000135 before printing anything."
}

$sys = Join-Path $Work 'System'

if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory -Force $sys | Out-Null

# 1. The kit, whole: binaries and its own packages. The kit's Engine.u carries LineagePlayerController, so it
#    is a genuine L2 set - just saved with licensee 0 - and it is internally consistent with its dlls.
#    The .ini files come along because UE2's appInit refuses to start without User.ini and the Default.ini /
#    DefUser.ini it clones missing ones from - that is the "Missing .ini file" error.
foreach ($pattern in '*.dll', '*.int', '*.ini', '*.u', 'UCC.exe') {
    Get-ChildItem $KitDir -Filter $pattern -File | ForEach-Object {
        # A package we compile ourselves must not already sit in System - ucc refuses to overwrite one.
        # Only .u files: the matching .dll still has to be there for the natives to bind.
        if ($_.Extension -ieq '.u' -and $SourcePackages -contains $_.BaseName) { return }
        Copy-Item $_.FullName $sys
    }
}

# 2. Only what the kit lacks. interface.u is never copied: ucc refuses to overwrite the package it builds.
foreach ($name in $FromClient) {
    if ($name -ieq 'interface.u') { continue }
    $src = Join-Path $ClientSystemDir $name
    if (-not (Test-Path $src)) { throw "not found in the client: $src" }
    Copy-Item $src $sys -Force
}
Write-Output ("taken from the client: {0}" -f ($FromClient -join ', '))

# 3. The sources, one Classes folder per package to build. Copied through Latin-1 so the bytes survive
#    untouched - these files carry Korean comments in the client's own codepage.
$latin1 = [System.Text.Encoding]::GetEncoding(28591)
foreach ($pkg in $SourcePackages) {
    $dst = Join-Path $Work "$pkg\Classes"
    New-Item -ItemType Directory -Force $dst | Out-Null

    $stripped = 0
    foreach ($f in Get-ChildItem (Join-Path $here "$pkg\Classes") -Filter '*.uc') {
        $text = $latin1.GetString([System.IO.File]::ReadAllBytes($f.FullName))
        foreach ($mod in $StripModifiers) {
            $new = [regex]::Replace($text, "(?i)\b$([regex]::Escape($mod))\b", '')
            if ($new -ne $text) { $stripped++; $text = $new }
        }
        if (($DenativizePackages -contains $pkg) -or ($DenativizeClasses -contains $f.BaseName)) {
            # "native ... function foo(...);" -> "... function foo(...) {}"
            $text = [regex]::Replace($text, '(?im)^([ \t]*)native(\s+[^\r\n;{]*?\bfunction\b[^\r\n;{]*);', '$1$2 {}')
            # whatever native is left marks a class, struct or var - just drop the keyword, and with it
            # noexport, which ucc only accepts on a native class
            $text = [regex]::Replace($text, '(?i)\bnative\b', '')
            $text = [regex]::Replace($text, '(?i)\bnoexport\b', '')
        }
        [System.IO.File]::WriteAllBytes((Join-Path $dst $f.Name), $latin1.GetBytes($text))
    }
    Write-Output ("{0}: {1} sources ({2} had a rejected modifier stripped)" -f $pkg, (Get-ChildItem $dst -Filter '*.uc').Count, $stripped)
}

# 4. The ini. Derived from the kit's Default.ini rather than written from scratch, so every section appInit
#    expects is present ; only the EditPackages list is swapped for ours. Interface is the sole package with
#    a Classes folder, so it is the only one actually compiled - the rest are listed to be loaded as
#    dependencies, in dependency order.
$editPackagesLines = $EditPackages | ForEach-Object { "EditPackages=$_" }

$template = Join-Path $KitDir 'Default.ini'
if (-not (Test-Path $template)) { throw "no Default.ini in $KitDir to base the build ini on" }
$ini = Get-Content $template

$out = New-Object 'System.Collections.Generic.List[string]'
$swapped = $false
foreach ($line in $ini) {
    if ($line -match '^\s*EditPackages\s*=') {
        if (-not $swapped) { $editPackagesLines | ForEach-Object { $out.Add($_) }; $swapped = $true }
        continue
    }
    $out.Add($line)
}
if (-not $swapped) { throw "no EditPackages found in $template" }

$iniPath = Join-Path $sys 'build.ini'
Set-Content -Path $iniPath -Value $out -Encoding ascii

# 5. Build.
$log = Join-Path $Work 'ucc.log'
$proc = Start-Process -FilePath (Join-Path $sys 'UCC.exe') -ArgumentList 'make', '-ini=build.ini' `
    -WorkingDirectory $sys -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $log -RedirectStandardError (Join-Path $Work 'ucc.err')

Write-Output ("ucc exit = 0x{0:X8}" -f $proc.ExitCode)
if (Test-Path $log) { Get-Content $log | Select-Object -Last 40 }
$err = Join-Path $Work 'ucc.err'
if ((Test-Path $err) -and (Get-Item $err).Length -gt 0) {
    Write-Output '--- stderr ---'
    Get-Content $err | Select-Object -Last 20
}

$built = Join-Path $sys 'Interface.u'
if (Test-Path $built) {
    Write-Output ("BUILT: {0} ({1} bytes)" -f $built, (Get-Item $built).Length)
    Write-Output "Check its version with: extract_interface_source.ps1 -Package '$built' -OutDir <tmp>"
    Write-Output "It must report package version 123, licensee 30."
}
else {
    Write-Output "no Interface.u produced - read $log"
}
