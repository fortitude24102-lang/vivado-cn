# Vivado 中文工程与上板助手

在 Windows 终端里，通过中文提示完成下面的流程：

**选择 FPGA 器件 → 创建工程 → 添加设计代码和 XDC → 设置顶层 → 综合 → 实现 → 生成 bit → 连接开发板 → 下载与调试。**

运行助手只需要 Windows 自带 PowerShell 和已安装的 Vivado。已在 **Vivado 2019.2** 上验证 RTL 到 bit 的构建，以及终端输入和下载确认逻辑；其他版本需要自行验证。Vivado 自身的日志保留原有语言。

## 目录

- [1. 安装与首次启动](#installation)
- [2. 菜单和参数怎么填](#parameters)
- [3. 从零准备一个示例设计](#example-design)
- [4. 新建工程并生成 bit](#build)
- [5. 连接开发板、下载和调试](#hardware)
- [6. 已有 bit，直接下载](#existing-bit)
- [7. GUI、Tcl 和自定义脚本](#raw-launcher)
- [8. 预览、日志和输出文件](#outputs)
- [9. 常见问题](#troubleshooting)
- [10. 验证脚本与文件说明](#verification)

> 下文终端示例中的 `[回车]` 表示直接按 Enter，不要输入这几个字。示例已省略长日志；路径、时间、器件列表和 JTAG 编号会随本机环境变化。构建输出参考本地实际测试，硬件下载成功段为流程示意，不是对任意开发板的实测记录。

<a id="installation"></a>

## 1. 安装与首次启动

### 1.1 准备环境

| 项目 | 要求 |
| --- | --- |
| 系统 | Windows，可运行 Windows PowerShell 5.1 |
| Vivado | 本项目已验证 2019.2；安装需要使用的 FPGA 器件支持包，并具有相应工具许可 |
| 设计输入 | RTL 设计文件、匹配开发板和顶层端口的 XDC 约束 |
| 下载到开发板 | 开发板供电、USB/JTAG 连接及相应线缆驱动 |
| Python | 仅完整构建回归测试需要 Python 3，日常运行助手不需要 |

### 1.2 获取项目

在 PowerShell 中执行，目标目录应当尚不存在：

```powershell
git clone https://github.com/fortitude24102-lang/vivado-cn.git E:\VivadoTerminal
cd E:\VivadoTerminal
```

如果已克隆过仓库，直接进入已有目录即可。没有 Git 时也可以从 GitHub 下载 ZIP 后解压到英文目录。

### 1.3 配置 Vivado 安装路径

打开 `launcher.ps1`，找到这一行，并改成自己电脑上真实存在的路径：

```powershell
$vivado = 'D:\visit\Vivado\2019.2\bin\vivado.bat'
```

可以先在 PowerShell 中确认该文件存在：

```powershell
Test-Path 'D:\visit\Vivado\2019.2\bin\vivado.bat'
```

预期输出：

```text
True
```

### 1.4 启动

在仓库目录中运行：

```powershell
.\vivado-cn.cmd
```

也可以在任意位置使用完整路径：

```powershell
E:\VivadoTerminal\vivado-cn.cmd
```

克隆仓库不会自动修改 PATH。如果希望在任意目录输入 `vivado-cn`，将仓库目录加入自己的用户 PATH，然后重新启动终端及其所属程序。没有配置 PATH 时，使用完整路径即可。

<a id="parameters"></a>

## 2. 菜单和参数怎么填

启动后的菜单：

```text
===== Vivado 2019.2 中文工程与上板助手 =====
输入 Q 可取消。器件型号和 XDC 约束请按实际开发板填写。
1. 选择器件、新建工程、添加源码和 XDC、综合/实现/生成 bit（默认）
2. 打开硬件管理器或烧录已有 bit
3. 原来的 GUI / Tcl 命令行 / 自定义 Tcl 启动助手
请选择 [1/2/3，回车选 1]：
```

第一次从源码构建选 `1`；已经有 bit 文件、只想下载时选 `2`。

### 新建工程的参数表

| 提示 | 应填内容 | 示例或默认值 |
| --- | --- | --- |
| FPGA 完整器件型号 | 实际 FPGA 的完整型号，包括封装和速度等级 | `xc7a35tcpg236-1`，仅为示例 |
| 工程名称 | 英文字母开头，只使用字母、数字、下划线 | `demo` |
| 新工程完整目录 | 尚不存在的新文件夹，不能填写 `.xpr` 文件 | `E:\FPGA\demo_build`；默认是仓库内 `projects\工程名` |
| 顶层模块/实体名称 | RTL 中的模块名或实体名，不带文件后缀 | `top` |
| 设计源码 | 每行一个文件或文件夹；目录会递归查找 | `E:\FPGA\demo_source\rtl` |
| XDC 约束 | 每行一个 `.xdc` 文件或包含它的文件夹 | `E:\FPGA\demo_source\constraints\pins.xdc` |
| 并行任务数 | 同时运行的任务数 | 回车默认 `4`，范围 `1–64` |
| 执行阶段 | `1` 仅建工程；`2` 完成综合；`3` 生成 bit | 回车默认 `3` |

输入源码和 XDC 时，**每个路径输入后按一次回车，全部添加完成后再按一次空行回车结束**。这两处至少各需要一个有效文件。

设计源码支持 `.v`、`.sv`、`.vh`、`.svh`、`.vhd`、`.vhdl` 以及辅助数据文件 `.mem`、`.hex`、`.mif`，其中至少需要一个实际 HDL 设计文件。不要把 testbench 或旧工程的生成文件目录混入设计源码。

不知道本机安装了哪些型号时，在型号提示处输入 `?xc7a35*` 一类查询，工具会显示最多 60 个匹配结果，随后继续要求输入完整型号。硬件管理器中的 `xcku040_0` 等名字是设备对象名，不能代替建工程所需的完整型号。

文件路径可以粘贴带双引号的完整路径。建议工程、源码和约束使用英文目录；相对路径按当前终端目录解析，初次使用推荐全部填写完整路径。顶层名、器件型号和实际文件内容仍须自行保持一致。

<a id="example-design"></a>

## 3. 从零准备一个示例设计

本节示例使用 **Basys 3 对应的 `xc7a35tcpg236-1`**，端口为时钟 `clk`、复位按钮 `rst` 和 LED 输出 `led`。可在没有连接开发板时完成工程构建和 bit 生成。

**其他开发板需要替换器件型号和 XDC，不能直接套用本节引脚。** 下列时钟、按钮和 LED 引脚对应 [Digilent 官方 Basys 3 XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc)，上板前还应核对自己的板卡版本。

先准备以下目录和两个文件；此时不要创建后文用来存放新工程的 `demo_build` 目录：

```text
E:\FPGA\demo_source\
├── rtl\
│   └── top.v
└── constraints\
    └── pins.xdc
```

### 3.1 设计文件：`rtl\top.v`

计数器在时钟上升沿累加，复位时清零，输出一位计数信号到 LED：

```verilog
module top (
    input  wire clk,
    input  wire rst,
    output wire led
);

reg [23:0] counter = 0;

always @(posedge clk) begin
    if (rst)
        counter <= 0;
    else
        counter <= counter + 1;
end

assign led = counter[23];

endmodule
```

顶层名称填 `top`，因为源码声明的是 `module top`，而不是因为文件名为 `top.v`。

### 3.2 约束文件：`constraints\pins.xdc`

```tcl
set_property PACKAGE_PIN W5 [get_ports clk]
set_property PACKAGE_PIN U18 [get_ports rst]
set_property PACKAGE_PIN U16 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports {clk rst led}]
create_clock -period 10.000 [get_ports clk]
```

这里分别指定封装引脚、电平标准和 10 ns 时钟周期。`get_ports` 中的名称必须与 `top` 的端口逐字匹配。更换开发板时，应使用对应板卡的引脚、电平和实际时钟约束。

<a id="build"></a>

## 4. 新建工程并生成 bit

### 4.1 按顺序输入

运行助手并按下表填写：

| 顺序 | 项目 | 本例输入 |
| --- | --- | --- |
| 1 | 主菜单 | `1` |
| 2 | 完整器件型号 | `xc7a35tcpg236-1` |
| 3 | 工程名称 | `demo` |
| 4 | 新工程目录 | `E:\FPGA\demo_build` |
| 5 | 顶层模块 | `top` |
| 6 | 第一个源码路径 | `E:\FPGA\demo_source\rtl`，回车后再空行回车结束 |
| 7 | 第一个 XDC 路径 | `E:\FPGA\demo_source\constraints\pins.xdc`，回车后再空行回车结束 |
| 8 | 并行任务数 | `4` 或直接回车 |
| 9 | 执行阶段 | `3` 或直接回车 |

多目录工程可以连续填写多个源码路径；头文件所在目录会加入 include 搜索路径。源码按原路径引用，修改原文件会影响工程，不会自动复制成一份独立源代码备份。

### 4.2 输入示例

为便于阅读，下面缩短了部分提示，具体措辞以终端显示为准：

```text
请选择 [1/2/3，回车选 1]：1
FPGA 完整器件型号：xc7a35tcpg236-1
工程名称：demo
新工程完整目录：E:\FPGA\demo_build
顶层模块/实体名称：top

设计源码 路径 [至少一项，空行结束]：E:\FPGA\demo_source\rtl
已收集 1 个文件。
设计源码 路径 [至少一项，空行结束]：[回车]

XDC 约束 路径 [至少一项，空行结束]：E:\FPGA\demo_source\constraints\pins.xdc
已收集 1 个文件。
XDC 约束 路径 [至少一项，空行结束]：[回车]

并行任务数 [1-64，回车用 4]：[回车]
执行到哪一步 [1 仅建工程 / 2 完成综合 / 3 生成 bit；回车选 3]：[回车]

新建工程：E:\FPGA\demo_build\demo.xpr
器件：xc7a35tcpg236-1；顶层：top；源码 1 个；XDC 1 个；执行阶段 3。
本次日志与启动记录：E:\VivadoTerminal\runs\flow-时间-编号
```

### 4.3 构建成功时的关键输出

```text
****** Vivado v2019.2 (64-bit)
...
步骤 1：创建工程、选择器件、添加设计文件和 XDC。
步骤 2：综合。
... Launched synth_1...
...
synth_design completed successfully
... synth_1 finished
步骤 3：实现并生成 bit。保留 Vivado 原有 DRC 检查。
... Launched impl_1...
...
INFO: [Vivado 12-1842] Bitgen Completed Successfully.
write_bitstream completed successfully
...
bit 已生成：E:/FPGA/demo_build/demo.runs/impl_1/top.bit
工程：E:/FPGA/demo_build/demo.xpr
bit 文件：E:/FPGA/demo_build/demo.runs/impl_1/top.bit
报告目录：E:\FPGA\demo_build\reports

下一步：0. 结束（默认）  1. 打开图形界面的硬件管理器  2. 终端连接并烧录 FPGA，随后打开调试界面
请选择 [0/1/2，回车选 0]：
```

没有连接开发板时，最后直接回车结束即可。阶段 `1` 不运行综合；阶段 `2` 完成综合并生成资源报告；只有阶段 `3` 会运行实现和 bit 生成。

bit 文件生成后还应查看时序和 DRC 报告。若输出“建立时间时序尚未收敛”，说明已经生成 bit，但需要继续修改设计或约束，不能仅凭文件存在判断设计满足时序。

<a id="hardware"></a>

## 5. 连接开发板、下载和调试

### 5.1 构建后直接下载

在“下一步”选择 `2`，依次输入：

| 提示 | 该怎么选 |
| --- | --- |
| bit 文件路径 | 刚生成的文件会显示出来，直接回车使用；也可填另一个现有 `.bit` |
| 调试 `.ltx` 路径 | 设计没有调试核时留空；检测到文件时回车使用，输入 `-` 可清空 |
| 硬件服务器地址 | 本机 USB/JTAG 通常回车使用 `localhost:3121` |
| 硬件目标 / FPGA 编号 | 多项时输入编号；仅一项时显示后自动选中 |
| 最终下载确认 | 核对器件和文件，输入大写 `PROGRAM` 并回车；直接回车取消 |

下载前先完成开发板供电和 USB/JTAG 连接。只填写服务器地址还不能替代物理连接及线缆驱动。

### 5.2 连接和确认的输出示例

下例中的 `DEMO_SERIAL` 是演示编号，请以实际检测结果为准：

```text
请选择 [0/1/2，回车选 0]：2
本次生成的 bit：E:/FPGA/demo_build/demo.runs/impl_1/top.bit
bit 文件路径 [回车使用本次生成的文件]：[回车]
调试 .ltx 路径 [回车使用检测到的文件；没有则留空，输入 - 清空]：[回车]
硬件服务器地址 [回车用 localhost:3121，本机 USB/JTAG 通常用默认值]：[回车]
...
检测到的硬件目标：
  1. localhost:3121/xilinx_tcf/Digilent/DEMO_SERIAL
INFO: [Labtoolstcl 44-466] Opening hw_target localhost:3121/xilinx_tcf/Digilent/DEMO_SERIAL
检测到的FPGA器件：
  1. xc7a35t_0
目标：localhost:3121/xilinx_tcf/Digilent/DEMO_SERIAL
器件：xc7a35t_0
bit：E:/FPGA/demo_build/demo.runs/impl_1/top.bit
调试探针：
核对以上信息，输入 PROGRAM 执行 FPGA 下载；回车取消：
PROGRAM
...
FPGA 下载完成，正在打开硬件调试界面。
```

下载成功后会打开图形界面，并保留 Vivado Tcl 控制台。完成操作后，可在 `Vivado%` 提示符输入 `exit` 退出。

取消时的输出：

```text
核对以上信息，输入 PROGRAM 执行 FPGA 下载；回车取消：
[回车]
已取消，未执行烧录。
```

本流程将 bit **通过 JTAG 下载到 FPGA 的易失配置，断电后会丢失**。外部 Flash 固化还涉及具体存储器型号和配置方式，当前助手不执行此步骤。

### 5.3 只打开图形硬件管理器

在“下一步”选择 `1`，然后在 Vivado 中使用 **Open Target → Auto Connect** 连接开发板，再用 **Program Device** 选择 bit 和可选的 ltx 文件。

### 5.4 ILA 调试需要什么

打开硬件管理器不会自动给 RTL 添加 ILA。设计中需要先包含调试核，并使用与当前 bit 匹配的 `.ltx`；本助手检测到实现后的调试核时会导出探针文件。没有调试核的 LED 等简单设计，不需要填写 ltx。

<a id="existing-bit"></a>

## 6. 已有 bit，直接下载

无需重新创建工程或重新编译：

1. 启动 `vivado-cn.cmd`，主菜单选择 `2`。
2. 在随后显示的“下一步”菜单选择 `2`。
3. 填写已经存在的 bit 完整路径，例如 `E:\FPGA\demo_build\demo.runs\impl_1\top.bit`。
4. 按需填写 ltx，服务器地址通常直接回车。
5. 核对实际设备，等确认提示出现后输入 `PROGRAM`。

这里的两个 `2` 分别是“进入硬件操作”和“执行连接下载”。如果只想打开 GUI，第二次选择 `1`。

<a id="raw-launcher"></a>

## 7. GUI、Tcl 和自定义脚本

主菜单选择 `3`，或者直接运行：

```powershell
E:\VivadoTerminal\vivado-cn.cmd -Raw
```

原启动助手的菜单为 `1` Tcl 命令行、`2` 图形界面、`3` 批处理。随后可填写工作目录、已有 `.xpr` 工程或 `.dcp` 检查点，以及可选的 Tcl 文件；批处理模式必须指定 Tcl。

### 7.1 打开已有工程

在原启动助手中选择图形界面，工程路径填现有的 `E:\FPGA\demo_build\demo.xpr`，Tcl 路径留空。对已有工程的修改和重新运行，可继续在 Vivado 中完成；主菜单 `1` 用于创建新目录中的新工程。

### 7.2 试运行附带的 Tcl 示例

进入原启动助手后依次填写：

| 项目 | 输入 |
| --- | --- |
| 原助手的运行模式 | `3`，即批处理 |
| 工作目录 | 回车使用默认的 `E:\VivadoTerminal\work` |
| 现有工程 | 留空 |
| Tcl 文件 | `E:\VivadoTerminal\example.tcl` |
| 第一个参数 | `xc7a35tcpg236-1` |
| 第二个参数 | `top` |
| 第三个参数 | `E:\FPGA\demo_source\rtl` |
| 结束参数输入 | 再按一次空行回车 |

关键输出示例：

```text
Vivado version: 2019.2
Working directory: E:/VivadoTerminal/work
Argument count: 3
Argument 1 = <xc7a35tcpg236-1>
Argument 2 = <top>
Argument 3 = <E:\FPGA\demo_source\rtl>
```

`example.tcl` 只显示参数，不创建工程或执行编译。自定义 Tcl 中参数由 `argv` 接收，`argc` 为数量；具体顺序由你的 Tcl 定义。每行传入一个参数，带空格的路径不用拆开，两个双引号 `""` 表示一个空参数。

原助手的工作目录决定 Tcl 中相对路径的起点，与主工程向导按当前终端目录读取输入路径的方式不同。

<a id="outputs"></a>

## 8. 预览、日志和输出文件

### 8.1 先预览参数

```powershell
E:\VivadoTerminal\vivado-cn.cmd -Preview
```

仍会显示中文提示并在 `runs` 中保存启动记录，但不会启动 Vivado、创建工程或连接硬件：

```text
本次日志与启动记录：E:\VivadoTerminal\runs\flow-时间-编号
预览结束，尚未启动 Vivado、创建工程或连接硬件。
```

### 8.2 结果在哪里

按前面的 `demo` 示例构建后：

| 文件 | 示例位置 |
| --- | --- |
| 工程 | `E:\FPGA\demo_build\demo.xpr` |
| bit | `E:\FPGA\demo_build\demo.runs\impl_1\top.bit` |
| 时序报告 | `E:\FPGA\demo_build\reports\timing_summary.rpt` |
| 资源报告 | `E:\FPGA\demo_build\reports\utilization.rpt` |
| DRC 报告 | `E:\FPGA\demo_build\reports\drc.rpt` |
| ltx，仅含调试核时 | `E:\FPGA\demo_build\top.ltx` |
| 综合运行日志 | `E:\FPGA\demo_build\demo.runs\synth_1\runme.log` |
| 实现运行日志 | `E:\FPGA\demo_build\demo.runs\impl_1\runme.log` |

助手每次调用的 `startup.tcl`、`vivado.log` 和 `vivado.jou` 在仓库的 `runs\flow-时间-编号\` 中。原启动助手使用 `runs\时间-编号\`。仅预览时没有 Vivado 运行日志。

默认的 `projects/`、`runs/` 和 `work/` 已被 Git 忽略，不会上传生成工程、bit 或运行记录。

<a id="troubleshooting"></a>

## 9. 常见问题

| 现象 | 检查和处理 |
| --- | --- |
| 提示找不到 Vivado | 检查 `launcher.ps1` 的 `$vivado` 是否指向实际的 `bin\vivado.bat` |
| 直接输入 `vivado-cn` 无法识别 | 使用完整路径，或将仓库目录加入用户 PATH 后重新启动终端 |
| 新工程目录已存在 | 换一个尚不存在的目录；如果需要打开旧工程，使用原启动助手的 GUI 模式 |
| 未找到唯一的已安装器件 | 核对完整型号，使用 `?` 查询；必要时在 Vivado 安装中补充该系列器件支持 |
| 一直重复要求源码或 XDC 路径 | 还没有收集到有效文件，或添加完后没有空行回车结束 |
| 顶层不存在、端口匹配失败 | 核对顶层模块/实体名称，及 XDC 中 `get_ports` 与 RTL 端口的拼写和大小写 |
| 生成 bit 时出现 UCIO / NSTD 等 DRC 错误 | 检查所需端口的引脚与电平标准是否完整；助手不会降低 DRC 等级强行生成 bit |
| 综合或实现失败 | 查看对应 `synth_1` / `impl_1` 的 `runme.log`，先处理最早出现的相关错误 |
| 没找到硬件目标或器件 | 检查供电、USB/JTAG、线缆驱动和服务器地址；关闭可能独占目标的其他会话后再试 |
| 输入 PROGRAM 却显示取消 | 确认使用最新脚本，等提示出现后输入大写 `PROGRAM`；旧版本曾错误修改控制台输入编码，当前已修复 |
| 下载后断电不保留 | 当前为 JTAG 易失配置；永久固化需另行配置实际板卡的 Flash 下载流程 |
| 没有 ILA 波形或探针不匹配 | 核对设计是否包含调试核，以及 ltx 是否与当前 bit 同一次构建匹配 |

失败会返回非零退出码。自动调用时可在 PowerShell 中检查 `$LASTEXITCODE`；取消操作按正常退出处理。

当前自动建工程流程面向普通 RTL。含 Block Design、定制 IP 仓库或复杂 VHDL 库映射时，使用已有工程/Tcl 入口继续配置；仿真 testbench 也应与设计源码分开管理。

<a id="verification"></a>

## 10. 验证脚本与文件说明

在仓库目录运行验证；这些测试不连接或烧录真实开发板。

### 10.1 启动与参数传递

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test-vivado-cn.ps1
```

预期结束输出：

```text
PASS: 中文交互、模式选择、取消、路径校验、真实 Vivado 批处理、参数传递及错误退出。
```

### 10.2 真实 RTL 到 bit 的构建

需要 Python 3，以及本机已安装的 `xc7a35tcpg236-1` 器件支持：

```powershell
python.exe -X utf8 .\test-workflow.py
```

测试会创建一个小型 RTL 设计，实际运行综合、实现和 bit 生成，并验证报告和已有工程目录保护。耗时取决于本机环境。

```text
PASS: workflow preview, invalid part, real RTL-to-bit build, reports, existing-project protection
Verified bitstream: E:\VivadoTerminal\runs\build-test-随机编号\project\cn_test.runs\impl_1\top.bit
```

### 10.3 真实终端里的 PROGRAM 确认

按本机 Vivado 路径调整下列命令：

```powershell
& 'D:\visit\Vivado\2019.2\bin\vivado.bat' -mode tcl -source .\test-hardware-input.tcl -notrace -tclargs confirm-only
```

这是在独立进程中模拟硬件 API 的输入回归测试。等到提示后手动输入 `PROGRAM`：

```text
核对以上信息，输入 PROGRAM 执行 FPGA 下载；回车取消：
PROGRAM
FPGA 下载完成，正在打开硬件调试界面。
PASS: offline hardware selection, no-target failure, cancellation and PROGRAM confirmation
```

本测试中的“下载完成”为模拟调用的输出，不代表真实板卡已下载，也不会打开实际调试 GUI。不要把测试脚本载入正在使用的硬件管理器会话。去掉 `-tclargs confirm-only` 时，完整测试依次输入 `invalid`、`2`、`q`、空行、`PROGRAM`。

### 10.4 仓库文件

| 文件 | 用途 |
| --- | --- |
| `vivado-cn.cmd` | Windows 终端入口 |
| `launcher.ps1` | Vivado 安装路径、输入辅助和原启动助手 |
| `workflow.ps1` | 中文工程与硬件操作向导 |
| `flow.tcl` | 工程创建、综合、实现及硬件操作 |
| `example.tcl` | 自定义 Tcl 参数传递示例 |
| `test-vivado-cn.ps1` | 启动与参数回归验证 |
| `test-workflow.py` | 真实构建回归验证 |
| `test-hardware-input.tcl` | 模拟硬件的终端输入验证 |
| [使用说明.md](使用说明.md) | 简版参数与操作参考 |
