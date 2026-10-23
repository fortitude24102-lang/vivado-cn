param([switch]$Preview)

# Read-Answer, Read-File and Tcl-Value are shared with launcher.ps1.
function Read-Number([string]$Prompt, [int]$Default, [int]$Minimum, [int]$Maximum) {
    while ($true) {
        $text = (Read-Answer $Prompt).Trim()
        if (-not $text) { return $Default }
        $number = 0
        if ([int]::TryParse($text, [ref]$number) -and $number -ge $Minimum -and $number -le $Maximum) {
            return $number
        }
        Write-Host "请输入 $Minimum 到 $Maximum 之间的整数。" -ForegroundColor Yellow
    }
}

function Read-Collection([string]$Label, [string[]]$Extensions) {
    $files = @()
    Write-Host "$Label：每行填一个文件或文件夹，文件夹会递归搜索；空行结束。"
    while ($true) {
        $value = (Read-Answer "$Label 路径 [至少一项，空行结束]").Trim().Trim('"')
        if (-not $value) {
            if ($files.Count -gt 0) { return @($files | Select-Object -Unique) }
            Write-Host '尚未添加有效文件，请继续输入。' -ForegroundColor Yellow
            continue
        }
        try {
            $item = Get-Item -LiteralPath $value -ErrorAction Stop
            $found = @($item)
            if ($item.PSIsContainer) { $found = @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File -ErrorAction Stop) }
            $found = @($found | Where-Object { $_.Extension -in $Extensions })
            if (-not $found.Count) { throw ('未找到支持的文件：' + ($Extensions -join ', ')) }
            $files += @($found | ForEach-Object FullName)
            Write-Host ('已收集 ' + (@($files | Select-Object -Unique).Count) + ' 个文件。')
        } catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
    }
}

