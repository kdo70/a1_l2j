<#
.SYNOPSIS
	Makes the on-screen messages (ExShowScreenMessage) readable in Cyrillic, by
	switching the font of OnScreenMessageWnd1..8 in the client's interface.xdat.

.DESCRIPTION
	The eight OnScreenMessageWnd windows draw their big line with fontType
	LargeFontType_4. That is not a font but a slot : the client resolves
	LargeFontType_1..4 to the TrueType fonts declared in TTFontInfo.ini under the
	usages zonetitle / benchmark / broadcast1 / broadcast2 - names that sit in
	d3ddrv.dll next to FD3DFont::CreateFont. An international client leaves
	broadcast2 commented out, so those boxes end up on a GDI default that draws
	Latin and nothing else : a Russian message shows an empty line while an
	English one shows fine.

	Everything else in the interface draws with the bitmap fonts Localization.ini
	names (Font / Font2, here L2Font-r.SmallFont-r and L2Font-r.LargeFont-r), and
	their glyph tables do carry U+0401..U+044F - which is why the very same text
	is readable in chat. So this script points the boxes at one of those instead :
	SpecialBigerFont is Font2, Normal is Font.

	The small variants (TextBoxsm*, picked when the server asks for the small
	size) already sit on Normal and are left untouched.

	The file is parsed and rewritten by the XDAT Editor's own libraries. The
	script first proves a no-op rewrite reproduces the input byte for byte, then
	checks that exactly one byte per text box moved.

.PARAMETER ClientSystemDir
	The client's "system" folder, the one holding interface.xdat.

.PARAMETER FontType
	Which font the big boxes get. SpecialBigerFont (default) is the large bitmap
	font; Normal is the smaller one the chat window draws with - use it if the
	large one comes out blank as well. LargeFontType_4 puts the stock value back.

.PARAMETER EditorDir
	Folder of the XDAT Editor by acmi, the one holding schema.jar and its jre.

.PARAMETER OutFile
	Write the result here instead of over the client's file. Implies -NoBackup.

.PARAMETER NoBackup
	Skip creating interface.xdat.prefont.bak.

.EXAMPLE
	powershell -ExecutionPolicy Bypass -File patch_screen_message_font.ps1 `
		-ClientSystemDir "C:\l2\system"
#>
param(
	[Parameter(Mandatory = $true)][string] $ClientSystemDir,
	[ValidateSet('Normal', 'SpecialBigerFont', 'SpecialDigitSmall', 'SpecialDigitNormal', 'SpecialDigitLarge',
		'LargeFontType_1', 'LargeFontType_2', 'LargeFontType_3', 'LargeFontType_4')]
	[string] $FontType = 'SpecialBigerFont',
	[string] $EditorDir = "C:\Users\KRIVOSHEEC\Desktop\xdatEditor",
	[string] $OutFile,
	[switch] $NoBackup
)

$ErrorActionPreference = 'Stop'

$xdat = Join-Path $ClientSystemDir 'interface.xdat'
if (-not (Test-Path -LiteralPath $xdat)) { throw "interface.xdat not found in $ClientSystemDir" }
if (-not (Test-Path -LiteralPath $EditorDir)) { throw "XDAT Editor not found at $EditorDir" }

$jars = Get-ChildItem -LiteralPath $EditorDir -Filter *.jar | ForEach-Object { $_.FullName }
if (-not $jars) { throw "no jars in $EditorDir - point -EditorDir at the XDAT Editor folder" }
$cp = $jars -join ';'

$java = Join-Path $EditorDir 'jre\bin\java.exe'
if (-not (Test-Path -LiteralPath $java)) {
	$java = (Get-Command java -ErrorAction SilentlyContinue).Source
	if (-not $java) { throw "no java : neither $EditorDir\jre nor a java on PATH" }
}

$script = Join-Path $PSScriptRoot 'screen_message_font.groovy'
if (-not (Test-Path -LiteralPath $script)) { throw "screen_message_font.groovy not found next to this script" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("interface-{0}.xdat" -f ([guid]::NewGuid()))
try {
	& $java -cp $cp groovy.ui.GroovyMain $script $xdat $tmp $FontType
	if ($LASTEXITCODE -ne 0) { throw "the xdat rewrite failed (exit $LASTEXITCODE)" }
	if (-not (Test-Path -LiteralPath $tmp)) { throw "the xdat rewrite produced no file" }

	if ($OutFile) {
		Copy-Item -LiteralPath $tmp -Destination $OutFile -Force
		Write-Host "written: $OutFile"
		return
	}

	if (-not $NoBackup) {
		$bak = "$xdat.prefont.bak"
		if (-not (Test-Path -LiteralPath $bak)) {
			Copy-Item -LiteralPath $xdat -Destination $bak
			Write-Host "backup: $bak"
		}
		else { Write-Host "backup kept: $bak" }
	}

	Copy-Item -LiteralPath $tmp -Destination $xdat -Force
	Write-Host "patched: $xdat ($FontType)"
}
finally {
	if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
}
