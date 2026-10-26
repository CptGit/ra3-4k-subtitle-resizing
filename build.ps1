param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [Parameter(Mandatory=$true)][string]$SdkDirectory
)
# Build only. Inputs are read-only; all writes stay in this project's build/.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$root = $PSScriptRoot
$out = Join-Path $root 'build'
$package = Join-Path $out 'package'
$compiled = Join-Path $out 'compiled'
$utf8 = New-Object Text.UTF8Encoding($false)

function BE32([byte[]]$b, [int]$p) {
    return [uint32]([long]$b[$p]*16777216 + [long]$b[$p+1]*65536 + [long]$b[$p+2]*256 + $b[$p+3])
}
function Unpack([byte[]]$b) {
    if ($b.Length -lt 5 -or $b[1] -ne 251 -or $b[0] -notin @(16,144)) { return ,$b }
    $width = 3; if ($b[0] -eq 144) { $width = 4 }
    $expected = 0
    for ($j=0; $j -lt $width; $j++) { $expected = $expected*256 + $b[2+$j] }
    [byte[]]$result = New-Object byte[] $expected
    $i = 2+$width; $n = 0
    while ($true) {
        if ($i -ge $b.Length) { throw 'Truncated RefPack stream' }
        $c = [int]$b[$i]; $i++
        if ($c -ge 252) {
            $literal = $c -band 3
            if ($i+$literal -gt $b.Length -or $n+$literal -gt $expected) { throw 'Invalid final literal' }
            [Array]::Copy($b,$i,$result,$n,$literal); $n += $literal
            break
        }
        if ($c -ge 224) {
            $literal = (($c -band 31)*4)+4
            if ($i+$literal -gt $b.Length -or $n+$literal -gt $expected) { throw 'Invalid literal' }
            [Array]::Copy($b,$i,$result,$n,$literal); $i += $literal; $n += $literal
            continue
        }
        if ($c -ge 192) {
            if ($i+3 -gt $b.Length) { throw 'Truncated back-reference' }
            $a=[int]$b[$i]; $z=[int]$b[$i+1]; $d=[int]$b[$i+2]; $i+=3
            $literal=$c -band 3; $length=(($c -band 12)*64)+$d+5
            $distance=(($c -band 16)*4096)+($a*256)+$z+1
        } elseif ($c -ge 128) {
            if ($i+2 -gt $b.Length) { throw 'Truncated back-reference' }
            $a=[int]$b[$i]; $z=[int]$b[$i+1]; $i+=2
            $literal=$a -shr 6; $length=($c -band 63)+4
            $distance=(($a -band 63)*256)+$z+1
        } else {
            if ($i -ge $b.Length) { throw 'Truncated back-reference' }
            $a=[int]$b[$i]; $i++
            $literal=$c -band 3; $length=(($c -band 28)/4)+3
            $distance=(($c -band 96)*8)+$a+1
        }
        if ($i+$literal -gt $b.Length -or $n+$literal+$length -gt $expected) { throw 'Invalid RefPack bounds' }
        [Array]::Copy($b,$i,$result,$n,[int]$literal); $i+=$literal; $n+=$literal
        if ($distance -gt $n) { throw 'Invalid RefPack distance' }
        $start=$n-$distance; $available=$distance; $left=[int]$length
        while ($left -gt 0) {
            $count=[Math]::Min($left,$available)
            [Array]::Copy($result,[int]$start,$result,[int]$n,[int]$count)
            $n+=$count; $left-=$count; $available+=$count
        }
    }
    if ($n -ne $expected) { throw 'RefPack length mismatch' }
    return ,$result
}
function ReadBig([byte[]]$b) {
    $magic=[Text.Encoding]::ASCII.GetString($b,0,4)
    if ($magic -notin @('BIG4','BIGF')) { throw 'Expected BIG4/BIGF archive' }
    $count=BE32 $b 8; $end=BE32 $b 12; $p=16; $files=@{}
    for ($j=0; $j -lt $count; $j++) {
        $offset=BE32 $b $p; $size=BE32 $b ($p+4); $p+=8; $start=$p
        while ($p -lt $end -and $b[$p] -ne 0) { $p++ }
        if ($p -ge $end -or $offset -lt $end -or [long]$offset+$size -gt $b.Length) { throw 'Invalid BIG directory' }
        $name=[Text.Encoding]::ASCII.GetString($b,$start,$p-$start).Replace('/','\').ToLowerInvariant(); $p++
        if ($files.ContainsKey($name)) { throw 'Duplicate BIG member' }
        # Store offsets, not copies of all unrelated resources.
        $files[$name]=@([int]$offset,[int]$size)
    }
    return $files
}
function Entry([byte[]]$big, $directory, [string]$name) {
    if (-not $directory.ContainsKey($name)) { throw "Missing BIG member: $name" }
    $r=$directory[$name]; [byte[]]$bytes=New-Object byte[] $r[1]
    [Array]::Copy($big,$r[0],$bytes,0,$r[1])
    return ,(Unpack $bytes)
}
function Insert([byte[]]$b, [int]$at, [byte[]]$extra) {
    [byte[]]$result=New-Object byte[] ($b.Length+$extra.Length)
    [Array]::Copy($b,0,$result,0,$at)
    [Array]::Copy($extra,0,$result,$at,$extra.Length)
    [Array]::Copy($b,$at,$result,$at+$extra.Length,$b.Length-$at)
    return ,$result
}

$core=[IO.Path]::GetFullPath((Join-Path $GameDirectory 'Data\Core12.big'))
$compiler=Join-Path $SdkDirectory 'tools\BinaryAssetBuilder.exe'
$packer=Join-Path $SdkDirectory 'tools\MakeBig.exe'
foreach ($path in @($core,$compiler,$packer)) { if (-not [IO.File]::Exists($path)) { throw "Missing input: $path" } }
$before=(Get-FileHash $core -Algorithm SHA256).Hash
$source=Join-Path $root 'src\SageXml\UI\SettingsCommon.xml'
[xml]$xml=[IO.File]::ReadAllText($source)
$ns=New-Object Xml.XmlNamespaceManager($xml.NameTable); $ns.AddNamespace('a','uri:ea.com:eala:asset')
$node=$xml.SelectSingleNode('/a:AssetDeclaration/a:UISubtitleDisplay[@id="UISubtitleDisplay"]',$ns)
if ($null -eq $node -or $node.Font.Size -ne '7') { throw 'Expected the subtitle Font Size=7 source change' }
[IO.Directory]::CreateDirectory($compiled) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $package 'data')) | Out-Null
# Compile only this asset; the full original source file remains in the repo for review.
$minimal='<?xml version="1.0" encoding="utf-8"?><AssetDeclaration xmlns="uri:ea.com:eala:asset">'+$node.OuterXml+'</AssetDeclaration>'
$mod=Join-Path $out 'mod.xml'; [IO.File]::WriteAllText($mod,$minimal,$utf8)
& $compiler $mod "/od:$compiled" "/iod:$compiled" /csc:false /ls:true /osh:false /pc:true /res:true /slowclean:true /ss:false > (Join-Path $out 'compiler.log')
if ($LASTEXITCODE -ne 0) { throw 'SDK compilation failed; see build/compiler.log' }
$bin=[IO.File]::ReadAllBytes((Join-Path $compiled 'mod.bin'))
$rel=[IO.File]::ReadAllBytes((Join-Path $compiled 'mod.relo'))
$mf=[IO.File]::ReadAllBytes((Join-Path $compiled 'mod.manifest'))
if ($bin.Length -ne 52 -or $rel.Length -ne 12 -or [BitConverter]::ToUInt32($bin,24) -ne 7) { throw 'Unexpected SDK subtitle payload' }
[byte[]]$payload=$bin[4..51]; [byte[]]$relocation=$rel[4..11]
$newHash=[BitConverter]::ToUInt32($mf,60)
$big=[IO.File]::ReadAllBytes($core); $directory=ReadBig $big
foreach ($stem in @('static.12','static_l.12','static_m.12')) {
    $prefix='data\'+$stem+'.'; $m=Entry $big $directory ($prefix+'manifest')
    if ([BitConverter]::ToUInt16($m,2) -ne 6) { throw 'Only manifest v6 is supported' }
    $rows=[BitConverter]::ToUInt32($m,12); $found=-1; $positions=@(4,4,4); $totals=@(4,4,4)
    for ($j=0; $j -lt $rows; $j++) {
        $p=48+$j*48
        if ([BitConverter]::ToUInt32($m,$p) -eq 165611890 -and [BitConverter]::ToUInt32($m,$p+4) -eq 703685003 -and [BitConverter]::ToUInt32($m,$p+8) -eq 1129081393) {
            if ($found -ne -1) { throw 'Duplicate subtitle asset' }; $found=$p; $positions=$totals.Clone()
            if ([BitConverter]::ToUInt32($m,$p+32) -ne 0 -or [BitConverter]::ToUInt32($m,$p+36) -ne 0 -or [BitConverter]::ToUInt32($m,$p+40) -ne 0) { throw 'Unknown or already-patched subtitle asset' }
        }
        for ($k=0; $k -lt 3; $k++) { $totals[$k]+=[BitConverter]::ToUInt32($m,$p+32+$k*4) }
    }
    if ($found -eq -1) { throw 'Subtitle asset not found' }
    $extensions=@('bin','relo','imp'); $extras=@($payload,$relocation,[byte[]]@())
    for ($k=0; $k -lt 3; $k++) {
        [byte[]]$original=Entry $big $directory ($prefix+$extensions[$k])
        if ($original.Length -ne $totals[$k]) { throw 'Stream length does not match manifest' }
        $result=Insert $original $positions[$k] $extras[$k]
        [IO.File]::WriteAllBytes((Join-Path $package ('data\'+$stem+'.'+$extensions[$k])),$result)
    }
    [Array]::Copy([BitConverter]::GetBytes($newHash),0,$m,$found+12,4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]48),0,$m,$found+32,4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]8),0,$m,$found+36,4)
    [IO.File]::WriteAllBytes((Join-Path $package ('data\'+$stem+'.manifest')),$m)
}
$archive=Join-Path $out 'SubtitlePreload_1.0.big'
& $packer -f $package "-o:$archive"
if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($archive)) { throw 'SDK BIG packaging failed' }
$skuSource=Join-Path $root 'src\RA3_english_1.12.SkuDef'
$skuText=[IO.File]::ReadAllText($skuSource)
if ($skuText -match '(?im)^\s*mod-game\b' -or $skuText -notmatch '(?im)^add-big Data\\SubtitlePreload_1\.0\.big\s*$') { throw 'Invalid normal-launch SkuDef source' }
[IO.File]::Copy($skuSource,(Join-Path $out 'RA3_english_1.12.SkuDef'),$true)
$legacy=Join-Path $out 'SubtitlePreload_1.0.skudef'
if ([IO.File]::Exists($legacy)) { [IO.File]::Delete($legacy) }
if ((Get-FileHash $core -Algorithm SHA256).Hash -ne $before) { throw 'Core12.big input changed' }
Write-Output "Built: $archive"
Write-Output 'Built: build/RA3_english_1.12.SkuDef'
Write-Output 'Original game files unchanged. Nothing installed or launched.'
