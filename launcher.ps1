[CmdletBinding()]
param([switch]$Preview, [switch]$Raw)

$ErrorActionPreference = 'Stop'
[Console]::InputEncoding = New-Object Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
$vivado = 'D:\visit\Vivado\2019.2\bin\vivado.bat'

function Read-Answer([string]$Prompt) {
    if ([Console]::IsInputRedirected) {
        Write-Host ($Prompt + '：') -NoNewline
        $value = [Console]::ReadLine()
        if ($null -eq $value) { throw '输入已结束，尚未填完必填项。' }
    } else {
        $value = Read-Host $Prompt
    }
    if ($value.Trim() -ieq 'q') { throw [OperationCanceledException]::new('已取消。') }
    return $value
}

function Read-File([string]$Prompt, [string[]]$Extensions, [string]$BaseDirectory, [switch]$Required) {
    while ($true) {
        $value = (Read-Answer $Prompt).Trim().Trim('"')
        if (-not $value) {
            if (-not $Required) { return '' }
            Write-Host '此项必填，请输入现有文件的路径。' -ForegroundColor Yellow
            continue
        }
        try {
            if (-not [IO.Path]::IsPathRooted($value)) { $value = Join-Path $BaseDirectory $value }
            $file = Get-Item -LiteralPath $value -ErrorAction Stop
            if ($file.PSIsContainer -or $file.Extension -notin $Extensions) {
                throw ('请选择扩展名为 ' + ($Extensions -join ' / ') + ' 的文件。')
            }
            return $file.FullName
        } catch {
            Write-Host ('文件不可用：' + $_.Exception.Message) -ForegroundColor Yellow
        }
    }
}

# Keep user text out of cmd.exe and Tcl syntax; UTF-8 hex preserves spaces and Chinese.
function Tcl-Value([string]$Value) {
    $hex = [BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Value)).Replace('-', '')
    return ('[encoding convertfrom utf-8 [binary format H* {' + $hex + '}]]')
}

try {
    if (-not (Test-Path -LiteralPath $vivado -PathType Leaf)) {
        throw "找不到 Vivado：$vivado。请修改脚本开头的安装路径。"
    }
    if (-not $Raw) {
        & (Join-Path $PSScriptRoot 'workflow.ps1') -Preview:$Preview
        exit $LASTEXITCODE
    }
    Write-Host "`n===== Vivado 2019.2 中文启动助手 =====" -ForegroundColor Cyan
    Write-Host '输入 Q 可取消；路径可以带空格和中文，也可以粘贴带双引号的路径。'
    Write-Host '1. Tcl 命令行：在当前终端输入 Vivado Tcl 命令（默认）'
    Write-Host '2. 图形界面：打开 Vivado 窗口'
    Write-Host '3. 批处理：执行 Tcl 文件，完成后退出'
    do {
        $choice = (Read-Answer '请选择运行模式 [1/2/3，回车选 1]').Trim()
        if (-not $choice) { $choice = '1' }
        $mode = @{ '1' = 'tcl'; '2' = 'gui'; '3' = 'batch' }[$choice]
        if (-not $mode) { Write-Host '请输入 1、2 或 3。' -ForegroundColor Yellow }
    } until ($mode)

    $defaultWork = Join-Path $PSScriptRoot 'work'
    while ($true) {
        $work = (Read-Answer "工作目录：Tcl 中相对路径的起点；不存在会新建 [回车用 $defaultWork]").Trim().Trim('"')
        if (-not $work) { $work = $defaultWork }
        try {
            $work = [IO.Path]::GetFullPath($work)
            if (Test-Path -LiteralPath $work -PathType Leaf) { throw '这里需要文件夹，不能填写文件。' }
            break
        } catch { Write-Host ('目录不可用：' + $_.Exception.Message) -ForegroundColor Yellow }
    }
    Write-Host '工程路径示例：E:\FPGA\demo\demo.xpr；只启动或由 Tcl 建工程时可留空。'
    $project = Read-File '现有工程 .xpr 或检查点 .dcp 的路径 [可留空]' @('.xpr', '.dcp') $work
    Write-Host 'Tcl 路径示例：E:\FPGA\scripts\build.tcl；相对路径按上面的工作目录解析。'
    Write-Host ('附带示例：' + (Join-Path $PSScriptRoot 'example.tcl'))
    $scriptPrompt = '启动后执行的 Tcl 文件路径 [可留空]'
    if ($mode -eq 'batch') { $scriptPrompt = '要执行的 Tcl 文件路径 [批处理必填]' }
    $source = Read-File $scriptPrompt @('.tcl') $work -Required:($mode -eq 'batch')
    $scriptArgs = @()
    if ($source) {
        Write-Host '以下参数传给所选 Tcl 的 argv，顺序和含义由该 Tcl 决定；不需要则直接回车。'
        Write-Host '每行输入一个参数，带空格的路径不用加引号；空行结束，两个双引号表示一个空参数。'
        Write-Host '示例脚本可填：xc7a35tcpg236-1、top、E:\FPGA\src（每项单独一行，仅演示传参）。'
        while ($true) {
            $value = Read-Answer ('第 ' + ($scriptArgs.Count + 1) + ' 个 Tcl 参数 [回车结束]')
            if ($value -eq '') { break }
            # Accept paths pasted with surrounding quotes; shell operators remain literal data.
            if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $scriptArgs += $value
        }
    }

    $run = Join-Path $PSScriptRoot ('runs\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
    [IO.Directory]::CreateDirectory($run) | Out-Null
    $startup = Join-Path $run 'startup.tcl'
    $lines = @('if {[catch {', ('    cd ' + (Tcl-Value $work)))
    if ($project) {
        $open = 'open_project'
        if ([IO.Path]::GetExtension($project) -ieq '.dcp') { $open = 'open_checkpoint' }
        $lines += ('    ' + $open + ' ' + (Tcl-Value $project))
    }
    $values = @($scriptArgs | ForEach-Object { Tcl-Value $_ })
    $lines += ('    set ::argv [list ' + ($values -join ' ') + ']')
    $lines += '    set ::argc [llength $::argv]'
    if ($source) {
        $lines += ('    set ::argv0 ' + (Tcl-Value $source))
        $lines += ('    source ' + (Tcl-Value $source))
    }
    $lines += @('} message options]} {', '    puts stderr "ERROR: $message"',
        '    puts stderr [dict get $options -errorinfo]')
    if ($mode -eq 'batch') { $lines += '    exit 1' }
    $lines += '}'
    [IO.File]::WriteAllLines($startup, [string[]]$lines, (New-Object Text.UTF8Encoding($false)))
    Write-Host "`n运行模式：$mode"
    Write-Host "工作目录：$work"
    Write-Host "本次日志及启动记录：$run"
    Write-Host ('调用："' + $vivado + '" -mode ' + $mode + ' -source "' + $startup + '"')
    if ($Preview) {
        Write-Host '预览结束，尚未启动 Vivado。'
        exit 0
    }
    [IO.Directory]::CreateDirectory($work) | Out-Null
    # All batch arguments below are generated ASCII paths, never raw user input.
    Push-Location -LiteralPath $run
    try {
        & $vivado -mode $mode -source $startup
        $code = $LASTEXITCODE
    } finally { Pop-Location }
    if ($code -ne 0) {
        Write-Host "Vivado 返回错误代码 $code，请查看 $run\vivado.log。" -ForegroundColor Red
    }
    exit $code
} catch [OperationCanceledException] {
    Write-Host '已取消。'
    exit 0
} catch {
    Write-Host ('错误：' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