function Invoke-Flow([hashtable]$Settings, [string]$Mode = 'batch') {
    $run = Join-Path $PSScriptRoot ('runs\flow-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    [IO.Directory]::CreateDirectory($run) | Out-Null
    $Settings['result'] = Join-Path $run 'result.txt'
    $lines = @('if {[catch {')
    foreach ($key in @($Settings.Keys | Sort-Object)) {
        if ($key -in @('sources', 'xdc')) {
            $values = @($Settings[$key] | ForEach-Object { Tcl-Value $_ })
            $lines += ('    set ::cn(' + $key + ') [list ' + ($values -join ' ') + ']')
        } else {
            $lines += ('    set ::cn(' + $key + ') ' + (Tcl-Value ([string]$Settings[$key])))
        }
    }
    $lines += ('    source -encoding utf-8 ' + (Tcl-Value (Join-Path $PSScriptRoot 'flow.tcl')))
    $lines += @('} message options]} {', '    puts stderr "ERROR: $message"',
        '    if {[dict exists $options -errorinfo]} { puts stderr [dict get $options -errorinfo] }',
        '    exit 1', '}')
    $startup = Join-Path $run 'startup.tcl'
    [IO.File]::WriteAllLines($startup, [string[]]$lines, (New-Object Text.UTF8Encoding($false)))
    Write-Host "本次日志与启动记录：$run"
    if ($Preview) {
        Write-Host '预览结束，尚未启动 Vivado、创建工程或连接硬件。'
        return @{ Code = 0; Result = $Settings['result'] }
    }
    Push-Location -LiteralPath $run
    try {
        & $vivado -mode $Mode -source $startup -notrace | Out-Host
        $code = $LASTEXITCODE
    } finally { Pop-Location }
    if ($code -ne 0) { Write-Host "Vivado 执行失败，请查看 $run\vivado.log。" -ForegroundColor Red }
    return @{ Code = $code; Result = $Settings['result'] }
}

function Open-Hardware([string]$ProjectFile = '', [string]$BitFile = '', [string]$ProbesFile = '') {
    Write-Host "`n下一步：0. 结束（默认）  1. 打开图形界面的硬件管理器  2. 终端连接并烧录 FPGA，随后打开调试界面"
    $next = Read-Number '请选择 [0/1/2，回车选 0]' 0 0 2
    if ($next -eq 0) { return 0 }
    if ($next -eq 1) {
        $result = Invoke-Flow @{ action = 'hardware_gui'; project_file = $ProjectFile } 'gui'
        return $result.Code
    }
    Write-Host '这里通过 JTAG 下载 .bit 到 FPGA；断电会丢失，不执行外部 Flash 固化。'
    if ($BitFile) {
        Write-Host "本次生成的 bit：$BitFile"
        $answer = (Read-Answer 'bit 文件路径 [回车使用本次生成的文件]').Trim().Trim('"')
        if ($answer) { $BitFile = $answer }
        if (-not (Test-Path -LiteralPath $BitFile -PathType Leaf) -or [IO.Path]::GetExtension($BitFile) -ine '.bit') {
            throw 'bit 文件不存在或扩展名不是 .bit。'
        }
        $BitFile = (Get-Item -LiteralPath $BitFile).FullName
    } else {
        $BitFile = Read-File '要烧录的 .bit 文件完整路径 [必填]' @('.bit') (Get-Location).Path -Required
    }
    if ($ProbesFile) { Write-Host "已检测到调试探针文件：$ProbesFile" }
    $probeAnswer = (Read-Answer '调试 .ltx 路径 [回车使用检测到的文件；没有则留空，输入 - 清空]').Trim().Trim('"')
    if ($probeAnswer -eq '-') { $ProbesFile = '' }
    elseif ($probeAnswer) { $ProbesFile = $probeAnswer }
    if ($ProbesFile -and (-not (Test-Path -LiteralPath $ProbesFile -PathType Leaf) -or [IO.Path]::GetExtension($ProbesFile) -ine '.ltx')) {
        throw '调试探针文件不存在或扩展名不是 .ltx。'
    }
    if ($ProbesFile) { $ProbesFile = (Get-Item -LiteralPath $ProbesFile).FullName }
    $server = (Read-Answer '硬件服务器地址 [回车用 localhost:3121，本机 USB/JTAG 通常用默认值]').Trim()
    if (-not $server) { $server = 'localhost:3121' }
    Write-Host 'Vivado 会列出目标和器件；核对 bit 路径后，输入 PROGRAM 才执行烧录。'
    $result = Invoke-Flow @{ action = 'program'; bit = $BitFile; probes = $ProbesFile; server = $server } 'tcl'
    return $result.Code
}

Write-Host "`n===== Vivado 2019.2 中文工程与上板助手 =====" -ForegroundColor Cyan
Write-Host '输入 Q 可取消。器件型号和 XDC 约束请按实际开发板填写。'
Write-Host '1. 选择器件、新建工程、添加源码和 XDC、综合/实现/生成 bit（默认）'
Write-Host '2. 打开硬件管理器或烧录已有 bit'
Write-Host '3. 原来的 GUI / Tcl 命令行 / 自定义 Tcl 启动助手'
$action = Read-Number '请选择 [1/2/3，回车选 1]' 1 1 3
if ($action -eq 3) {
    & (Join-Path $PSScriptRoot 'launcher.ps1') -Raw -Preview:$Preview
    exit $LASTEXITCODE
}
if ($action -eq 2) { $code = Open-Hardware; exit $code }

while ($true) {
    $part = (Read-Answer 'FPGA 完整器件型号 [如 xc7a35tcpg236-1；输入 ?xc7a35* 可查询已安装型号]').Trim()
    if ($part.StartsWith('?')) {
        $pattern = $part.Substring(1)
        if (-not $pattern) { $pattern = '*' }
        $lookup = Invoke-Flow @{ action = 'parts'; pattern = $pattern }
        if ($Preview) { exit 0 }
        if ($lookup.Code -ne 0) { exit $lookup.Code }
    } elseif ($part -match '^[A-Za-z0-9_-]+$') { break }
    else { Write-Host '请填写完整器件型号，或使用 ? 加通配符查询。' -ForegroundColor Yellow }
}
do {
    $name = (Read-Answer '工程名称 [英文字母开头，仅字母、数字、下划线；如 demo]').Trim()
} until ($name -match '^[A-Za-z][A-Za-z0-9_]*$')
$defaultProject = Join-Path $PSScriptRoot "projects\$name"
while ($true) {
    $projectDir = (Read-Answer "新工程完整目录 [应为尚不存在的文件夹；回车用 $defaultProject]").Trim().Trim('"')
    if (-not $projectDir) { $projectDir = $defaultProject }
    try {
        $projectDir = [IO.Path]::GetFullPath($projectDir)
        if (Test-Path -LiteralPath $projectDir) { throw '该路径已存在，请为新工程换一个目录。' }
        break
    } catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
}
do { $top = (Read-Answer '顶层模块/实体名称 [如 top，不含 .v/.vhd 后缀]').Trim() }
until ($top -match '^[A-Za-z_][A-Za-z0-9_$]*$')
Write-Host '请选择设计 RTL 文件或仅包含设计代码的目录；不要把仿真 testbench 混入设计源码。'
$sources = @(Read-Collection '设计源码' @('.v', '.sv', '.vh', '.svh', '.vhd', '.vhdl', '.mem', '.hex', '.mif'))
if (-not @($sources | Where-Object { [IO.Path]::GetExtension($_) -in @('.v', '.sv', '.vhd', '.vhdl') }).Count) {
    throw '至少需要一个 Verilog、SystemVerilog 或 VHDL 设计文件。'
}
Write-Host 'XDC 必须与开发板和顶层端口对应，包含所需的引脚、电平标准与时钟约束。'
$xdc = @(Read-Collection 'XDC 约束' @('.xdc'))
$jobs = Read-Number '并行任务数 [1-64，回车用 4]' 4 1 64
$stage = Read-Number '执行到哪一步 [1 仅建工程 / 2 完成综合 / 3 生成 bit；回车选 3]' 3 1 3
Write-Host "`n新建工程：$projectDir\$name.xpr"
Write-Host "器件：$part；顶层：$top；源码 $($sources.Count) 个；XDC $($xdc.Count) 个；执行阶段 $stage。"
$result = Invoke-Flow @{ action = 'build'; part = $part; name = $name; project_dir = $projectDir;
    top = $top; sources = $sources; xdc = $xdc; jobs = $jobs; stage = $stage }
if ($result.Code -ne 0) { exit $result.Code }
if ($Preview) { exit 0 }
$paths = [IO.File]::ReadAllLines($result.Result, [Text.Encoding]::UTF8)
Write-Host "工程：$($paths[0])" -ForegroundColor Green
if ($paths[1]) { Write-Host "bit 文件：$($paths[1])" -ForegroundColor Green }
Write-Host "报告目录：$projectDir\reports"
$code = Open-Hardware $paths[0] $paths[1] $paths[2]
exit $code
