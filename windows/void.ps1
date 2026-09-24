<#
    VOID - send your junk to the void
    Personal Windows cleanup + app utility.
    Ideas borrowed from Mole (github.com/tw93/Mole); the Toolbox launches other open-source GitHub tools.

    void             open the menu
    void <command>   jump straight to a tool   (void help for the list)
#>
param([string]$Command = '', [switch]$SelfTest, [switch]$Preview, [switch]$Screens)

$VoidVersion  = '1.4'
$VoidHome     = $PSScriptRoot
$BackupDir    = Join-Path $VoidHome 'backups'
$HistoryFile  = Join-Path $VoidHome 'history.log'
$SettingsFile = Join-Path $VoidHome 'settings.json'
$Command      = $Command.ToLower().TrimStart('-', '/')

$Commands = [ordered]@{
    clean      = 'clean junk files'
    uninstall  = 'uninstall apps + their leftovers'
    fix        = 'fix stuck apps (files already gone)'
    installers = 'old installers in Downloads / Desktop'
    purge      = 'dev junk: node_modules, venvs, build caches'
    status     = 'live system dashboard'
    disk       = "what's eating your storage"
    optimize   = 'flush DNS, TRIM SSDs, repair Windows...'
    update     = 'update all apps with winget'
    speed      = 'internet speed test (Cloudflare)'
    tools      = 'GitHub power tools (btop, dua, Czkawka...)'
    scan       = 'suspicious scan'
    virus      = 'virus scan'
    history    = 'what VOID has done'
    remove     = 'uninstall VOID itself'
}

if ($Command -in 'help', 'h', '?') {
    Write-Host ''
    Write-Host '  VOID - send your junk to the void' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('  {0,-18}{1}' -f 'void', 'open the menu')
    foreach ($name in $Commands.Keys) { Write-Host ('  {0,-18}{1}' -f "void $name", $Commands[$name]) }
    Write-Host ''
    exit
}
if ($Command -and -not $Commands.Contains($Command)) {
    Write-Host "  unknown command '$Command' - try: void help" -ForegroundColor Red
    exit 1
}

# ── admin ──────────────────────────────────────────────────────────────
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not $SelfTest -and -not $Preview -and -not $Screens -and -not (Test-Admin)) {
    $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Command) { $argLine += " $Command" }
    try {
        Start-Process powershell.exe -Verb RunAs -ErrorAction Stop -ArgumentList $argLine
    } catch {
        Write-Host 'VOID needs admin rights to clean and uninstall - cancelled.' -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
    exit
}

# ── look ───────────────────────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "VOID $VoidVersion"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

# careful: PowerShell names are case-insensitive - never use $r / $e / $p / $bold-style locals
$E     = [char]27
$R     = "$E[0m"
$Bold  = "$E[1m"
$Track = "$E[38;2;58;58;78m"
function Fg([int[]]$c) { "$E[38;2;$($c[0]);$($c[1]);$($c[2])m" }
function Bg([int[]]$c) { "$E[48;2;$($c[0]);$($c[1]);$($c[2])m" }

$Col = @{
    Text = Fg 235, 235, 245; Dim = Fg 120, 120, 145; White = Fg 255, 255, 255
    Good = Fg 74, 222, 128;  Warn = Fg 250, 204, 21; Bad = Fg 248, 113, 113
}

$Themes = [ordered]@{
    void    = @(@(168, 85, 247), @(34, 211, 238))
    inferno = @(@(255, 60, 60),  @(255, 190, 40))
    matrix  = @(@(0, 255, 120),  @(0, 140, 70))
    ice     = @(@(100, 140, 255), @(190, 245, 255))
    sakura  = @(@(255, 90, 170),  @(255, 195, 225))
    toxic   = @(@(170, 255, 0),   @(0, 225, 190))
}
function Set-Theme([string]$Name) {
    if (-not $Themes.Contains($Name)) { $Name = 'void' }
    $script:ThemeName = $Name
    $script:GradA = [int[]]$Themes[$Name][0]
    $script:GradB = [int[]]$Themes[$Name][1]
    $Col.Acc = Fg $GradB
    $Col.Pur = Fg $GradA
    $script:SelBg  = Bg @([int]($GradA[0] * 0.22), [int]($GradA[1] * 0.22), [int]($GradA[2] * 0.22))
    $script:PillBg = Bg $GradB
    $script:PillFg = Fg 14, 14, 24
}
function Save-Settings { try { @{ theme = $ThemeName } | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8 } catch {} }
$savedTheme = 'void'
try { $savedTheme = (Get-Content -LiteralPath $SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json).theme } catch {}
Set-Theme $savedTheme

$BlockW     = 72
$SparkChars = '▁▂▃▄▅▆▇█'
$NoiseChars = '░▒▓█▚▞▀▄'
$SpinChars  = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
$Tagline    = 's e n d   y o u r   j u n k   t o   t h e   v o i d'
$Rng        = New-Object Random

$Logo = @(
    '██╗   ██╗ ██████╗ ██╗██████╗ '
    '██║   ██║██╔═══██╗██║██╔══██╗'
    '██║   ██║██║   ██║██║██║  ██║'
    '╚██╗ ██╔╝██║   ██║██║██║  ██║'
    ' ╚████╔╝ ╚██████╔╝██║██████╔╝'
    '  ╚═══╝   ╚═════╝ ╚═╝╚═════╝ '
)

function Out-Line([string]$s = '') { [Console]::WriteLine($s) }
function Out-Text([string]$s) { [Console]::Write($s) }
function Get-Width  { try { [Console]::WindowWidth } catch { 100 } }
function Get-Height { try { [Console]::WindowHeight } catch { 30 } }
function Get-Row    { try { [Console]::CursorTop } catch { 0 } }
function Set-Pos([int]$x, [int]$y) { try { [Console]::SetCursorPosition($x, $y) } catch {} }
function Get-Pad([int]$w) { ' ' * [Math]::Max([int](((Get-Width) - $w) / 2), 0) }
function Set-Cursor([bool]$on) { try { [Console]::CursorVisible = $on } catch {} }
function Get-VisLen([string]$s) { ($s -replace "$E\[[0-9;]*m", '').Length }

# theme gradient across the text; Shine adds a white glow centred on that column
function Get-Gradient([string]$Text, [int]$Offset = 0, [int]$Span = 0, [double]$Shine = -99) {
    if (-not $Span) { $Span = $Text.Length }
    $den = [Math]::Max($Span - 1, 1)
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $t = [Math]::Min(($i + $Offset) / $den, 1)
        $cr = $GradA[0] + ($GradB[0] - $GradA[0]) * $t
        $cg = $GradA[1] + ($GradB[1] - $GradA[1]) * $t
        $cb = $GradA[2] + ($GradB[2] - $GradA[2]) * $t
        if ($Shine -gt -99) {
            $glow = [Math]::Max(0, 1 - [Math]::Abs($i + $Offset - $Shine) / 5)
            $cr += (255 - $cr) * $glow; $cg += (255 - $cg) * $glow; $cb += (255 - $cb) * $glow
        }
        [void]$sb.Append("$E[38;2;$([int]$cr);$([int]$cg);$([int]$cb)m").Append($Text[$i])
    }
    $sb.Append($R).ToString()
}

# 0-100 bar: theme gradient when fine, yellow when high, red when critical.
# -HighIsGood flips that for scores (like health) where a full bar is the good case.
function Get-Meter([double]$Pct, [int]$W = 24, [switch]$HighIsGood) {
    $Pct = [Math]::Min([Math]::Max($Pct, 0), 100)
    $fill = [int][Math]::Round($W * $Pct / 100)
    $level = if ($HighIsGood) { 100 - $Pct } else { $Pct }
    $bar = if ($level -ge 90) { $Col.Bad + ('━' * $fill) + $R }
           elseif ($level -ge 75) { $Col.Warn + ('━' * $fill) + $R }
           elseif ($HighIsGood) { $Col.Good + ('━' * $fill) + $R }
           else { Get-Gradient ('━' * $fill) 0 $W }
    $bar + $Track + ('━' * ($W - $fill)) + $R
}

function Get-Spark([double[]]$Values) {
    $sb = New-Object Text.StringBuilder
    foreach ($v in $Values) {
        $i = [int][Math]::Min([Math]::Max([Math]::Floor($v / 100 * 8), 0), 7)
        $c = if ($v -ge 90) { $Col.Bad } elseif ($v -ge 60) { $Col.Warn } else { $Col.Acc }
        [void]$sb.Append($c).Append($SparkChars[$i])
    }
    $sb.Append($R).ToString()
}

# rounded panel with a gradient border; Body lines should fit in W-4 visible chars
function Get-Box([string]$Title, [string[]]$Body, [int]$W = $BlockW) {
    $inner = $W - 2
    $lines = New-Object System.Collections.Generic.List[string]
    if ($Title) {
        $tail = [Math]::Max($inner - 3 - $Title.Length, 0)
        $lines.Add((Get-Gradient '╭─ ' 0 $W) + "$Bold$($Col.Text)$Title$R" + (Get-Gradient (' ' + ('─' * $tail) + '╮') ($Title.Length + 3) $W))
    } else {
        $lines.Add((Get-Gradient ('╭' + ('─' * $inner) + '╮')))
    }
    $left = Fg $GradA; $right = Fg $GradB
    foreach ($line in $Body) {
        $pad = [Math]::Max($W - 4 - (Get-VisLen $line), 0)
        $lines.Add("$left│$R $line$(' ' * $pad) $right│$R")
    }
    $lines.Add((Get-Gradient ('╰' + ('─' * $inner) + '╯')))
    $lines
}

# key hints drawn as little buttons: Get-Keys 'q','quit','enter','open'
function Get-Keys([string[]]$Pairs) {
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Pairs.Count; $i += 2) {
        [void]$sb.Append("$PillBg$PillFg$Bold $($Pairs[$i]) $R $($Col.Dim)$($Pairs[$i + 1])$R   ")
    }
    $sb.ToString()
}

# paints a whole row in the selection colour (re-applied after every colour reset inside the text)
function Format-Selected([string]$Text, [int]$W) {
    $pad = [Math]::Max($W - (Get-VisLen $Text), 0)
    "$SelBg" + $Text.Replace($R, "$R$SelBg") + (' ' * $pad) + $R
}

function Say([string]$tag, [string]$color, [string]$msg) { Out-Line "$script:P  $color$tag$R $($Col.Text)$msg$R" }
function Ok([string]$m)   { Say '◆' $Col.Good $m }
function Warn([string]$m) { Say '▲' $Col.Warn $m }
function Fail([string]$m) { Say '■' $Col.Bad $m }
function Info([string]$m) { Say '▸' $Col.Acc $m }
function Note([string]$m) { Out-Line "$script:P  $($Col.Dim)$m$R" }
function Limit([string]$s, [int]$n) { if ($s.Length -gt $n) { $s.Substring(0, $n - 1) + '…' } else { $s.PadRight($n) } }

function Format-Size([double]$b) {
    if ($b -ge 1TB) { '{0:N1} TB' -f ($b / 1TB) }
    elseif ($b -ge 1GB) { '{0:N1} GB' -f ($b / 1GB) }
    elseif ($b -ge 1MB) { '{0:N0} MB' -f ($b / 1MB) }
    elseif ($b -gt 0) { '{0:N0} KB' -f ($b / 1KB) }
    else { '0 MB' }
}
function Format-Rate([double]$b) {
    if ($b -ge 1MB) { '{0:N1} MB/s' -f ($b / 1MB) } elseif ($b -ge 1KB) { '{0:N0} KB/s' -f ($b / 1KB) } else { '{0:N0} B/s' -f $b }
}
function Format-Age([datetime]$When) {
    $d = ((Get-Date) - $When).TotalDays
    if ($d -lt 1) { 'today' }
    elseif ($d -lt 2) { 'yesterday' }
    elseif ($d -lt 31) { '{0} days ago' -f [int]$d }
    elseif ($d -lt 365) { $m = [int]($d / 30); if ($m -eq 1) { '1 month ago' } else { "$m months ago" } }
    else { '{0:N1} years ago' -f ($d / 365) }
}
function Format-Uptime([TimeSpan]$t) {
    if ($t.TotalDays -ge 1) { '{0}d {1}h' -f [int][Math]::Floor($t.TotalDays), $t.Hours } else { '{0}h {1}m' -f $t.Hours, $t.Minutes }
}

function Get-TitleLines([string]$t) {
    $left  = (Get-Gradient '◆ VOID') + "$($Col.Dim)  ›  $R$Bold$($Col.Text)$t$R"
    $right = "$($Col.Dim)$(Get-Date -Format 'HH:mm')  ·  $env:USERNAME$R"
    $gap = [Math]::Max($BlockW - 4 - (Get-VisLen $left) - (Get-VisLen $right), 1)
    ''
    foreach ($line in (Get-Box '' @($left + (' ' * $gap) + $right))) { "$script:P$line" }
    ''
}

