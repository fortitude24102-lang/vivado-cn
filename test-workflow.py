"""Real Vivado integration check; standard library only. Never connects to hardware."""
import pathlib
import subprocess
import uuid

ROOT = pathlib.Path(__file__).resolve().parent
WORK = ROOT / "runs" / ("build-test-" + uuid.uuid4().hex)
WORK.mkdir(parents=True)
DESIGN = WORK / "rtl"
DESIGN.mkdir()
(DESIGN / "top.v").write_text('''module top(input wire clk, input wire rst, output wire led);
reg [23:0] counter = 0;
always @(posedge clk) begin
    if (rst) counter <= 0;
    else counter <= counter + 1;
end
assign led = counter[23];
endmodule
''', encoding="ascii")
(DESIGN / "pins.xdc").write_text('''set_property PACKAGE_PIN W5 [get_ports clk]
set_property PACKAGE_PIN U18 [get_ports rst]
set_property PACKAGE_PIN U16 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports {clk rst led}]
create_clock -period 10.000 [get_ports clk]
''', encoding="ascii")


def run(answers, preview=False):
    command = ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
               "-File", str(ROOT / "launcher.ps1")]
    if preview:
        command.append("-Preview")
    return subprocess.run(command, input="\n".join(answers) + "\n", encoding="utf-8",
                          errors="replace", capture_output=True, timeout=600)


def build_answers(project, part="xc7a35tcpg236-1"):
    return ["1", part, "cn_test", str(project), "top", str(DESIGN), "",
            str(DESIGN / "pins.xdc"), "", "2", "3", "0"]


# Catch the old launcher being presented instead of the requested project workflow.
preview = run(build_answers(WORK / "preview"), preview=True)
assert preview.returncode == 0 and "新建工程" in preview.stdout, preview.stdout + preview.stderr
assert not (WORK / "preview").exists(), "Preview unexpectedly created a project"

# Bad device selection must fail before creating or changing a project.
invalid = run(build_answers(WORK / "invalid", "xc_does_not_exist"))
assert invalid.returncode != 0 and not (WORK / "invalid").exists(), invalid.stdout

# Real synthesis, implementation, bit generation and reports, using a local installed part.
project = WORK / "project"
result = run(build_answers(project))
(WORK / "console.txt").write_text(result.stdout + result.stderr, encoding="utf-8")
assert result.returncode == 0, result.stdout[-12000:] + result.stderr
assert "步骤 1" in result.stdout and "bit 已生成" in result.stdout, "Vivado Chinese output was corrupted"
bit = project / "cn_test.runs" / "impl_1" / "top.bit"
assert bit.exists() and bit.stat().st_size > 1000, "No real bitstream was generated"
assert (project / "cn_test.xpr").exists(), "Missing project"
assert (project / "reports" / "timing_summary.rpt").exists(), "Missing timing report"
assert (project / "reports" / "utilization.rpt").exists(), "Missing utilization report"

# Existing projects must survive the new-project prompt without being overwritten.
marker = project / "keep.txt"
marker.write_text("keep", encoding="ascii")
retry = build_answers(project)
retry.insert(4, str(WORK / "retry"))
existing = run(retry, preview=True)
assert existing.returncode == 0 and marker.read_text() == "keep", existing.stdout
assert not (WORK / "retry").exists(), "Preview unexpectedly created a project"

print("PASS: workflow preview, invalid part, real RTL-to-bit build, reports, existing-project protection")
print("Verified bitstream: " + str(bit))
