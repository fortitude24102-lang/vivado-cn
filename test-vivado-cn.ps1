$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot ('runs\self-test-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$launcher = Join-Path $PSScriptRoot 'launcher.ps1'
if (-not (Test-Path -LiteralPath $launcher)) { throw 'FAIL: 中文启动脚本尚未实现。' }
$env:Path += ';' + $PSScriptRoot
if ((Get-Command vivado-cn -ErrorAction Stop).Source -ne (Join-Path $PSScriptRoot 'vivado-cn.cmd')) {
    throw 'FAIL: 简短命令没有使用可绕过脚本执行策略的 CMD 入口。'
}

function Run-Launcher([string[]]$Answers, [switch]$Preview) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $start.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $launcher + '" -Raw'
    if ($Preview) { $start.Arguments += ' -Preview' }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $start.StandardErrorEncoding = New-Object Text.UTF8Encoding($false)
    $process = [Diagnostics.Process]::Start($start)
    $output = $process.StandardOutput.ReadToEndAsync()
    $errors = $process.StandardError.ReadToEndAsync()
    $inputBytes = [Text.Encoding]::UTF8.GetBytes(($Answers -join "`r`n") + "`r`n")
    $process.StandardInput.BaseStream.Write($inputBytes, 0, $inputBytes.Length)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(90000)) {
        $process.Kill()
        throw 'FAIL: 启动脚本没有在 90 秒内结束。'
    }
    $result = @{ Code = $process.ExitCode; Text = $output.Result + $errors.Result }
    $process.Dispose()
    return $result
}

# Catch wrong mode selection, a lost default, and cancellation that still launches Vivado.
foreach ($case in @(@('', 'tcl'), @('2', 'gui'))) {
    $result = Run-Launcher -Answers @('invalid', $case[0], $root, '', '') -Preview
    if ($result.Code -ne 0 -or $result.Text -notmatch ('-mode ' + $case[1])) {
        throw "FAIL: 模式选择/默认值错误。$($result.Text)"
    }
}
$result = Run-Launcher -Answers @('q')
if ($result.Code -ne 0 -or $result.Text -notmatch '已取消') { throw 'FAIL: 取消操作失败。' }
$result = Run-Launcher -Answers @('3', $root, '', '')
if ($result.Code -eq 0) { throw 'FAIL: 批处理缺少 Tcl 文件时被错误执行。' }

# Run the real Vivado: verify paths and argument boundaries, and prevent Tcl evaluation of input.
$dataDir = Join-Path $root '中文 空格 & (测试) %!'
[IO.Directory]::CreateDirectory($dataDir) | Out-Null
$fixture = Join-Path $dataDir '验证 脚本.tcl'
$resultFile = Join-Path $dataDir '参数结果.txt'
$tcl = @'
set f [open [lindex $argv 0] w]
fconfigure $f -encoding utf-8
puts $f [pwd]
puts $f [llength $argv]
foreach arg [lrange $argv 1 end] { puts $f $arg }
close $f
'@
[IO.File]::WriteAllText($fixture, $tcl, (New-Object Text.UTF8Encoding($false)))
$result = Run-Launcher -Answers @('3', $dataDir, '', (Join-Path $root 'missing.tcl'), $fixture,
    $resultFile, 'hello world', '中文参数', '[error INJECTED]; $env(PATH)', '-flag', '""', '')
if ($result.Code -ne 0 -or -not (Test-Path -LiteralPath $resultFile)) {
    throw "FAIL: 实际批处理执行失败。$($result.Text)"
}
$lines = [IO.File]::ReadAllLines($resultFile, [Text.Encoding]::UTF8)
if ($lines[0].Replace('/', '\') -ne $dataDir -or $lines[1] -ne '6' -or
    $lines[2] -ne 'hello world' -or $lines[3] -ne '中文参数' -or
    $lines[4] -ne '[error INJECTED]; $env(PATH)' -or $lines[5] -ne '-flag' -or $lines[6] -ne '') {
    throw 'FAIL: 工作目录、中文路径或脚本参数被改变。'
}

# A Tcl error must be visible to terminal callers as a nonzero exit code.
$failure = Join-Path $root 'fail.tcl'
[IO.File]::WriteAllText($failure, 'error "EXPECTED_TEST_FAILURE"')
$result = Run-Launcher -Answers @('3', $root, '', $failure, '')
if ($result.Code -eq 0 -or $result.Text -notmatch 'EXPECTED_TEST_FAILURE') {
    throw 'FAIL: Tcl 执行失败没有正确返回错误。'
}
Write-Host 'PASS: 中文交互、模式选择、取消、路径校验、真实 Vivado 批处理、参数传递及错误退出。'
