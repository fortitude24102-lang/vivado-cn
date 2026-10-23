# Vivado 中文工程与上板助手

面向 Windows 和 Vivado 2019.2 的中文交互脚本：选择 FPGA 器件、创建 RTL 工程、添加设计源码和 XDC、执行综合与实现并生成 bit，再按需连接开发板下载和调试。

## 运行

1. 将仓库放到英文目录，例如 `E:\VivadoTerminal`。
2. 本机默认 Vivado 路径为 `D:\visit\Vivado\2019.2\bin\vivado.bat`；安装位置不同时，修改 `launcher.ps1` 开头的 `$vivado`。
3. 在 PowerShell 或 CMD 执行：

```powershell
E:\VivadoTerminal\vivado-cn.cmd
```

脚本使用 Windows 自带 PowerShell，无需安装运行依赖。通过完整路径或当前目录下的 `./vivado-cn.cmd` 启动即可；克隆仓库不会自动修改 PATH。

## 功能

- 中文提示填写完整器件型号、工程目录、顶层模块、源码和 XDC 路径。
- 查询本机安装的器件；支持多个 RTL 文件或递归搜索设计目录。
- 可选择仅建工程、完成综合，或运行到 bit 生成并导出报告。
- 图形硬件管理器，以及列出 JTAG 目标和器件后输入 `PROGRAM` 确认下载。
- 保留 Windows 控制台原生输入编码，兼容交互输入与 UTF-8 管道输入。
- 保留原来的 GUI、Tcl 控制台及自定义 Tcl 启动方式。

普通 RTL 工程可直接使用；Block Design、定制 IP 仓库和复杂库映射，可在菜单中选择已有 Tcl 或打开工程配置。硬件下载为 FPGA 的 JTAG 易失配置，不包含外部 Flash 固化。ILA 调试需要设计已有调试核及匹配的 `.ltx`。

详细参数、输出路径及操作示例见 [使用说明](使用说明.md)。

## 文件

| 文件 | 用途 |
| --- | --- |
| `vivado-cn.cmd` | Windows 终端入口 |
| `launcher.ps1` | 输入辅助、安装路径及原有启动功能 |
| `workflow.ps1` | 中文工程与硬件操作向导 |
| `flow.tcl` | Vivado 工程、综合、实现和硬件操作 |
| `example.tcl` | 自定义 Tcl 参数传递示例 |

新工程放在 `projects/`，运行日志和测试输出放在 `runs/`；这些生成文件不提交到版本控制。

## 验证

在仓库目录运行，需安装 Vivado；完整构建测试另需 Python 3：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test-vivado-cn.ps1
python.exe -X utf8 .\test-workflow.py
```

完整构建测试使用本机已安装的 `xc7a35tcpg236-1`，验证 RTL 到真实 bit 的流程和报告生成。该型号仅用于测试，不代表实际开发板。

离线验证实际终端的确认输入：

```powershell
& 'D:\visit\Vivado\2019.2\bin\vivado.bat' -mode tcl -source .\test-hardware-input.tcl -notrace -tclargs confirm-only
```

看到确认提示后输入 `PROGRAM`，预期显示 `PASS`。此测试在独立进程中模拟硬件 API，不会连接或烧录真实开发板；不要将测试脚本载入正在使用的硬件管理器会话。