function Show-Title([string]$t) {
    Clear-Host; Set-Cursor $false
    $script:P = Get-Pad $BlockW
    foreach ($line in (Get-TitleLines $t)) { Out-Line $line }
}

function Wait-Back {
    Out-Line; Out-Line "$script:P  $(Get-Keys 'any key', 'back')"
    [void][Console]::ReadKey($true)
}

function Confirm-Action([string]$q) {
    Out-Text "$script:P  $($Col.Warn)?$R $($Col.Text)$q$R   $(Get-Keys 'y', 'yes', 'n', 'no')"
    while ($true) {
        $k = [string][Console]::ReadKey($true).KeyChar
        if ($k -eq 'y') { Out-Line; return $true }
        if ($k -eq 'n' -or $k -eq [string][char]27) { Out-Line; return $false }
    }
}

# Line input that also understands Esc (returns $null).
function Read-Line([string]$label) {
    Out-Text "$script:P  $($Col.Acc)$label ▸$R "
    Set-Cursor $true
    $sb = New-Object Text.StringBuilder
    while ($true) {
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'Enter'     { Out-Line; Set-Cursor $false; return $sb.ToString().Trim() }
            'Escape'    { Out-Line; Set-Cursor $false; return $null }
            'Backspace' { if ($sb.Length) { [void]$sb.Remove($sb.Length - 1, 1); Out-Text "`b `b" } }
            default     { if (-not [char]::IsControl($k.KeyChar)) { [void]$sb.Append($k.KeyChar); Out-Text ([string]$k.KeyChar) } }
        }
    }
}

# one frame of the picker: visible rows, scroll hints, footer and key bar
function Get-PickerLines($Items, [int]$Pos, [int]$Off, [int]$View, [scriptblock]$Footer, [string]$Keys, [switch]$Single) {
    $n = $Items.Count
    $end = [Math]::Min($Off + $View, $n) - 1
    $above = if ($Off -gt 0) { "▲ $Off more" } else { '' }
    "$script:P$($Col.Dim)      $above$R"
    for ($i = $Off; $i -le $end; $i++) {
        $it = $Items[$i]
        $mark = if ($Single) { '' } elseif ($it.On) { "$($Col.Good)●$R  " } else { "$($Col.Dim)○$R  " }
        if ($i -eq $Pos) { "$script:P $($Col.Acc)▌$R" + (Format-Selected " $mark$($it.Text)" ($BlockW - 2)) }
        else { "$script:P   $mark$($it.Text)" }
    }
    $below = $n - 1 - $end
    $belowTxt = if ($below -gt 0) { "▼ $below more" } else { '' }
    "$script:P$($Col.Dim)      $belowTxt$R"
    $foot = if ($Footer) { & $Footer $Items $Pos } else { '' }
    "$script:P  $($Col.Text)$foot$R"
    "$script:P  $Keys"
}

# Arrow-key picker (Mole-style). Items need .Text (max ~62 visible chars) and .On.
# Footer gets (items, cursor index). Multi: returns $true/$false. -Single: returns the index, or -1 on Esc.
function Select-Items([string]$Title, $Items, [string]$Hint = '', [scriptblock]$Footer = $null, [switch]$Single) {
    $Items = @($Items)
    $n = $Items.Count
    if (-not $n) { if ($Single) { return -1 } else { return $false } }
    $pos = 0; $off = 0
    Show-Title $Title
    if ($Hint) { Note $Hint; Out-Line }
    $row = Get-Row
    $keys = if ($Single) { Get-Keys '↑↓', 'move', 'enter', 'open', 'esc', 'back' }
            else { Get-Keys '↑↓', 'move', 'space', 'select', 'a', 'all', 'enter', 'go', 'esc', 'back' }
    while ($true) {
        $view = [Math]::Max((Get-Height) - $row - 6, 3)
        if ($pos -lt $off) { $off = $pos }
        if ($pos -ge $off + $view) { $off = $pos - $view + 1 }
        Set-Pos 0 $row
        $lines = @(Get-PickerLines $Items $pos $off $view $Footer $keys -Single:$Single)
        for ($i = 0; $i -lt $lines.Count - 1; $i++) { Out-Line "$($lines[$i])$E[K" }
        Out-Text "$($lines[-1])$E[K$E[J"
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'UpArrow'   { $pos = ($pos - 1 + $n) % $n }
            'DownArrow' { $pos = ($pos + 1) % $n }
            'PageUp'    { $pos = [Math]::Max($pos - $view, 0) }
            'PageDown'  { $pos = [Math]::Min($pos + $view, $n - 1) }
            'Home'      { $pos = 0 }
            'End'       { $pos = $n - 1 }
            'Spacebar'  { if (-not $Single) { $Items[$pos].On = -not $Items[$pos].On } }
            'Enter'     { Out-Line; if ($Single) { return $pos } else { return $true } }
            'Escape'    { Out-Line; if ($Single) { return -1 } else { return $false } }
            default {
                switch ([string]$k.KeyChar) {
                    'k' { $pos = ($pos - 1 + $n) % $n }
                    'j' { $pos = ($pos + 1) % $n }
                    'a' { if (-not $Single) { $all = @($Items | Where-Object On).Count -ne $n; foreach ($x in $Items) { $x.On = $all } } }
                }
            }
        }
    }
}

function Write-VoidLog([string]$What) {
    try { Add-Content -LiteralPath $HistoryFile -Value ('{0:yyyy-MM-dd HH:mm}  {1}' -f (Get-Date), $What) -Encoding UTF8 } catch {}
}

Add-Type -AssemblyName Microsoft.VisualBasic
function Move-ToRecycleBin([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Container) {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
    } else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
    }
}

# ── system data ────────────────────────────────────────────────────────
$UninstallKeys = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
# Stuff Windows, games and drivers need - never offered for removal.
$Protected = 'Visual C\+\+|Desktop Runtime|\.NET|Graphics Driver|HD Audio Driver|PhysX|Realtek|Intel\(R\)|Chipset|WebView2|^Microsoft Edge$|GameInput|Update Health'

$Browsers = "$env:LOCALAPPDATA\Google\Chrome\User Data", "$env:LOCALAPPDATA\Microsoft\Edge\User Data", "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
$JunkSpots = @(
    # 'claude' keeps Claude Code's live session files
    @{ Name = 'Your temp files';             Paths = @($env:TEMP); Skip = @('claude') }
    @{ Name = 'Windows temp files';          Paths = @("$env:SystemRoot\Temp") }
    @{ Name = 'Crash dumps';                 Paths = @("$env:LOCALAPPDATA\CrashDumps") }
    @{ Name = 'Error reports';               Paths = @("$env:ProgramData\Microsoft\Windows\WER\ReportArchive", "$env:ProgramData\Microsoft\Windows\WER\ReportQueue") }
    @{ Name = 'Windows Update leftovers';    Paths = @("$env:SystemRoot\SoftwareDistribution\Download"); Svc = @('wuauserv', 'bits') }
    @{ Name = 'Delivery Optimization cache'; Paths = @("$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"); Svc = @('dosvc') }
    @{ Name = 'Browser caches';              Hint = 'close browsers first'; Paths = @($Browsers | ForEach-Object { "$_\*\Cache", "$_\*\Code Cache", "$_\*\GPUCache" }) }
    @{ Name = 'Discord cache';               Paths = @('discord', 'discordcanary' | ForEach-Object { "$env:APPDATA\$_\Cache", "$env:APPDATA\$_\Code Cache", "$env:APPDATA\$_\GPUCache" }) }
    @{ Name = 'npm / pip / yarn caches';     Hint = 'redownloaded if needed'; Paths = @("$env:LOCALAPPDATA\npm-cache", "$env:LOCALAPPDATA\pip\cache", "$env:LOCALAPPDATA\Yarn\Cache") }
    @{ Name = 'Shader caches';               Hint = 'games may stutter once'; Off = $true; Paths = @("$env:LOCALAPPDATA\D3DSCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\NVIDIA\GLCache") }
    @{ Name = 'Recycle Bin';                 Hint = 'empties it for good';    Off = $true; Recycle = $true; Paths = @() }
)

function Get-SysInfo {
    $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
           Where-Object { $_.Name -notmatch 'Basic|Virtual|Remote|Parsec|Meta|Mirage|Oray' } | Select-Object -First 1
    [pscustomobject]@{
        OS  = if ($os) { $os.Caption -replace '^Microsoft ', '' } else { 'Windows' }
        CPU = if ($cpu) { ($cpu.Name -replace '\((R|TM)\)|CPU|Processor|\d+-Core|with Radeon.*|@.*', '' -replace '\s+', ' ').Trim() } else { '' }
        GPU = if ($gpu) { ($gpu.Name -replace 'NVIDIA GeForce |\((R|TM)\)', '').Trim() } else { '' }
        RAM = if ($os) { [Math]::Round($os.TotalVisibleMemorySize / 1MB) } else { 0 }
    }
}

function Get-DriveInfo {
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{ Letter = $_.DeviceID; Size = [double]$_.Size; Free = [double]$_.FreeSpace }
    }
}

function Update-AppIndex {
    $raw = Get-ItemProperty $UninstallKeys -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -and $_.SystemComponent -ne 1 -and -not $_.ParentKeyName -and $_.ReleaseType -notmatch 'Update|Hotfix'
    }
    $script:AllEntries = @($raw | ForEach-Object {
        [pscustomobject]@{
            Name      = ([string]$_.DisplayName).Trim()
            Publisher = ([string]$_.Publisher).Trim()
            SizeMB    = [Math]::Round(([double]$_.EstimatedSize) / 1024)
            Location  = ([string]$_.InstallLocation).Trim().Trim('"').Trim()
            Uninstall = [string]$_.UninstallString
            Quiet     = [string]$_.QuietUninstallString
            Key       = $_.PSPath
        }
    })
    # one row per name, preferring the entry with a silent uninstaller
    $script:Apps = @($script:AllEntries | Sort-Object Name, @{ e = { -not $_.Quiet } } |
        Group-Object Name | ForEach-Object { $_.Group[0] } | Sort-Object Name)
}

# a path we can't read counts as existing - never call something "gone" just because it's locked
function Test-Exists([string]$Path) { try { Test-Path -LiteralPath $Path -ErrorAction Stop } catch { $true } }

function Get-FolderBytes([string]$Path, $Skip) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -ErrorAction SilentlyContinue)) { return [double]0 }
    $sum = [double]0
    foreach ($it in (Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Where-Object { $Skip -notcontains $_.Name })) {
        if ($it.PSIsContainer) {
            $s = (Get-ChildItem -LiteralPath $it.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            if ($s) { $sum += $s }
        } else { $sum += $it.Length }
    }
    $sum
}

function Expand-JunkPaths([string[]]$Paths) {
    foreach ($path in $Paths) {
        if ($path -match '[\*\?]') { Resolve-Path -Path $path -ErrorAction SilentlyContinue | ForEach-Object { $_.ProviderPath } }
        elseif (Test-Path -LiteralPath $path -ErrorAction SilentlyContinue) { $path }
    }
}

