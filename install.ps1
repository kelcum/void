# Installs VOID for Windows: type "void" in Win+R or any terminal, or use the desktop / Start menu shortcut.
#   irm https://raw.githubusercontent.com/kelcum/void/main/install.ps1 | iex
# Lives in %USERPROFILE%\.void (not AppData, which sandboxed/packaged apps can redirect).
& {
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$repoRaw = 'https://raw.githubusercontent.com/kelcum/void/main'
$dest = Join-Path $env:USERPROFILE '.void'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$folder = Get-Item -LiteralPath $dest -Force
$folder.Attributes = ($folder.Attributes -band -bnot [IO.FileAttributes]::System) -bor [IO.FileAttributes]::Hidden

# from a cloned repo / unzipped download, or straight from GitHub when run with irm | iex
foreach ($name in 'void.ps1', 'void.cmd') {
    $local = @("$PSScriptRoot\windows\$name", "$PSScriptRoot\$name") | Where-Object { $PSScriptRoot -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if ($local) { Copy-Item -LiteralPath $local -Destination $dest -Force }
    else { Invoke-WebRequest -UseBasicParsing -Uri "$repoRaw/windows/$name" -OutFile (Join-Path $dest $name) }
}

# icon: purple->cyan rounded square with a black hole in the middle
Add-Type -AssemblyName System.Drawing
function New-IconBitmap([int]$s) {
    $bmp = New-Object Drawing.Bitmap $s, $s, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([Drawing.Color]::Transparent)
    $d = [Math]::Max([int]($s * 0.44), 4); $w = $s - 1
    $path = New-Object Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90);           $path.AddArc($w - $d, 0, $d, $d, 270, 90)
    $path.AddArc($w - $d, $w - $d, $d, $d, 0, 90); $path.AddArc(0, $w - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $p1 = New-Object Drawing.Point 0, 0; $p2 = New-Object Drawing.Point $s, $s
    $brush = New-Object Drawing.Drawing2D.LinearGradientBrush $p1, $p2, ([Drawing.Color]::FromArgb(168, 85, 247)), ([Drawing.Color]::FromArgb(34, 211, 238))
    $g.FillPath($brush, $path)
    $r = [float]($s * 0.28); $c = [float]($s / 2)
    $g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(12, 10, 24))), [float]($c - $r), [float]($c - $r), [float]($r * 2), [float]($r * 2))
    $g.Dispose()
    $bmp
}
# 256px as PNG, smaller sizes as classic 32-bit bitmaps (what every Windows version reads)
function Get-IconEntry([int]$s) {
    $bmp = New-IconBitmap $s
    $ms = New-Object IO.MemoryStream
    if ($s -ge 256) {
        $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    } else {
        $bw = New-Object IO.BinaryWriter $ms
        $bw.Write([uint32]40); $bw.Write([int32]$s); $bw.Write([int32]($s * 2))
        $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]0)
        $bw.Write([uint32]($s * $s * 4)); $bw.Write([int32]0); $bw.Write([int32]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
        for ($y = $s - 1; $y -ge 0; $y--) {
            for ($x = 0; $x -lt $s; $x++) {
                $px = $bmp.GetPixel($x, $y)
                $bw.Write([byte]$px.B); $bw.Write([byte]$px.G); $bw.Write([byte]$px.R); $bw.Write([byte]$px.A)
            }
        }
        $maskRow = [int]([Math]::Ceiling($s / 32) * 4)
        $bw.Write((New-Object byte[] ($maskRow * $s)))
        $bw.Flush()
    }
    $bmp.Dispose()
    , $ms.ToArray()
}
$sizes = 256, 48, 32, 16
$entries = foreach ($s in $sizes) { , (Get-IconEntry $s) }
$ms = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $b = [byte]($sizes[$i] % 256)
    $bw.Write($b); $bw.Write($b); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$entries[$i].Length); $bw.Write([uint32]$offset)
    $offset += $entries[$i].Length
}
foreach ($e in $entries) { $bw.Write([byte[]]$e) }
$bw.Flush()
[IO.File]::WriteAllBytes((Join-Path $dest 'void.ico'), $ms.ToArray())

# launcher in WindowsApps - already on PATH, so "void" works right away (no sign-out needed)
$apps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
if (Test-Path -LiteralPath $apps) {
    Set-Content -LiteralPath (Join-Path $apps 'void.cmd') -Encoding ASCII -Value `
        "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$dest\void.ps1`" %*"
}

# very early builds put VOID on PATH from AppData - remove that stale entry
$key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
$old = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
$kept = @($old -split ';' | Where-Object { $_ -and $_ -notlike '*\AppData\Local\VOID' }) -join ';'
if ($kept -ne $old.TrimEnd(';')) { $key.SetValue('Path', $kept, [Microsoft.Win32.RegistryValueKind]::ExpandString) }
$key.Close()

# shortcuts that open straight as admin
$shell = New-Object -ComObject WScript.Shell
foreach ($dir in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) {
    $lnk = Join-Path $dir 'VOID.lnk'
    $sc = $shell.CreateShortcut($lnk)
    $sc.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$dest\void.ps1`""
    $sc.WorkingDirectory = $dest
    $sc.IconLocation = "$dest\void.ico,0"
    $sc.Description = 'VOID - send your junk to the void'
    $sc.Save()
    $bytes = [IO.File]::ReadAllBytes($lnk); $bytes[0x15] = $bytes[0x15] -bor 0x20; [IO.File]::WriteAllBytes($lnk, $bytes)
}

# refresh the icon cache so the shortcut shows the new icon
Start-Process ie4uinit.exe -ArgumentList '-show' -Wait -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '  VOID installed.' -ForegroundColor Cyan
Write-Host '  Launch it: Win+R -> void, type void in any terminal, or the VOID shortcut.'
Write-Host ''
}
