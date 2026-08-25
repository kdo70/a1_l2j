<#
.SYNOPSIS
    Wraps a plain Unreal package (ucc output) back into the Lineage 2 "Lineage2Ver111" container.

.DESCRIPTION
    A stock Interlude client stores its packages as:
        [28 bytes] "Lineage2Ver111" in UTF-16
        [body]     the Unreal package, every byte XOR'ed with 0xAC
        [20 bytes] a plain trailer

    ucc produces the plain package only, so it has to be wrapped before the client will read it. The trailer
    is copied verbatim from a reference file - use the original interface.u for that, its meaning is not
    documented anywhere and guessing it is a good way to end up with a client that refuses to start.

    Try the plain ucc output in system\ first: some clients accept unwrapped packages, and then this script
    isn't needed at all.

.PARAMETER In
    The plain package produced by ucc, e.g. ...\Interface.u

.PARAMETER Out
    Where to write the wrapped package, e.g. C:\Lineage2\system\interface.u

.PARAMETER TrailerFrom
    A stock client package to copy the 20 byte trailer from, e.g. interface.u.orig.bak

.EXAMPLE
    .\pack_l2_package.ps1 -In 'C:\l2mod\Interface.u' -Out 'C:\Lineage2\system\interface.u' `
                          -TrailerFrom 'C:\Lineage2\system\interface.u.orig.bak'
#>
param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    [Parameter(Mandatory = $true)][string]$TrailerFrom
)

$ErrorActionPreference = 'Stop'

$body = [System.IO.File]::ReadAllBytes($In)
if (("{0:X8}" -f [BitConverter]::ToUInt32($body, 0)) -ne '9E2A83C1') {
    throw "$In is not a plain Unreal package (bad signature) - is it already wrapped?"
}

$ref = [System.IO.File]::ReadAllBytes($TrailerFrom)
if ([System.Text.Encoding]::Unicode.GetString($ref, 0, 28) -ne 'Lineage2Ver111') {
    throw "$TrailerFrom is not a Lineage2Ver111 file, cannot take a trailer from it"
}
$trailer = $ref[($ref.Length - 20)..($ref.Length - 1)]

$header = [System.Text.Encoding]::Unicode.GetBytes('Lineage2Ver111')

$out = New-Object byte[] ($header.Length + $body.Length + 20)
[Array]::Copy($header, 0, $out, 0, $header.Length)
for ($i = 0; $i -lt $body.Length; $i++) { $out[$header.Length + $i] = [byte]($body[$i] -bxor 0xAC) }
[Array]::Copy($trailer, 0, $out, $header.Length + $body.Length, 20)

[System.IO.File]::WriteAllBytes($Out, $out)
Write-Output ("wrapped {0} ({1} bytes) -> {2} ({3} bytes)" -f $In, $body.Length, $Out, $out.Length)
Write-Output ("trailer taken from {0}: {1}" -f $TrailerFrom, (($trailer | ForEach-Object { $_.ToString('X2') }) -join ' '))