function Get-RecycleBinBytes {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $sum = [double]0
    foreach ($d in (Get-DriveInfo)) { $sum += Get-FolderBytes (Join-Path "$($d.Letter)\" ('$Recycle.Bin\' + $sid)) }
    $sum
}

function Measure-JunkSpot($Spot) {
    $paths = @(Expand-JunkPaths $Spot.Paths)
    $bytes = [double]0
    if ($Spot.Recycle) { $bytes = Get-RecycleBinBytes }
    else { foreach ($path in $paths) { $bytes += Get-FolderBytes $path $Spot.Skip } }
    [pscustomobject]@{
        Name = $Spot.Name; Paths = $paths; Skip = $Spot.Skip; Svc = $Spot.Svc; Recycle = [bool]$Spot.Recycle
        Bytes = $bytes; On = -not $Spot.Off
        Text = "$($Col.Text)$($Spot.Name.PadRight(28))$R$($Col.Dim)$((Format-Size $bytes).PadLeft(9))  $($Spot.Hint)$R"
    }
}
function Measure-Junk { @($JunkSpots | ForEach-Object { Measure-JunkSpot $_ }) }

# '"C:\x y\un.exe" /S' -> 'C:\x y\un.exe', '/S'
function Split-Command([string]$Cmd) {
    $Cmd = $Cmd.Trim()
    if ($Cmd -match '^"([^"]+)"\s*(.*)$') { $exe = $Matches[1]; $arg = $Matches[2] }
    elseif ($Cmd -match '^(.+?\.exe)(\s+.*)?$') { $exe = $Matches[1]; $arg = "$($Matches[2])".Trim() }
    else { $exe = $Cmd; $arg = '' }
    if ($exe -notmatch '^[A-Za-z]:\\') {
        $found = Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $exe = $found.Source }
    }
    return $exe, $arg
}

# ── intro / outro ──────────────────────────────────────────────────────
function Write-Logo([int]$Row, [double]$Shine = -99) {
    $lp = Get-Pad $Logo[0].Length
    for ($i = 0; $i -lt $Logo.Count; $i++) {
        Set-Pos 0 ($Row + $i)
        $s = if ($Shine -gt -99) { $Shine - $i * 1.5 } else { -99 }
        Out-Text ($lp + (Get-Gradient $Logo[$i] 0 0 $s) + "$E[K")
    }
}

# a beam of light opens where the logo will appear
function Show-Portal([int]$Row) {
    $w = 60; $pad = Get-Pad $w
    for ($half = 1; $half -le $w / 2; $half += 3) {
        $line = (' ' * ($w / 2 - $half)) + ('━' * ($half * 2))
        Set-Pos 0 $Row
        Out-Text ($pad + (Get-Gradient $line 0 $w ($w / 2)) + "$E[K")
        Start-Sleep -Milliseconds 14
    }
}

# the logo decodes out of static
function Show-LogoDecrypt([int]$Row) {
    $w = $Logo[0].Length; $pad = Get-Pad $w; $frames = 18
    for ($f = 0; $f -le $frames; $f++) {
        for ($i = 0; $i -lt $Logo.Count; $i++) {
            $sb = New-Object Text.StringBuilder
            foreach ($ch in $Logo[$i].ToCharArray()) {
                if ($ch -eq ' ') { [void]$sb.Append(' ') }
                elseif ($Rng.NextDouble() -lt ($f / $frames)) { [void]$sb.Append($ch) }
                else { [void]$sb.Append($NoiseChars[$Rng.Next($NoiseChars.Length)]) }
            }
            Set-Pos 0 ($Row + $i)
            Out-Text ($pad + (Get-Gradient $sb.ToString() 0 0 (($f / $frames) * ($w + 10) - 5 - $i)) + "$E[K")
        }
        Start-Sleep -Milliseconds 30
    }
}

function Show-LogoDissolve([int]$Row) {
    $w = $Logo[0].Length; $pad = Get-Pad $w; $frames = 14
    for ($f = 0; $f -le $frames; $f++) {
        $p = $f / $frames
        for ($i = 0; $i -lt $Logo.Count; $i++) {
            $sb = New-Object Text.StringBuilder
            foreach ($ch in $Logo[$i].ToCharArray()) {
                $roll = $Rng.NextDouble()
                if ($ch -eq ' ' -or $roll -lt $p * 0.8) { [void]$sb.Append(' ') }
                elseif ($roll -lt $p * 1.3) { [void]$sb.Append($NoiseChars[$Rng.Next($NoiseChars.Length)]) }
                else { [void]$sb.Append($ch) }
            }
            Set-Pos 0 ($Row + $i)
            Out-Text ($pad + (Get-Gradient $sb.ToString()) + "$E[K")
        }
        Start-Sleep -Milliseconds 35
    }
}

function Show-Type([string]$text, [string]$color, [int]$ms = 20) {
    Out-Text ((Get-Pad $text.Length) + $color)
    foreach ($ch in $text.ToCharArray()) { Out-Text ([string]$ch); if ($ch -ne ' ') { Start-Sleep -Milliseconds $ms } }
    Out-Line $R
}

function Show-Bar([double]$Pct, [string]$Label, [int]$Frame) {
    $w = 44
    $fill = [int][Math]::Round($w * [Math]::Min([Math]::Max($Pct, 0), 1))
    $bar = (Get-Gradient ('━' * $fill) 0 $w (($Frame * 2) % ($w + 24) - 6)) + $Track + ('━' * ($w - $fill)) + $R
    $pc = '{0,3}%' -f [int]($Pct * 100)
    $spin = $SpinChars[$Frame % $SpinChars.Length]
    $lab = "$spin $Label"
    Out-Text ("`r" + (Get-Pad ($w + 5)) + "$bar $($Col.Text)$pc$R$E[K`n`r" +
              (Get-Pad $lab.Length) + "$($Col.Acc)$spin$R $($Col.Dim)$Label$R$E[K$E[1A")
}

function Show-Intro {
    Clear-Host; Set-Cursor $false
    $top = 3
    Show-Portal ($top + 3)
    Show-LogoDecrypt $top
    Write-Logo $top
    Set-Pos 0 ($top + $Logo.Count + 1)
    Show-Type $Tagline $Col.Dim 7
    Out-Line; Out-Line
    $steps = New-Object System.Collections.Generic.List[object]
    $steps.Add(@{ L = 'booting up';              S = { Start-Sleep -Milliseconds 100 } })
    $steps.Add(@{ L = 'reading your hardware';   S = { $script:Sys = Get-SysInfo } })
    $steps.Add(@{ L = 'indexing installed apps'; S = { Update-AppIndex } })
    $steps.Add(@{ L = 'measuring drives';        S = { $script:Drives = @(Get-DriveInfo) } })
    foreach ($spot in $JunkSpots) { $steps.Add(@{ L = "sniffing: $($spot.Name.ToLower())"; Spot = $spot }) }
    $script:Junk = @()
    $done = 0.0; $frame = 0
    for ($i = 0; $i -lt $steps.Count; $i++) {
        $st = $steps[$i]
        Show-Bar $done $st.L ($frame++)
        if ($st.Spot) { $script:Junk += Measure-JunkSpot $st.Spot } else { & $st.S }
        $target = ($i + 1) / $steps.Count
        while ($done -lt $target) {
            $done = [Math]::Min($done + 0.02, $target)
            Show-Bar $done $st.L ($frame++)
            Start-Sleep -Milliseconds 8
        }
    }
    for ($x = 0; $x -lt 18; $x++) { Show-Bar 1 'ready' ($frame++); Start-Sleep -Milliseconds 18 }
    Out-Text "`n`n"
}

function Show-Outro {
    Clear-Host; Set-Cursor $false
    Write-Logo 3
    Start-Sleep -Milliseconds 150
    Show-LogoDissolve 3
    Set-Pos 0 6
    Show-Type 'see you in the void.' $Col.Acc 28
    Start-Sleep -Milliseconds 450
}

# ── main screen ────────────────────────────────────────────────────────
$Menu = @(
    @{ Key = '1'; Name = 'Clean junk';        Cmd = 'clean';      Run = { Invoke-Clean };          Desc = 'temp files, browser + Discord caches, crash dumps, update leftovers' }
    @{ Key = '2'; Name = 'Uninstall apps';    Cmd = 'uninstall';  Run = { Invoke-UninstallMenu };  Desc = 'search, pick, remove - then sweep the folders they leave behind' }
    @{ Key = '3'; Name = 'Fix stuck apps';    Cmd = 'fix';        Run = { Invoke-FixStuck };       Desc = "clear apps that won't uninstall because their files are gone" }
    @{ Key = '4'; Name = 'Old installers';    Cmd = 'installers'; Run = { Invoke-Installers };     Desc = 'setup files rotting in your Downloads and Desktop' }
    @{ Key = '5'; Name = 'Dev junk';          Cmd = 'purge';      Run = { Invoke-Purge };          Desc = 'node_modules, venvs, __pycache__ and build caches in your projects' }
    @{ Key = '6'; Name = 'Live status';       Cmd = 'status';     Run = { Show-Status };           Desc = 'real-time CPU, GPU, RAM, disk, network + a health score' }
    @{ Key = '7'; Name = 'Disk space';        Cmd = 'disk';       Run = { Show-DiskSpace };        Desc = "what's eating your storage - press D inside to explore with dua" }
    @{ Key = '8'; Name = 'Optimize';          Cmd = 'optimize';   Run = { Invoke-Optimize };       Desc = 'flush DNS, TRIM SSDs, refresh icons, repair Windows' }
    @{ Key = '9'; Name = 'Update everything'; Cmd = 'update';     Run = { Invoke-UpdateAll };      Desc = 'update every app at once with winget' }
    @{ Key = '0'; Name = 'Speed test';        Cmd = 'speed';      Run = { Invoke-SpeedTest };      Desc = "how fast is your internet? - Cloudflare speed test with live graphs" }
    @{ Key = 't'; Name = 'Toolbox';           Cmd = 'tools';      Run = { Invoke-Toolbox };        Desc = 'GitHub power tools: btop, dua, Czkawka, fastfetch, WinUtil...' }
    @{ Key = 's'; Name = 'Suspicious scan';   Cmd = 'scan';       Run = { Invoke-SuspiciousScan }; Desc = 'random-named apps, sketchy startup entries and scheduled tasks' }
    @{ Key = 'v'; Name = 'Virus scan';        Cmd = 'virus';      Run = { Invoke-VirusScan };      Desc = 'Defender quick scan, or opens Malwarebytes' }
    @{ Key = 'h'; Name = 'History';           Cmd = 'history';    Run = { Show-History };          Desc = 'everything VOID has cleaned, removed and fixed' }
    @{ Key = '?'; Name = 'Commands';          Cmd = '';           Run = { Show-Commands };         Desc = 'shortcuts like "void status" you can type in Win+R' }
    @{ Key = '';  Name = 'Remove VOID';       Cmd = 'remove';     Run = { Remove-Void };           Desc = '' }
)
$MenuLeft  = 'CLEAN', '1', '2', '3', '4', '5', '', 'SAFETY', 's', 'v', ''
$MenuRight = 'SYSTEM', '6', '7', '8', '9', '0', '', 'EXTRA', 't', 'h', '?'
$NavCells = @(for ($i = 0; $i -lt $MenuLeft.Count; $i++) {
    foreach ($side in 0, 1) {
        $id = if ($side -eq 0) { $MenuLeft[$i] } else { $MenuRight[$i] }
        if ($id -and $id -cnotmatch '^[A-Z]{2,}$') { [pscustomobject]@{ Side = $side; Row = $i; Key = $id } }
    }
})
$SelIdx = 0

function Move-MenuSel([string]$Dir) {
    $cur   = $NavCells[$script:SelIdx]
    $same  = @($NavCells | Where-Object Side -eq $cur.Side)
    $other = @($NavCells | Where-Object Side -ne $cur.Side)
    $next = switch ($Dir) {
        'up'    { $c = @($same | Where-Object Row -lt $cur.Row); if ($c) { $c[-1] } else { $same[-1] } }
        'down'  { $c = @($same | Where-Object Row -gt $cur.Row); if ($c) { $c[0] } else { $same[0] } }
        default { $other | Sort-Object { [Math]::Abs($_.Row - $cur.Row) } | Select-Object -First 1 }
    }
    $script:SelIdx = [array]::IndexOf($NavCells, $next)
}

function Get-MenuCell([string]$Id, [bool]$Selected) {
    $w = 35
    if ($Id -eq '') { return ' ' * $w }
    if ($Id -cmatch '^[A-Z]{2,}$') { return "  $Bold$($Col.Pur)$Id$R $Track$('─' * ($w - 5 - $Id.Length))$R  " }
    $label = ($Menu | Where-Object { $_.Key -eq $Id } | Select-Object -First 1).Name
    if ($Selected) { return "$($Col.Acc)▌$R" + (Format-Selected "  $Bold$($Col.Acc)$($Id.ToUpper())$R  $Bold$($Col.White)$label$R" ($w - 1)) }
    "   $($Col.Acc)$($Id.ToUpper())$R  $($Col.Text)$($label.PadRight($w - 6))$R"
}

function Get-MainLines {
    $lines = New-Object System.Collections.Generic.List[string]
    $lp = Get-Pad $Logo[0].Length
    $lines.Add('')
    foreach ($l in $Logo) { $lines.Add($lp + (Get-Gradient $l)) }
    $lines.Add((Get-Pad $Tagline.Length) + $Col.Dim + $Tagline + $R)
    $lines.Add('')
    $sysBody = @(
        "$Bold$($Col.Text)$(Limit $Sys.OS 31)$R"
        "$($Col.Text)$(Limit $Sys.CPU 31)$R"
        "$($Col.Dim)$(Limit "$($Sys.GPU) · $($Sys.RAM) GB RAM" 31)$R"
    )
    $stoBody = @(foreach ($d in @($Drives | Select-Object -First 2)) {
        $used = if ($d.Size) { 100 * (1 - $d.Free / $d.Size) } else { 0 }
        "$($Col.Text)$($d.Letter)$R " + (Get-Meter $used 12) + " $($Col.Dim)$(Format-Size $d.Free) free$R"
    })
    $junkTotal = ($Junk | Where-Object On | Measure-Object Bytes -Sum).Sum
    $stoBody += if ($junkTotal -gt 200MB) { "$($Col.Warn)$(Format-Size $junkTotal) of junk$R $($Col.Dim)· press 1$R" } else { "$($Col.Good)◆$R $($Col.Dim)no junk worth cleaning$R" }
    while ($stoBody.Count -lt $sysBody.Count) { $stoBody += '' }
    while ($sysBody.Count -lt $stoBody.Count) { $sysBody += '' }
    $boxL = @(Get-Box 'SYSTEM' $sysBody 35)
    $boxR = @(Get-Box 'STORAGE' $stoBody 35)
    for ($i = 0; $i -lt $boxL.Count; $i++) { $lines.Add("$script:P$($boxL[$i])  $($boxR[$i])") }
    $lines.Add('')
    $sel = $NavCells[$SelIdx]
    for ($i = 0; $i -lt $MenuLeft.Count; $i++) {
        $cellL = Get-MenuCell $MenuLeft[$i]  ($sel.Side -eq 0 -and $sel.Row -eq $i)
        $cellR = Get-MenuCell $MenuRight[$i] ($sel.Side -eq 1 -and $sel.Row -eq $i)
        $lines.Add("$script:P$cellL  $cellR")
    }
    $lines.Add("$script:P$Track$('─' * $BlockW)$R")
    $desc = ($Menu | Where-Object { $_.Key -eq $sel.Key } | Select-Object -First 1).Desc
    $lines.Add("$script:P  $($Col.Acc)▸$R $($Col.Text)$desc$R")
    $lines.Add("$script:P  " + (Get-Keys '↑↓←→', 'move', 'enter', 'open', 'c', "theme: $ThemeName", 'q', 'quit'))
    $lines
}

function Show-Main([switch]$Full) {
    if ($Full) { Clear-Host }
    Set-Cursor $false
    $script:P = Get-Pad $BlockW
    $lines = @(Get-MainLines)
    Set-Pos 0 0
    for ($i = 0; $i -lt $lines.Count - 1; $i++) { Out-Line "$($lines[$i])$E[K" }
    Out-Text "$($lines[-1])$E[K$E[J"
}

# waits for a key while a shine sweeps across the logo
function Read-MainKey {
    $shine = -10.0
    while ($true) {
        try { if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) } } catch { return [Console]::ReadKey($true) }
        if ($shine -le $Logo[0].Length + 12) { Write-Logo 1 $shine }
        $shine += 0.9
        if ($shine -gt 95) { $shine = -10.0 }
        Start-Sleep -Milliseconds 35
    }
}

