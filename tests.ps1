param([Parameter(Mandatory=$true)][string]$GameDirectory, [Parameter(Mandatory=$true)][string]$SdkDirectory)
$ErrorActionPreference = 'Stop'
function Assert($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$source = Join-Path $PSScriptRoot 'src\SageXml\UI\SettingsCommon.xml'
Assert (Test-Path $source) 'Missing source layout src/SageXml/UI/SettingsCommon.xml'
$original = [IO.File]::ReadAllText((Join-Path $SdkDirectory 'SageXml\UI\SettingsCommon.xml'))
$modified = [IO.File]::ReadAllText($source)
$old = '<Font Name="Lucida Sans" Size="14"/>'
$new = '<Font Name="Lucida Sans" Size="7"/>'
Assert ($original.Replace($old,$new) -ceq $modified) 'Source must differ from original in this one font-size line only'
$core = Join-Path $GameDirectory 'Data\Core12.big'
$before = (Get-FileHash $core -Algorithm SHA256).Hash
& (Join-Path $PSScriptRoot 'build.ps1') -GameDirectory $GameDirectory -SdkDirectory $SdkDirectory
Assert ((Get-FileHash $core -Algorithm SHA256).Hash -eq $before) 'Original Core12.big changed'
$payload = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'build\compiled\mod.bin'))
Assert ($payload.Length -eq 52 -and [BitConverter]::ToUInt32($payload,24) -eq 7) 'Wrong compiled subtitle payload'
$members = @(Get-ChildItem (Join-Path $PSScriptRoot 'build\package\data') -File)
Assert ($members.Count -eq 12) 'Expected exactly twelve stream files'
Assert (Test-Path (Join-Path $PSScriptRoot 'build\SubtitlePreload_1.0.big')) 'Missing final BIG'
$skuSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'src\RA3_english_1.12.SkuDef'))
$skuOutput = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'build\RA3_english_1.12.SkuDef'))
Assert ($skuOutput -ceq $skuSource) 'Output SkuDef differs from source'
Assert ($skuOutput -notmatch '(?im)^\s*mod-game\b') 'Unexpected MOD configuration'
Assert (-not (Test-Path (Join-Path $PSScriptRoot 'build\SubtitlePreload_1.0.skudef'))) 'Stale standalone MOD configuration'
Write-Output 'PASS: src layout / one-field XML delta / SDK compile / normal-launch SkuDef / 12 stream files / unchanged Core12.big'