function Show-Commands {
    Show-Title 'Commands'
    Note 'type these in Win+R or any terminal to jump straight to a tool'
    Out-Line
    Out-Line ("$script:P  $($Col.Acc){0,-18}$R$($Col.Text){1}$R" -f 'void', 'open the menu')
    foreach ($name in $Commands.Keys) { Out-Line ("$script:P  $($Col.Acc){0,-18}$R$($Col.Text){1}$R" -f "void $name", $Commands[$name]) }
    Wait-Back
}

# ── 1. clean junk ──────────────────────────────────────────────────────
function Invoke-Clean {
    Show-Title 'Clean junk'
    Info 'measuring...'
    $items = @(Measure-Junk)
    $picked = Select-Items 'Clean junk' $items -Hint 'pick what to clean - sizes are what VOID found just now' `
        -Footer { param($list) 'selected: ' + (Format-Size (($list | Where-Object On | Measure-Object Bytes -Sum).Sum)) }
    $sel = @($items | Where-Object On)
    if (-not $picked -or -not $sel) { return }
    Show-Title 'Clean junk'
    $before = (Get-DriveInfo | Measure-Object Free -Sum).Sum
    foreach ($it in $sel) {
        Out-Text "$script:P  $($Col.Acc)▸$R $($Col.Text)cleaning $($it.Name)...$R"
        if ($it.Recycle) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        } else {
            foreach ($s in $it.Svc) { Stop-Service $s -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
            foreach ($path in $it.Paths) {
                Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue |
                    Where-Object { $it.Skip -notcontains $_.Name } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue   # files in use are skipped
            }
            foreach ($s in $it.Svc) { Start-Service $s -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
        }
        Out-Text "`r$E[K"; Ok "$($it.Name) cleaned"
    }
    $freed = [Math]::Max((Get-DriveInfo | Measure-Object Free -Sum).Sum - $before, 0)
    Out-Line
    Ok "freed $(Format-Size $freed)  (files that were in use were skipped)"
    Write-VoidLog "clean: freed $(Format-Size $freed) ($(($sel | ForEach-Object Name) -join ', '))"
    $script:Junk = Measure-Junk
    $script:Drives = @(Get-DriveInfo)
    Wait-Back
}

# ── 2. uninstall (+ leftovers) ─────────────────────────────────────────
function Wait-ForRemoval([string]$Key, [int]$Seconds = 90) {
    $i = 0
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ((Test-Path -LiteralPath $Key) -and $sw.Elapsed.TotalSeconds -lt $Seconds) {
        Out-Text "`r$script:P  $($Col.Acc)$($SpinChars[$i++ % $SpinChars.Length])$R $($Col.Dim)waiting for the uninstaller to finish... (any key to skip)$R$E[K"
        try { if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); break } } catch {}
        Start-Sleep -Milliseconds 120
    }
    Out-Text "`r$E[K"
}

# returns $true when the app is gone
function Invoke-AppUninstall($App) {
    $cmd = if ($App.Quiet) { $App.Quiet } else { $App.Uninstall }
    Info "removing $($App.Name)"
    $code = ''
    try {
        if (-not $cmd) { throw 'it has no uninstaller' }
        if ($cmd -match 'msiexec' -and $cmd -match '\{[0-9A-Fa-f-]{36}\}') {
            $proc = Start-Process msiexec.exe -ArgumentList "/x $($Matches[0]) /qn /norestart" -Wait -PassThru
            $code = $proc.ExitCode
        } else {
            $exe, $arg = Split-Command $cmd
            if (-not (Test-Path -LiteralPath $exe)) { throw 'its uninstaller is missing - use "Fix stuck apps"' }
            if ($cmd -match 'steam://uninstall') {
                if ($App.Location -and -not (Test-Path -LiteralPath $App.Location)) { throw 'its files are already gone - use "Fix stuck apps"' }
                Start-Process -FilePath $exe -ArgumentList $arg
                Warn 'Steam opened - finish the uninstall there'
                return $false
            }
            if ($arg) { $proc = Start-Process -FilePath $exe -ArgumentList $arg -PassThru }
            else      { $proc = Start-Process -FilePath $exe -PassThru }
            $null = $proc.Handle   # keeps ExitCode readable
            $proc.WaitForExit()
            $code = $proc.ExitCode
            Wait-ForRemoval $App.Key   # some uninstallers hand off to a helper and exit early
        }
    } catch {
        Fail "$($App.Name): $($_.Exception.Message)"
        return $false
    }
    if (Test-Path -LiteralPath $App.Key) {
        Warn "$($App.Name) is still listed (exit $code) - cancelled, or needs a restart"
        Write-VoidLog "uninstall incomplete: $($App.Name)"
        return $false
    }
    Ok "$($App.Name) removed"
    Write-VoidLog "uninstalled $($App.Name)"
    $true
}

$NeverLeftover = '^(Microsoft|Windows|Common Files|Intel|NVIDIA|NVIDIA Corporation|AMD|Realtek|Google|Packages|Programs|Temp|Steam|Valve|Mozilla|Apple|Adobe|Oracle|Java|Python|Package Cache)$'

function Get-CleanName([string]$s) {
    ($s -replace '\(.*?\)', '' -replace '\s+version\s+.*$', '' -replace '\s+v?\d+(\.\d+)+.*$', '' -replace '\s+(x64|x86|64-bit|32-bit)$', '').Trim()
}

# Folders an app leaves behind in AppData / ProgramData / Program Files (exact name matches only).
function Find-Leftovers($App) {
    $name = Get-CleanName $App.Name
    if ($name.Length -lt 4 -or $name -match $NeverLeftover) { return }
    $pub = ($App.Publisher -replace ',?\s+(Inc\.?|LLC|Ltd\.?|Limited|Corporation|Corp\.?|GmbH|B\.V\.|S\.A\.|Pte\.?).*$', '').Trim()
    $roots = @($env:APPDATA, $env:LOCALAPPDATA, "$env:LOCALAPPDATA\Programs", $env:ProgramData, $env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
    $names = @($name, ($name -replace '\s', '')) | Select-Object -Unique
    $cands = foreach ($root in $roots) {
        foreach ($n in $names) {
            Join-Path $root $n
            if ($pub.Length -ge 3 -and $pub -notmatch $NeverLeftover) { Join-Path (Join-Path $root $pub) $n }
        }
    }
    if ($App.Location) { $cands = @($cands) + $App.Location }
    $cands | Where-Object {
        $_ -and (Test-Path -LiteralPath $_ -PathType Container) -and
        ($_.TrimEnd('\') -split '\\').Count -ge 3 -and
        ($roots -notcontains $_.TrimEnd('\')) -and
        $_ -notlike "$env:SystemRoot*"
    } | Sort-Object -Unique | ForEach-Object {
        $bytes = Get-FolderBytes $_
        [pscustomobject]@{ Path = $_; Bytes = $bytes; On = $true; Text = "$($Col.Text)$(Limit $_ 50)$R$($Col.Dim)$((Format-Size $bytes).PadLeft(9))$R" }
    }
}

function Remove-Leftovers($Items) {
    $picked = Select-Items 'Leftovers' $Items -Hint 'folders the uninstaller left behind - they go to the Recycle Bin' `
        -Footer { param($list) 'selected: ' + (Format-Size (($list | Where-Object On | Measure-Object Bytes -Sum).Sum)) }
    $sel = @($Items | Where-Object On)
    if (-not $picked -or -not $sel) { return }
    Show-Title 'Leftovers'
    foreach ($it in $sel) {
        try { Move-ToRecycleBin $it.Path; Ok "recycled $($it.Path)" } catch { Fail "$($it.Path): $($_.Exception.Message)" }
    }
    Write-VoidLog "leftovers: recycled $($sel.Count) folder(s), $(Format-Size (($sel | Measure-Object Bytes -Sum).Sum))"
}

function Invoke-UninstallMenu {
    while ($true) {
        Show-Title 'Uninstall apps'
        Note 'type part of a name to search, Enter to list everything, Esc to go back'
        Note "drivers and runtimes that Windows or games need aren't listed"
        Note 'bulk job? BCUninstaller is in the Toolbox (T)'
        Out-Line
        $q = Read-Line 'search'
        if ($null -eq $q) { return }
        $items = @($Apps | Where-Object {
            $_.Name -notmatch $Protected -and (-not $q -or
            $_.Name.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $_.Publisher.IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        } | ForEach-Object {
            $size = if ($_.SizeMB) { Format-Size ($_.SizeMB * 1MB) } else { '' }
            [pscustomobject]@{ App = $_; On = $false; Text = "$($Col.Text)$(Limit $_.Name 36)$R$($Col.Dim)$($size.PadLeft(9))  $(Limit $_.Publisher 15)$R" }
        })
        if (-not $items) { Out-Line; Warn "nothing matches '$q'"; Wait-Back; continue }
        $picked = Select-Items 'Uninstall apps' $items -Hint 'select the apps to remove' `
            -Footer { param($list) "$(@($list | Where-Object On).Count) selected" }
        $chosen = @($items | Where-Object On | ForEach-Object App)
        if (-not $picked -or -not $chosen) { continue }
        Show-Title 'Uninstall apps'
        foreach ($c in $chosen) { Note "  - $($c.Name)" }
        Out-Line
        if (-not (Confirm-Action "uninstall these $($chosen.Count)? this can't be undone")) { continue }
        Out-Line
        $leftovers = @()
        foreach ($c in $chosen) {
            if (Invoke-AppUninstall $c) { $leftovers += @(Find-Leftovers $c) }
        }
        Update-AppIndex
        if ($leftovers) {
            Out-Line; Info "found $($leftovers.Count) leftover folder(s)..."
            Start-Sleep -Milliseconds 900
            Remove-Leftovers $leftovers
        }
        Wait-Back
    }
}

# ── 3. stuck apps ──────────────────────────────────────────────────────
function Find-StuckApps {
    foreach ($a in $AllEntries) {
        $why = @()
        # only judge paths on drives that are actually plugged in
        if ($a.Location -match '^[A-Za-z]:\\' -and (Test-Path -LiteralPath $a.Location.Substring(0, 3))) {
            if (-not (Test-Exists $a.Location)) { $why += 'folder gone' }
        }
        $cmd = if ($a.Quiet) { $a.Quiet } else { $a.Uninstall }
        if ($cmd -and $cmd -notmatch 'msiexec') {
            $exe = (Split-Command $cmd)[0]
            if ($exe -match '^[A-Za-z]:\\' -and (Test-Path -LiteralPath $exe.Substring(0, 3)) -and -not (Test-Exists $exe)) {
                $why += 'uninstaller gone'
            }
        }
        if ($why) { $a | Select-Object *, @{ n = 'Why'; e = { $why -join ', ' } } }
    }
}

function Backup-RegKey([string]$PsPath, [string]$Name) {
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $reg  = $PsPath -replace '^(Microsoft\.PowerShell\.Core\\)?Registry::', ''
    $file = Join-Path $BackupDir ('{0}_{1:yyyyMMdd-HHmmss}.reg' -f ($Name -replace '[^\w\-]+', '_'), (Get-Date))
    & reg.exe export $reg $file /y 2>$null | Out-Null
}

function Invoke-FixStuck {
    Show-Title 'Fix stuck apps'
    Info 'checking...'
    $stuck = @(Find-StuckApps | ForEach-Object {
        [pscustomobject]@{ App = $_; On = $true; Text = "$($Col.Text)$(Limit $_.Name 32)$R$($Col.Dim)  $($_.Why)$R" }
    })
    if (-not $stuck) { Show-Title 'Fix stuck apps'; Ok 'nothing stuck - your app list is clean'; Wait-Back; return }
    $picked = Select-Items 'Fix stuck apps' $stuck -Hint 'already gone but still in Settings > Apps - entries are backed up'
    $sel = @($stuck | Where-Object On)
    if (-not $picked -or -not $sel) { return }
    Show-Title 'Fix stuck apps'
    foreach ($s in $sel) {
        try {
            Backup-RegKey $s.App.Key $s.App.Name
            Remove-Item -LiteralPath $s.App.Key -Recurse -Force -ErrorAction Stop
            Ok "cleared $($s.App.Name)"
            Write-VoidLog "cleared stuck entry $($s.App.Name)"
        } catch { Fail "$($s.App.Name): $($_.Exception.Message)" }
    }
    Out-Line
    Note "backups: $BackupDir"
    Note '(double-click a .reg file there to undo)'
    Update-AppIndex
    Wait-Back
}

# ── 4. old installers ──────────────────────────────────────────────────
$InstallerExt = '.exe', '.msi', '.msix', '.msixbundle', '.appx', '.appxbundle', '.iso'
$ArchiveExt   = '.zip', '.7z', '.rar'

function Get-DownloadsFolder {
    try { $f = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path; if ($f) { return $f } } catch {}
    Join-Path $env:USERPROFILE 'Downloads'
}

function Invoke-Installers {
    Show-Title 'Old installers'
    Info 'looking in Downloads and Desktop...'
    $dirs = @((Get-DownloadsFolder), [Environment]::GetFolderPath('Desktop')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    $files = @(foreach ($d in $dirs) {
        Get-ChildItem -LiteralPath $d -File -Recurse -Depth 1 -Force -ErrorAction SilentlyContinue |
            Where-Object { ($InstallerExt + $ArchiveExt) -contains $_.Extension.ToLower() }
    })
    if (-not $files) { Show-Title 'Old installers'; Ok 'no installers lying around'; Wait-Back; return }
    # pre-tick things that are clearly setup files and at least a day old; portable apps / archives stay unticked
    $items = @($files | Sort-Object Length -Descending | ForEach-Object {
        $ext = $_.Extension.ToLower()
        $setupish = $ext -in '.msi', '.msix', '.msixbundle', '.appx', '.appxbundle', '.iso' -or
                    $_.BaseName -match 'setup|install|update|x64|x86|win(32|64)|amd64|bootstrap|redist|\d+\.\d+'
        $on = ($ArchiveExt -notcontains $ext) -and $setupish -and ((Get-Date) - $_.LastWriteTime).TotalDays -ge 1
        [pscustomobject]@{
            File = $_; Bytes = [double]$_.Length; On = $on
            Text = "$($Col.Text)$(Limit $_.Name 34)$R$($Col.Dim)$((Format-Size $_.Length).PadLeft(9))  $(Format-Age $_.LastWriteTime)$R"
        }
    })
    $picked = Select-Items 'Old installers' $items -Hint 'setup files you already ran - picked ones go to the Recycle Bin' `
        -Footer { param($list, $at) 'selected: ' + (Format-Size (($list | Where-Object On | Measure-Object Bytes -Sum).Sum)) + "$($Col.Dim)   $(Limit $list[$at].File.DirectoryName 34)$R" }
    $sel = @($items | Where-Object On)
    if (-not $picked -or -not $sel) { return }
    Show-Title 'Old installers'
    foreach ($it in $sel) {
        try { Move-ToRecycleBin $it.File.FullName; Ok "recycled $($it.File.Name)" } catch { Fail "$($it.File.Name): $($_.Exception.Message)" }
    }
    $total = ($sel | Measure-Object Bytes -Sum).Sum
    Out-Line; Ok "moved $(Format-Size $total) to the Recycle Bin"
    Write-VoidLog "installers: recycled $($sel.Count) file(s), $(Format-Size $total)"
    Wait-Back
}

# ── 5. dev junk ────────────────────────────────────────────────────────
$AlwaysDevJunk = 'node_modules', '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache', '.next', '.nuxt', '.turbo', '.parcel-cache', '.svelte-kit'

function Test-DevJunk([string]$Dir, [string]$Name) {
    if ($AlwaysDevJunk -contains $Name) { return $true }
    $parent = [IO.Path]::GetDirectoryName($Dir)
    if ($Name -in '.venv', 'venv', 'env') { return (Test-Path -LiteralPath (Join-Path $Dir 'pyvenv.cfg')) }
    if ($Name -eq 'target') { return (Test-Path -LiteralPath (Join-Path $parent 'Cargo.toml')) }
    if ($Name -in 'dist', 'build') { return (Test-Path -LiteralPath (Join-Path $parent 'package.json')) }
    $false
}

function Find-DevJunk([string]$Root, [int]$Depth, $Found) {
    if ($Depth -gt 8) { return }
    $subs = $null
    try { $subs = [IO.Directory]::GetDirectories($Root) } catch { return }
    foreach ($d in $subs) {
        $name = [IO.Path]::GetFileName($d)
        try { if ([IO.File]::GetAttributes($d) -band [IO.FileAttributes]::ReparsePoint) { continue } } catch { continue }
        if (Test-DevJunk $d $name) { $Found.Add($d); continue }
        if ($name.StartsWith('.') -or $name -eq 'AppData') { continue }
        Find-DevJunk $d ($Depth + 1) $Found
    }
}

function Invoke-Purge {
    Show-Title 'Dev junk'
    $roots = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments')) +
             @('source', 'code', 'dev', 'projects', 'repos', 'GitHub', 'src', 'workspace' | ForEach-Object { Join-Path $env:USERPROFILE $_ })
    $roots = @($roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Sort-Object -Unique)
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($root in $roots) {
        Out-Text "`r$script:P  $($Col.Acc)▸$R $($Col.Text)scanning $(Limit $root 50)$R$E[K"
        Find-DevJunk $root 0 $found
    }
    Out-Text "`r$E[K"
    if (-not $found.Count) { Ok 'no node_modules, venvs or build caches found'; Note ('looked in: ' + ($roots -join ', ')); Wait-Back; return }
    $i = 0
    $items = @(foreach ($d in $found) {
        $i++
        Out-Text "`r$script:P  $($Col.Acc)$($SpinChars[$i % $SpinChars.Length])$R $($Col.Text)measuring $i/$($found.Count)...$R$E[K"
        $bytes = Get-FolderBytes $d
        $touched = [IO.Directory]::GetLastWriteTime([IO.Path]::GetDirectoryName($d))
        $show = if ($d.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) { '~' + $d.Substring($env:USERPROFILE.Length) } else { $d }
        # build output and venvs can be what something runs from (Vencord-style mods load from dist, bots from venv)
        $risky  = [IO.Path]::GetFileName($d) -in 'dist', 'build', 'target', '.venv', 'venv', 'env'
        $recent = ((Get-Date) - $touched).TotalDays -lt 7
        [pscustomobject]@{
            Path = $d; Bytes = $bytes
            On = -not $risky -and -not $recent
            Note = if ($risky) { 'something may run from this - rebuild after' } elseif ($recent) { 'project touched this week' } else { '' }
            Text = "$($Col.Text)$(Limit $show 38)$R$($Col.Dim)$((Format-Size $bytes).PadLeft(9))  $(Format-Age $touched)$R"
        }
    })
    $items = @($items | Sort-Object Bytes -Descending)
    $picked = Select-Items 'Dev junk' $items -Hint 'rebuildable (npm/pip install brings it back) - deleted for good' `
        -Footer { param($list, $at) 'selected: ' + (Format-Size (($list | Where-Object On | Measure-Object Bytes -Sum).Sum)) + "   $($Col.Warn)$($list[$at].Note)$R" }
    $sel = @($items | Where-Object On)
    if (-not $picked -or -not $sel) { return }
    Show-Title 'Dev junk'
    foreach ($it in $sel) {
        & cmd.exe /c rd /s /q "\\?\$($it.Path)" 2>$null   # handles paths longer than 260 chars
        if (Test-Path -LiteralPath $it.Path) { Warn "partly removed (files in use?): $($it.Path)" } else { Ok "deleted $($it.Path)" }
    }
    $total = ($sel | Measure-Object Bytes -Sum).Sum
    Out-Line; Ok "freed about $(Format-Size $total)"
    Write-VoidLog "dev junk: deleted $($sel.Count) folder(s), $(Format-Size $total)"
    Wait-Back
}

# ── 6. live status ─────────────────────────────────────────────────────
function Get-Num($v) {
    $d = 0.0
    if ([double]::TryParse(([string]$v).Trim(), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { $d } else { $null }
}

# per-app CPU from the change in processor time since the last frame (much faster than perf counters)
function Get-TopApps([int]$Cores) {
    $now = [DateTime]::UtcNow
    $prev = $script:PrevCpu
    $elapsed = if ($script:PrevAt) { ($now - $script:PrevAt).TotalMilliseconds } else { 0 }
    $cur = @{}
    $rows = foreach ($proc in (Get-Process -ErrorAction SilentlyContinue)) {
        if ($proc.Id -eq 0) { continue }
        $pt = $proc.TotalProcessorTime
        $ms = if ($pt) { $pt.TotalMilliseconds } else { 0.0 }
        $cur[$proc.Id] = $ms
        $delta = if ($prev -and $prev.ContainsKey($proc.Id)) { [Math]::Max($ms - $prev[$proc.Id], 0) } else { 0 }
        [pscustomobject]@{ Name = $proc.ProcessName; Cpu = $delta; Mem = [double]$proc.WorkingSet64 }
    }
    $script:PrevCpu = $cur; $script:PrevAt = $now
    @($rows | Group-Object Name | ForEach-Object {
        $cpuMs = ($_.Group | Measure-Object Cpu -Sum).Sum
        [pscustomobject]@{
            Name  = $_.Name; Count = $_.Count
            Cpu   = if ($elapsed -gt 0) { 100 * $cpuMs / ($elapsed * [Math]::Max($Cores, 1)) } else { 0 }
            Mem   = ($_.Group | Measure-Object Mem -Sum).Sum
        }
    } | Sort-Object Cpu, Mem -Descending | Select-Object -First 6)
}

function Get-LiveStats([int]$Cores, [bool]$HasNv) {
    $os    = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpus  = @(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -ErrorAction SilentlyContinue)
    $disk  = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction SilentlyContinue
    $nets  = @(Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction SilentlyContinue)
    $sysDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction SilentlyContinue
    $gpu = $null
    if ($HasNv) {
        $line = & nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($line) {
            $f = $line -split ','
            $gpu = [pscustomobject]@{ Util = Get-Num $f[0]; Temp = Get-Num $f[1]; MemUsed = Get-Num $f[2]; MemTotal = Get-Num $f[3]; Power = Get-Num $f[4] }
        }
    }
    [pscustomobject]@{
        Cpu        = [double]($cpus | Where-Object Name -eq '_Total').PercentProcessorTime
        CoreLoad   = [double[]]@($cpus | Where-Object Name -ne '_Total' | Sort-Object { [int](($_.Name -split ',')[-1]) } | ForEach-Object { [double]$_.PercentProcessorTime } | Select-Object -First 48)
        MemPct     = if ($os) { 100 * (1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) } else { 0 }
        MemUsed    = if ($os) { ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB } else { 0 }
        MemTotal   = if ($os) { $os.TotalVisibleMemorySize * 1KB } else { 0 }
        Uptime     = if ($os) { (Get-Date) - $os.LastBootUpTime } else { [TimeSpan]::Zero }
        DiskPct    = if ($disk) { [Math]::Min([double]$disk.PercentDiskTime, 100) } else { 0 }
        DiskRead   = if ($disk) { [double]$disk.DiskReadBytesPersec } else { 0 }
        DiskWrite  = if ($disk) { [double]$disk.DiskWriteBytesPersec } else { 0 }
        NetDown    = [double](($nets | Measure-Object BytesReceivedPersec -Sum).Sum)
        NetUp      = [double](($nets | Measure-Object BytesSentPersec -Sum).Sum)
        SysFreePct = if ($sysDrive -and $sysDrive.Size) { 100 * $sysDrive.FreeSpace / $sysDrive.Size } else { 100 }
        Gpu        = $gpu
        Top        = Get-TopApps $Cores
    }
}

function Get-Health($s) {
    $score = 100; $notes = New-Object System.Collections.Generic.List[string]
    if ($s.Cpu -ge 90) { $score -= 15; $notes.Add('CPU is maxed out') }
    if ($s.MemPct -ge 90) { $score -= 20; $notes.Add('RAM is almost full - close some apps') } elseif ($s.MemPct -ge 75) { $score -= 8 }
    if ($s.SysFreePct -lt 10) { $score -= 20; $notes.Add("$env:SystemDrive is almost full") } elseif ($s.SysFreePct -lt 20) { $score -= 8; $notes.Add("$env:SystemDrive is getting full") }
    if ($s.Uptime.TotalDays -ge 7) { $score -= 10; $notes.Add("no restart in $([int]$s.Uptime.TotalDays) days - a restart helps") }
    if ($s.Gpu -and $s.Gpu.Temp -ge 85) { $score -= 10; $notes.Add('GPU is running hot') }
    $junkOn = ($Junk | Where-Object On | Measure-Object Bytes -Sum).Sum
    if ($junkOn -ge 5GB) { $score -= 5; $notes.Add("$(Format-Size $junkOn) of junk - run Clean") }
    [pscustomobject]@{ Score = [Math]::Max($score, 0); Notes = $notes }
}

function Format-StatRow([string]$Label, [double]$Pct, [string]$Detail) {
    "$Bold$($Col.Text)$($Label.PadRight(5))$R" + ('{0,4:N0}%' -f $Pct) + "  $(Get-Meter $Pct 22)  $($Col.Dim)$Detail$R"
}

function Get-StatusLines($s, $h, [double[]]$CpuHistory, [int]$Cores) {
    $hc = if ($h.Score -ge 80) { $Col.Good } elseif ($h.Score -ge 60) { $Col.Warn } else { $Col.Bad }
    $hw = if ($h.Score -ge 80) { 'good' } elseif ($h.Score -ge 60) { 'okay' } else { 'needs attention' }
    $live = New-Object System.Collections.Generic.List[string]
    $live.Add("$Bold$($Col.Text)HEALTH$R $Bold$hc$($h.Score)$R$($Col.Dim)/100$R  $hc$($hw.PadRight(16))$R$(Get-Meter $h.Score 16 -HighIsGood)   $($Col.Dim)up $(Format-Uptime $s.Uptime)$R")
    foreach ($n in $h.Notes) { $live.Add("$($Col.Dim)       · $n$R") }
    $live.Add('')
    $live.Add((Format-StatRow 'CPU' $s.Cpu "$Cores threads"))
    $live.Add("            $(Get-Spark $CpuHistory)  $($Col.Dim)history$R")
    $live.Add("            $(Get-Spark $s.CoreLoad)  $($Col.Dim)cores$R")
    if ($s.Gpu) {
        $g = $s.Gpu
        $detail = "$($g.Temp)°C · $(Format-Size ($g.MemUsed * 1MB)) / $(Format-Size ($g.MemTotal * 1MB))"
        if ($g.Power) { $detail += " · $([int]$g.Power) W" }
        $live.Add((Format-StatRow 'GPU' $g.Util $detail))
    }
    $live.Add((Format-StatRow 'RAM' $s.MemPct "$(Format-Size $s.MemUsed) / $(Format-Size $s.MemTotal)"))
    $live.Add((Format-StatRow 'DISK' $s.DiskPct "r $(Format-Rate $s.DiskRead) · w $(Format-Rate $s.DiskWrite)"))
    $live.Add("$Bold$($Col.Text)NET$R          $($Col.Acc)▼$R $((Format-Rate $s.NetDown).PadRight(12)) $($Col.Pur)▲$R $(Format-Rate $s.NetUp)")
    $apps = New-Object System.Collections.Generic.List[string]
    $apps.Add(("$($Col.Dim){0}{1,8}{2,11}$R" -f 'APP'.PadRight(40), 'CPU', 'RAM'))
    foreach ($t in $s.Top) {
        $nm = if ($t.Count -gt 1) { "$($t.Name) ×$($t.Count)" } else { $t.Name }
        $apps.Add(("$($Col.Text){0}$R$($Col.Acc){1,8}$R$($Col.Dim){2,11}$R" -f (Limit $nm 40), ('{0:N1}%' -f $t.Cpu), (Format-Size $t.Mem)))
    }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($x in (Get-Box 'LIVE' $live)) { $out.Add($x) }
    foreach ($x in (Get-Box 'TOP APPS' $apps)) { $out.Add($x) }
    $out
}

function Show-Status {
    Show-Title 'Live status'
    Info 'warming up sensors...'
    $cores = [int](Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).NumberOfLogicalProcessors
    $hasNv = [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue)
    $hist  = New-Object System.Collections.Generic.List[double]
    $script:PrevCpu = $null; $script:PrevAt = $null
    $null = Get-LiveStats $cores $hasNv   # primes the counters and the per-app CPU baseline
    Show-Title 'Live status'
    $row = Get-Row
    while ($true) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $s = Get-LiveStats $cores $hasNv
        $hist.Add($s.Cpu); while ($hist.Count -gt 40) { $hist.RemoveAt(0) }
        $lines = Get-StatusLines $s (Get-Health $s) $hist.ToArray() $cores
        Set-Pos 0 $row
        foreach ($line in $lines) { Out-Line "$script:P$line$E[K" }
        Out-Line "$E[K"
        Out-Text "$script:P  $(Get-Keys 'q', 'back', 'b', 'open btop')$($Col.Dim)$($SpinChars[$hist.Count % $SpinChars.Length]) live$R$E[K$E[J"
        # always listen for keys between frames - even when gathering stats was slow
        $wait = [Math]::Max(300, 1000 - $sw.ElapsedMilliseconds)
        $tick = [Diagnostics.Stopwatch]::StartNew()
        $leave = $false; $btop = $false
        while ($tick.ElapsedMilliseconds -lt $wait) {
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq 'Escape' -or [string]$k.KeyChar -eq 'q') { $leave = $true; break }
                if ([string]$k.KeyChar -eq 'b') { $btop = $true; break }
            }
            Start-Sleep -Milliseconds 40
        }
        if ($leave) { return }
        if ($btop) {
            Invoke-Tool ($Tools | Where-Object Name -eq 'btop')
            Show-Title 'Live status'
            $row = Get-Row
        }
    }
}

# ── 7. disk space ──────────────────────────────────────────────────────
function Get-SteamGameFolders {
    $root = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $root) { return }
    $root = $root -replace '/', '\'
    $libs = @($root)
    $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        $libs += [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"') |
                 ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' }
    }
    $libs | Sort-Object -Unique | ForEach-Object { Join-Path $_ 'steamapps\common' } |
        Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory }
}

function Show-DiskSpace {
    Show-Title 'Disk space'
    $script:Drives = @(Get-DriveInfo)
    $body = @(foreach ($d in $Drives) {
        $used = if ($d.Size) { 100 * (1 - $d.Free / $d.Size) } else { 0 }
        "$Bold$($Col.Text)$($d.Letter)$R  " + (Get-Meter $used 34) + "  $($Col.Text)$(Format-Size $d.Free) free$R$($Col.Dim) / $(Format-Size $d.Size)$R"
    })
    foreach ($line in (Get-Box 'DRIVES' $body)) { Out-Line "$script:P$line" }
    $big = @($Apps | Where-Object SizeMB | Sort-Object SizeMB -Descending | Select-Object -First 8 | ForEach-Object {
        "$($Col.Text)$(Limit $_.Name 52)$R$($Col.Dim)$((Format-Size ($_.SizeMB * 1MB)).PadLeft(12))$R"
    })
    foreach ($line in (Get-Box 'BIGGEST APPS' $big)) { Out-Line "$script:P$line" }
    $games = @(Get-SteamGameFolders)
    if ($games) {
        $sized = foreach ($g in $games) {
            Out-Text "`r$script:P  $($Col.Dim)measuring $($g.Name)...$R$E[K"
            [pscustomobject]@{ Name = $g.Name; Bytes = Get-FolderBytes $g.FullName }
        }
        Out-Text "`r$E[K"
        $gl = @($sized | Sort-Object Bytes -Descending | Where-Object { $_.Bytes -gt 100MB } | ForEach-Object {
            "$($Col.Text)$(Limit $_.Name 52)$R$($Col.Dim)$((Format-Size $_.Bytes).PadLeft(12))$R"
        })
        if ($gl) { foreach ($line in (Get-Box 'STEAM GAMES' $gl)) { Out-Line "$script:P$line" } }
    }
    $junkTotal = ($Junk | Where-Object On | Measure-Object Bytes -Sum).Sum
    if ($junkTotal -gt 200MB) { Warn "$(Format-Size $junkTotal) of junk - press 1 on the main menu to clean it" }
    Out-Line
    Out-Line "$script:P  $(Get-Keys 'd', "explore $env:SystemDrive with dua", 'any key', 'back')"
    $k = [Console]::ReadKey($true)
    if ([string]$k.KeyChar -eq 'd') { Invoke-Tool ($Tools | Where-Object Name -eq 'dua') }
}

# ── 8. optimize ────────────────────────────────────────────────────────
function Invoke-Optimize {
    $tasks = @(
        [pscustomobject]@{ Name = 'Flush DNS cache';       Hint = "fixes sites that won't load";  On = $true
                           Run = { Clear-DnsClientCache } }
        [pscustomobject]@{ Name = 'Refresh icon cache';    Hint = 'fixes blank or wrong icons';   On = $true
                           Run = { Start-Process ie4uinit.exe -ArgumentList '-show' -Wait } }
        [pscustomobject]@{ Name = 'TRIM SSDs';             Hint = 'keeps SSDs fast';              On = $true
                           Run = { Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } |
                                   ForEach-Object { Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue } } }
        [pscustomobject]@{ Name = 'Restart Explorer';      Hint = 'fixes a glitchy taskbar';      On = $false
                           Run = { Stop-Process -Name explorer -Force; Start-Sleep -Seconds 3
                                   if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe } } }
        [pscustomobject]@{ Name = 'Clean component store'; Hint = 'old update files · 5-15 min';  On = $false
                           Run = { Start-Process Dism.exe -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup' -NoNewWindow -Wait } }
        [pscustomobject]@{ Name = 'Repair system files';   Hint = 'sfc /scannow · 10+ min';       On = $false
                           Run = { Start-Process sfc.exe -ArgumentList '/scannow' -NoNewWindow -Wait } }
    )
    foreach ($t in $tasks) { $t | Add-Member -NotePropertyName Text -NotePropertyValue "$($Col.Text)$($t.Name.PadRight(28))$R$($Col.Dim)$($t.Hint)$R" }
    $picked = Select-Items 'Optimize' $tasks -Hint 'safe maintenance - pick what to run'
    $sel = @($tasks | Where-Object On)
    if (-not $picked -or -not $sel) { return }
    Show-Title 'Optimize'
    foreach ($t in $sel) {
        Info "$($t.Name)..."
        try { & $t.Run | Out-Null; Ok "$($t.Name) done" } catch { Fail "$($t.Name): $($_.Exception.Message)" }
    }
    Write-VoidLog "optimize: $(($sel | ForEach-Object Name) -join ', ')"
    Wait-Back
}

# ── 9. update everything ───────────────────────────────────────────────
function Invoke-UpdateAll {
    Show-Title 'Update everything'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Fail 'winget is missing - install "App Installer" from the Microsoft Store'
        Wait-Back; return
    }
    Info 'checking for updates...'
    Out-Line
    winget upgrade
    Out-Line
    if (Confirm-Action 'update everything listed above?') {
        Out-Line
        winget upgrade --all
        Out-Line
        Ok 'done'
        Write-VoidLog 'updated all apps with winget'
    }
    Wait-Back
}

# ── T. toolbox (open-source GitHub tools, installed on demand with winget) ──
$Tools = @(
    [pscustomobject]@{ Name = 'btop';          Repo = 'aristocratos/btop4win';         Id = 'aristocratos.btop4win';       Exe = 'btop4win';      Find = '*btop*.exe';        Kind = 'tui'; Args = @();                          Desc = 'the prettiest full-screen system monitor there is' }
    [pscustomobject]@{ Name = 'bottom';        Repo = 'ClementTsang/bottom';           Id = 'Clement.bottom';              Exe = 'btm';           Find = 'btm.exe';           Kind = 'tui'; Args = @();                          Desc = 'graphs for CPU, RAM, network, disks and temps' }
    [pscustomobject]@{ Name = 'dua';           Repo = 'Byron/dua-cli';                 Id = 'Byron.dua-cli';               Exe = 'dua';           Find = 'dua.exe';           Kind = 'tui'; Args = @('i', "$env:SystemDrive\"); Desc = 'explore folders by size and delete from inside' }
    [pscustomobject]@{ Name = 'Czkawka';       Repo = 'qarmin/czkawka';                Id = 'qarmin.czkawka.gui';          Exe = 'czkawka_gui';   Find = '*czkawka*gui*.exe'; Kind = 'gui'; Args = @();                          Desc = 'find duplicate files, huge files and empty folders' }
    [pscustomobject]@{ Name = 'BCUninstaller'; Repo = 'Klocman/Bulk-Crap-Uninstaller'; Id = 'Klocman.BulkCrapUninstaller'; Exe = 'BCUninstaller'; Find = 'BCUninstaller.exe'; Kind = 'gui'; Args = @();                          Desc = 'bulk-remove apps and hunt down their leftovers'
                       Paths = @("$env:ProgramFiles\BCUninstaller\BCUninstaller.exe", "${env:ProgramFiles(x86)}\BCUninstaller\BCUninstaller.exe") }
    [pscustomobject]@{ Name = 'fastfetch';     Repo = 'fastfetch-cli/fastfetch';       Id = 'Fastfetch-cli.Fastfetch';     Exe = 'fastfetch';     Find = 'fastfetch.exe';     Kind = 'cli'; Args = @();                          Desc = 'your specs as a screenshot-worthy card' }
    [pscustomobject]@{ Name = 'WinUtil';       Repo = 'ChrisTitusTech/winutil';        Id = '';                            Exe = '';              Find = '';                  Kind = 'web'; Args = @();                          Desc = "Chris Titus' tweaks, debloat and app installer" }
)

function Update-SessionPath {
    $env:Path = (@([Environment]::GetEnvironmentVariable('Path', 'Machine'), [Environment]::GetEnvironmentVariable('Path', 'User')) | Where-Object { $_ }) -join ';'
}

function Find-ToolExe($Tool) {
    if (-not $Tool.Exe) { return $null }
    $cmd = Get-Command $Tool.Exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    foreach ($path in $Tool.Paths) { if ($path -and (Test-Path -LiteralPath $path)) { return $path } }
    foreach ($root in "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "$env:ProgramFiles\WinGet\Packages") {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $hit = Get-ChildItem -LiteralPath $root -Directory -Filter "$($Tool.Id)*" -ErrorAction SilentlyContinue |
               ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Filter $Tool.Find -ErrorAction SilentlyContinue } |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    $null
}

function Invoke-Tool($Tool) {
    if ($Tool.Kind -eq 'web') {
        Show-Title $Tool.Name
        Note "runs Chris Titus' WinUtil from christitus.com in its own window"
        Note "source: github.com/$($Tool.Repo)"
        Out-Line
        if (Confirm-Action 'open WinUtil?') {
            Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command "irm https://christitus.com/win | iex"'
            Write-VoidLog 'opened WinUtil'
        }
        return
    }
    $exe = Find-ToolExe $Tool
    if (-not $exe) {
        Show-Title $Tool.Name
        Info "$($Tool.Name) isn't installed yet"
        Note "github.com/$($Tool.Repo)"
        Note "installs with winget: $($Tool.Id)"
        Out-Line
        if (-not (Confirm-Action "install $($Tool.Name)?")) { return }
        Out-Line
        & winget install --id $Tool.Id -e --source winget
        Update-SessionPath
        $exe = Find-ToolExe $Tool
        if (-not $exe) { Out-Line; Fail "couldn't find $($Tool.Name) after installing - try again after a restart"; Wait-Back; return }
        Write-VoidLog "installed $($Tool.Name)"
    }
    switch ($Tool.Kind) {
        'gui'   { Start-Process -FilePath $exe }
        'cli'   { Clear-Host; Out-Line; & $exe @($Tool.Args); $script:P = Get-Pad $BlockW; Wait-Back }
        default { Clear-Host; Set-Cursor $true; & $exe @($Tool.Args); Set-Cursor $false }
    }
}

function Invoke-Toolbox {
    while ($true) {
        $items = @($Tools | ForEach-Object {
            $state = if ($_.Kind -eq 'web') { "$($Col.Acc)◆ online$R" } elseif (Find-ToolExe $_) { "$($Col.Good)● ready$R" } else { "$($Col.Dim)○ get$R" }
            [pscustomobject]@{ Tool = $_; On = $false; Text = "$Bold$($Col.Text)$($_.Name.PadRight(14))$R$($Col.Dim)$(Limit $_.Repo 32)$R  $state" }
        })
        $pick = Select-Items 'Toolbox' $items -Single -Hint 'open-source tools from GitHub - picked ones install via winget' `
            -Footer { param($list, $at) "$($Col.Acc)▸$R $($Col.Text)$($list[$at].Tool.Desc)$R" }
        if ($pick -lt 0) { return }
        Invoke-Tool $items[$pick].Tool
    }
}

# ── 0. speed test (github.com/kavehtehrani/cloudflare-speed-cli) ─────────
$SpeedRepo = 'kavehtehrani/cloudflare-speed-cli'
$SpeedDir  = Join-Path $VoidHome 'tools\cloudflare-speed-cli'

function Get-SpeedExe {
    $cmd = Get-Command cloudflare-speed-cli -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    if (Test-Path -LiteralPath $SpeedDir) {
        $hit = Get-ChildItem -LiteralPath $SpeedDir -Recurse -File -Filter 'cloudflare-speed-cli.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    $null
}

function Get-SpeedRelease {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $rel = Invoke-RestMethod -UseBasicParsing -ErrorAction Stop -Uri "https://api.github.com/repos/$SpeedRepo/releases/latest" -Headers @{ 'User-Agent' = 'VOID' }
    $zip = $rel.assets | Where-Object { $_.name -like '*x86_64-pc-windows-msvc.zip' } | Select-Object -First 1
    $sum = $rel.assets | Where-Object { $zip -and $_.name -eq "$($zip.name).sha256" } | Select-Object -First 1
    if (-not $zip -or -not $sum) { throw "the latest release ($($rel.tag_name)) has no Windows build" }
    [pscustomobject]@{ Tag = $rel.tag_name; Zip = $zip; Sum = $sum }
}

# it isn't on winget, so: the official Windows build from the project's GitHub releases, checked against its SHA-256
function Install-SpeedTool($Release) {
    $ProgressPreference = 'SilentlyContinue'   # the PowerShell 5.1 progress bar makes downloads crawl
    $tmp = Join-Path $env:TEMP ('void-speed-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $zipPath = Join-Path $tmp $Release.Zip.name
        Invoke-WebRequest -UseBasicParsing -ErrorAction Stop -Uri $Release.Zip.browser_download_url -OutFile $zipPath
        $raw = (Invoke-WebRequest -UseBasicParsing -ErrorAction Stop -Uri $Release.Sum.browser_download_url).Content
        if ($raw -is [byte[]]) { $raw = [Text.Encoding]::ASCII.GetString($raw) }
        $expected = ([string]$raw).Trim().Split(" `t`r`n", [StringSplitOptions]::RemoveEmptyEntries)[0]
        $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw 'the download failed its SHA-256 check - it was thrown away' }
        New-Item -ItemType Directory -Force -Path $SpeedDir | Out-Null
        Expand-Archive -LiteralPath $zipPath -DestinationPath $SpeedDir -Force
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-SpeedTest {
    $exe = Get-SpeedExe
    if (-not $exe) {
        Show-Title 'Speed test'
        Info "the speed test runs cloudflare-speed-cli - open source, tests against Cloudflare's network"
        Note "github.com/$SpeedRepo"
        Out-Line
        Info 'checking the latest release...'
        try { $rel = Get-SpeedRelease } catch { Fail "couldn't reach GitHub: $($_.Exception.Message)"; Wait-Back; return }
        Note "not on winget, so VOID downloads the official Windows build ($($rel.Tag), $(Format-Size $rel.Zip.size))"
        Note 'from its GitHub releases and checks it against the published SHA-256'
        Out-Line
        if (-not (Confirm-Action 'download it?')) { return }
        try {
            Install-SpeedTool $rel
            Ok "cloudflare-speed-cli $($rel.Tag) ready"
            Write-VoidLog "installed cloudflare-speed-cli $($rel.Tag)"
        } catch { Fail $_.Exception.Message; Wait-Back; return }
        $exe = Get-SpeedExe
        if (-not $exe) { Fail 'installed, but the program was not where VOID expected it'; Wait-Back; return }
    }
    Show-Title 'Speed test'
    Info "download, upload, latency and jitter against Cloudflare's network"
    Note 'the live dashboard has graphs and history - press q inside it to come back'
    Out-Line
    Out-Line "$script:P  $(Get-Keys 'enter', 'live dashboard', 't', 'quick text result', 'esc', 'back')"
    $k = [Console]::ReadKey($true)
    if ($k.Key -eq 'Enter') {
        Clear-Host; Set-Cursor $true; & $exe; Set-Cursor $false
        Write-VoidLog 'ran a speed test'
    } elseif ([string]$k.KeyChar -eq 't') {
        Out-Line; Info 'testing... (takes about 20 seconds)'; Out-Line
        & $exe --text 2>&1 | ForEach-Object { Out-Line "$script:P  $_" }
        Write-VoidLog 'ran a speed test'
        Wait-Back
    }
}

# ── S. suspicious scan ─────────────────────────────────────────────────
# "GIuychYBxsQ" yes, "GitHubDesktop" / "qBittorrent" no
function Test-RandomName([string]$s) {
    if (-not $s) { return $false }
    $s = $s.Trim()
    if ($s.Length -lt 7 -or $s -notmatch '^[A-Za-z0-9]+$') { return $false }
    $letters = ($s -replace '[^A-Za-z]', '').Length
    if ($letters -lt 5) { return $false }
    $vowels = ($s -replace '[^aeiouAEIOU]', '').Length
    $flips  = [regex]::Matches($s, '[a-z][A-Z]').Count + [regex]::Matches($s, '[A-Z]{2,}[a-z]').Count
    ($flips -ge 2) -and (($vowels / $letters) -lt 0.25)
}

$TempRx   = '\\(Temp|Downloads)\\'
$ScriptRx = '(powershell|pwsh)[^;]*(-enc|-e\s|-w\w*\s+h|iex|downloadstring|frombase64)|mshta|wscript|cscript'

function Get-SuspiciousItems {
    foreach ($a in $Apps) {
        if (Test-RandomName $a.Name) {
            $pub = if ($a.Publisher) { "publisher: $($a.Publisher)" } else { 'no publisher' }
            [pscustomobject]@{ Kind = 'app'; Name = $a.Name; Why = 'random-looking name'; Detail = $pub; Ref = $a }
        }
    }
    $runKeys = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
               'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
               'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    foreach ($k in $runKeys) {
        $props = Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -in 'PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider') { continue }
            $val = [string]$prop.Value; $why = @()
            if (Test-RandomName $prop.Name) { $why += 'random-looking name' }
            if ($val -match $TempRx)        { $why += 'runs from temp/downloads' }
            if ($val -match $ScriptRx)      { $why += 'launches a hidden script' }
            if ($why) { [pscustomobject]@{ Kind = 'startup'; Name = $prop.Name; Why = $why -join ', '; Detail = $val; Ref = $k } }
        }
    }
    Get-ScheduledTask -TaskPath '\' -ErrorAction SilentlyContinue | Where-Object State -ne 'Disabled' | ForEach-Object {
        $exec = ($_.Actions | Where-Object { $_.Execute } | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join '; '
        $why = @()
        if (Test-RandomName $_.TaskName) { $why += 'random-looking name' }
        if ($exec -match $TempRx)        { $why += 'runs from temp/downloads' }
        if ($exec -match $ScriptRx)      { $why += 'launches a hidden script' }
        if ($why) { [pscustomobject]@{ Kind = 'task'; Name = $_.TaskName; Why = $why -join ', '; Detail = $exec; Ref = $_ } }
    }
}

function Invoke-SuspiciousScan {
    Show-Title 'Suspicious scan'
    Info 'checking installed apps, startup entries and scheduled tasks...'
    $hits = @(Get-SuspiciousItems | ForEach-Object {
        [pscustomobject]@{
            Kind = $_.Kind; Name = $_.Name; Why = $_.Why; Detail = $_.Detail; Ref = $_.Ref; On = $false
            Text = "$($Col.Dim)$($_.Kind.PadRight(8))$R$($Col.Text)$(Limit $_.Name 22)$R  $($Col.Warn)$(Limit $_.Why 30)$R"
        }
    })
    if (-not $hits) {
        Show-Title 'Suspicious scan'
        Ok 'nothing sketchy found'
        Note 'this is a quick sniff test, not an antivirus - press V on the menu for a real scan'
        Wait-Back; return
    }
    $picked = Select-Items 'Suspicious scan' $hits -Hint 'not proof of malware - google it first before removing anything' `
        -Footer { param($list, $at) "$($Col.Dim)$(Limit $list[$at].Detail 64)$R" }
    $sel = @($hits | Where-Object On)
    if (-not $picked -or -not $sel) { return }
    Show-Title 'Suspicious scan'
    foreach ($h in $sel) {
        switch ($h.Kind) {
            'app' { if (Invoke-AppUninstall $h.Ref) { Update-AppIndex } }
            'startup' {
                Backup-RegKey ('Registry::' + (Convert-Path $h.Ref)) "startup_$($h.Name)"
                Remove-ItemProperty -LiteralPath $h.Ref -Name $h.Name -ErrorAction SilentlyContinue
                Ok "removed $($h.Name) from startup (backed up)"
                Write-VoidLog "removed startup entry $($h.Name)"
            }
            'task' {
                Disable-ScheduledTask -TaskName $h.Ref.TaskName -TaskPath $h.Ref.TaskPath -ErrorAction SilentlyContinue | Out-Null
                Ok "disabled task $($h.Name)"
                Write-VoidLog "disabled scheduled task $($h.Name)"
            }
        }
    }
    Wait-Back
}

# ── V. virus scan ──────────────────────────────────────────────────────
function Invoke-VirusScan {
    Show-Title 'Virus scan'
    $mb = "$env:ProgramFiles\Malwarebytes\Anti-Malware\Malwarebytes.exe"
    $def = $null
    try { $def = Get-MpComputerStatus -ErrorAction Stop } catch {}
    if ($def -and $def.AMRunningMode -eq 'Normal') {
        Info 'running a Microsoft Defender quick scan (a few minutes)...'
        $start = Get-Date
        Start-MpScan -ScanType QuickScan
        $found = @(Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object { $_.InitialDetectionTime -ge $start })
        if ($found) { Warn "$($found.Count) threat(s) found - open Windows Security > Protection history" }
        else { Ok 'scan finished - nothing found' }
        Write-VoidLog "defender quick scan: $($found.Count) threat(s)"
    } elseif (Test-Path -LiteralPath $mb) {
        Info "Malwarebytes is your antivirus, so Defender's scanner is off."
        Info 'opening Malwarebytes - hit "Scan" there.'
        Start-Process $mb
    } else {
        Info 'opening Windows Security...'
        Start-Process 'windowsdefender://threat/'
    }
    Wait-Back
}

# ── H. history ─────────────────────────────────────────────────────────
function Show-History {
    Show-Title 'History'
    if (-not (Test-Path -LiteralPath $HistoryFile)) {
        Note 'nothing yet - VOID logs everything it cleans, removes and fixes here'
        Wait-Back; return
    }
    $lines = @(Get-Content -LiteralPath $HistoryFile -Tail 40 -Encoding UTF8)
    [array]::Reverse($lines)
    foreach ($line in $lines) {
        $parts = $line -split '  ', 2
        Out-Line "$script:P  $($Col.Dim)$($parts[0])$R  $($Col.Text)$($parts[1])$R"
    }
    Out-Line
    Note "full log: $HistoryFile"
    Wait-Back
}

# ── void remove ────────────────────────────────────────────────────────
function Remove-Void {
    Show-Title 'Remove VOID'
    Note 'deletes VOID, its shortcuts, the void command, its history and backups'
    Out-Line
    if (-not (Confirm-Action 'remove VOID from this PC?')) { return }
    Set-Location $env:USERPROFILE
    [Environment]::CurrentDirectory = $env:USERPROFILE
    Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\void.cmd') -Force -ErrorAction SilentlyContinue
    foreach ($dir in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) {
        Remove-Item -LiteralPath (Join-Path $dir 'VOID.lnk') -Force -ErrorAction SilentlyContinue
    }
    # only wipe the whole folder if it's VOID's own; otherwise just VOID's files
    if ((Split-Path $VoidHome -Leaf) -eq '.void') { Remove-Item -LiteralPath $VoidHome -Recurse -Force -ErrorAction SilentlyContinue }
    else { 'void.ps1', 'void.cmd', 'void.ico', 'history.log', 'settings.json' | ForEach-Object { Remove-Item -LiteralPath (Join-Path $VoidHome $_) -Force -ErrorAction SilentlyContinue } }
    Out-Line
    Ok 'VOID removed - see you in the void.'
    Start-Sleep -Seconds 2
}

# ── screens: demo frames with made-up data, used to render the README images ──
if ($Screens) {
    $env:USERNAME = 'you'
    $script:P = Get-Pad $BlockW
    $script:Sys = [pscustomobject]@{ OS = 'Windows 11 Pro'; CPU = 'AMD Ryzen 7 7800X3D'; GPU = 'RTX 4070 SUPER'; RAM = 32 }
    $script:Drives = @([pscustomobject]@{ Letter = 'C:'; Size = 1000GB; Free = 402GB }, [pscustomobject]@{ Letter = 'D:'; Size = 2000GB; Free = 1210GB })
    $script:Junk = @(
        @('Your temp files', 3.4GB, $true, ''), @('Windows temp files', 412MB, $true, ''), @('Crash dumps', 1.9GB, $true, ''),
        @('Error reports', 86MB, $true, ''), @('Windows Update leftovers', 2.2GB, $true, ''), @('Delivery Optimization cache', 740MB, $true, ''),
        @('Browser caches', 1.6GB, $true, 'close browsers first'), @('Discord cache', 750MB, $true, ''),
        @('npm / pip / yarn caches', 2.4GB, $true, 'redownloaded if needed'), @('Shader caches', 4.0GB, $false, 'games may stutter once'),
        @('Recycle Bin', 610MB, $false, 'empties it for good')
    ) | ForEach-Object {
        [pscustomobject]@{ Name = $_[0]; Bytes = [double]$_[1]; On = $_[2]
            Text = "$($Col.Text)$($_[0].PadRight(28))$R$($Col.Dim)$((Format-Size $_[1]).PadLeft(9))  $($_[3])$R" }
    }
    function Out-Screen([string]$Name, $Lines) { "=== $Name ==="; $Lines }

    $lp = Get-Pad $Logo[0].Length
    $bar = (Get-Gradient ('━' * 30) 0 44 18) + $Track + ('━' * 14) + $R + " $($Col.Text) 68%$R"
    Out-Screen 'intro' @(
        ''; for ($i = 0; $i -lt $Logo.Count; $i++) { $lp + (Get-Gradient $Logo[$i] 0 0 (13 - $i * 1.5)) }
        ''; ((Get-Pad $Tagline.Length) + $Col.Dim + $Tagline + $R); ''; ''
        ((Get-Pad 49) + $bar); ((Get-Pad 26) + "$($Col.Acc)⠼$R $($Col.Dim)sniffing: browser caches$R"); ''
    )
    $script:SelIdx = 2
    Out-Screen 'main' @(Get-MainLines)

    Out-Screen 'clean' @(
        Get-TitleLines 'Clean junk'; "$script:P  $($Col.Dim)pick what to clean - sizes are what VOID found just now$R"; ''
        Get-PickerLines $Junk 6 0 11 { param($list) 'selected: ' + (Format-Size (($list | Where-Object On | Measure-Object Bytes -Sum).Sum)) } `
            (Get-Keys '↑↓', 'move', 'space', 'select', 'a', 'all', 'enter', 'go', 'esc', 'back')
    )

    $apps = @(('chrome', 24, 6.1, 3.1GB), ('Discord', 6, 1.2, 1.4GB), ('obs64', 1, 3.8, 612MB), ('Code', 9, 0.9, 1.8GB), ('Spotify', 7, 0.4, 890MB), ('explorer', 1, 0.3, 240MB)) |
        ForEach-Object { [pscustomobject]@{ Name = $_[0]; Count = $_[1]; Cpu = $_[2]; Mem = [double]$_[3] } } | Sort-Object Cpu -Descending
    $st = [pscustomobject]@{
        Cpu = 23; CoreLoad = [double[]](12, 40, 8, 66, 21, 5, 93, 30, 14, 9, 51, 27, 6, 18, 72, 11); MemPct = 47; MemUsed = 15GB; MemTotal = 32GB
        Uptime = New-TimeSpan -Days 1 -Hours 4; DiskPct = 6; DiskRead = 2.1MB; DiskWrite = 640KB; NetDown = 3.4MB; NetUp = 220KB; SysFreePct = 40
        Gpu = [pscustomobject]@{ Util = 71; Temp = 58; MemUsed = 6100; MemTotal = 12282; Power = 182 }; Top = $apps
    }
    $hist = [double[]](8, 12, 10, 18, 25, 22, 30, 41, 38, 29, 24, 33, 47, 52, 44, 36, 28, 31, 26, 23, 19, 24, 35, 61, 77, 58, 42, 33, 27, 23)
    Out-Screen 'status' @(Get-TitleLines 'Live status'; (Get-StatusLines $st (Get-Health $st) $hist 16 | ForEach-Object { "$script:P$_" }); ''; "$script:P  $(Get-Keys 'q', 'back', 'b', 'open btop')$($Col.Dim)⠹ live$R")

    $ready = 'btop', 'dua', 'BCUninstaller'
    $tb = @($Tools | ForEach-Object {
        $state = if ($_.Kind -eq 'web') { "$($Col.Acc)◆ online$R" } elseif ($ready -contains $_.Name) { "$($Col.Good)● ready$R" } else { "$($Col.Dim)○ get$R" }
        [pscustomobject]@{ Tool = $_; On = $false; Text = "$Bold$($Col.Text)$($_.Name.PadRight(14))$R$($Col.Dim)$(Limit $_.Repo 32)$R  $state" }
    })
    Out-Screen 'toolbox' @(
        Get-TitleLines 'Toolbox'; "$script:P  $($Col.Dim)open-source tools from GitHub - picked ones install via winget$R"; ''
        Get-PickerLines $tb 2 0 10 { param($list, $at) "$($Col.Acc)▸$R $($Col.Text)$($list[$at].Tool.Desc)$R" } (Get-Keys '↑↓', 'move', 'enter', 'open', 'esc', 'back') -Single
    )

    foreach ($name in $Themes.Keys) {
        Set-Theme $name
        Out-Screen "theme-$name" @(foreach ($l in $Logo) { Get-Gradient $l }; ''; "$($Col.Acc)$($name.PadLeft(14 + [int]($name.Length / 2)))$R")
    }
    exit
}

# ── self test / preview (no input) ─────────────────────────────────────
if ($SelfTest) {
    $script:P = ''
    $script:Sys = Get-SysInfo; Update-AppIndex; $script:Drives = @(Get-DriveInfo); $script:Junk = Measure-Junk
    "sys:     $($Sys.OS) | $($Sys.CPU) | $($Sys.GPU) | $($Sys.RAM) GB"
    "apps:    $($Apps.Count) listed"
    "junk:    " + (($Junk | ForEach-Object { "$($_.Name)=$(Format-Size $_.Bytes)$(if (-not $_.On) { ' (off)' })" }) -join ', ')
    "stuck:   " + ((Find-StuckApps | ForEach-Object { "$($_.Name) [$($_.Why)]" }) -join '; ')
    "sus:     " + ((Get-SuspiciousItems | ForEach-Object { "$($_.Kind):$($_.Name) [$($_.Why)]" }) -join '; ')
    "tools:   " + (($Tools | ForEach-Object { "$($_.Name)=$(if ($_.Kind -eq 'web') { 'web' } elseif (Find-ToolExe $_) { 'ready' } else { 'get' })" }) -join ', ')
    "nav:     " + (($NavCells | ForEach-Object Key) -join ' ')
    $widths = @(Get-MainLines | ForEach-Object { Get-VisLen $_ })
    "widths:  main max $(($widths | Measure-Object -Maximum).Maximum) over $($widths.Count) lines"
    foreach ($name in 'void', 'inferno') { Set-Theme $name; "theme:   $name -> " + ((Get-MainLines)[1] -replace "$E\[[0-9;]*m", '') }
    Set-Theme 'void'
    $cores = [int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    $null = Get-LiveStats $cores $true; Start-Sleep -Milliseconds 900
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $st = Get-LiveStats $cores ([bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue))
    "stats:   one frame took $($sw.ElapsedMilliseconds) ms"
    '--- status frame ---'
    Get-StatusLines $st (Get-Health $st) @(10, 30, 50, 70, 95) $cores
    '--- main screen ---'
    Get-MainLines
    exit
}
if ($Preview) { Show-Intro; Show-Main -Full; Out-Line; exit }

# ── go ─────────────────────────────────────────────────────────────────
if ($Command -eq 'remove') { Remove-Void; exit }
try {
    Show-Intro
    if ($Command) {
        & ($Menu | Where-Object { $_.Cmd -eq $Command }).Run
    } else {
        Show-Main -Full
        while ($true) {
            $k = Read-MainKey
            $key = $k.Key.ToString()
            $ch = [string]$k.KeyChar
            if ($key -eq 'Escape' -or $ch -eq 'q') { break }
            if ($key -in 'UpArrow', 'DownArrow', 'LeftArrow', 'RightArrow') {
                Move-MenuSel ($key -replace 'Arrow', '').ToLower()
                Show-Main
            } elseif ($ch -eq 'c') {
                $names = @($Themes.Keys)
                Set-Theme $names[([array]::IndexOf($names, $ThemeName) + 1) % $names.Count]
                Save-Settings
                Show-Main
            } else {
                $want = if ($key -eq 'Enter') { $NavCells[$SelIdx].Key } else { $ch }
                $item = $Menu | Where-Object { $_.Key -and $_.Key -eq $want } | Select-Object -First 1
                if ($item) {
                    $idx = [array]::IndexOf(@($NavCells | ForEach-Object Key), $item.Key)
                    if ($idx -ge 0) { $SelIdx = $idx }
                    try { & $item.Run }
                    catch { Out-Line; Fail "something broke: $($_.Exception.Message)"; Wait-Back }
                    Show-Main -Full
                }
            }
        }
        Show-Outro
    }
} finally {
    Set-Cursor $true
    Out-Text $R
}
