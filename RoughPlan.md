# FaultAnalyzer Technical Implementation Plan

## Project Goal

FaultAnalyzer is a Vivado project for the Digilent Nexys A7-100T that uses the
Nexys FPGA as an external JTAG master for a Gowin KIWI 1P5QN48XF target board.
The project scope is a safe diagnostic path: reset the target TAP, shift the
Gowin Read ID instruction, capture the 32-bit IDCODE, record one 64-bit event
in the generated FIFO IP, and report the result through status logic, LEDs,
UART, and VGA.

This project does not implement target bitstream loading, embedded Flash
programming, or BSDL-driven pin interconnect tests. It uses the IEEE 1149.1
TAP and boundary-scan architecture for a meaningful, non-destructive IDCODE
scan that exercises TCK, TMS, TDI, TDO, IR shifting, DR shifting, and result
checking.

## Validated Hardware Facts

| Fact | Project Use | Source |
| --- | --- | --- |
| Nexys A7-100T uses the `XC7A100T-1CSG324C` FPGA and has a 100 MHz board clock, switches, LEDs, UART, VGA, Pmod headers, and an eight-digit seven-segment display. | Defines the top-level board target and available I/O. | Digilent Nexys A7 Reference Manual |
| Nexys A7 Pmod JA pins JA1-JA4 map to FPGA pins `C17`, `D18`, `E18`, and `G17` with `LVCMOS33`. | External JTAG uses JA1-JA4 for `TCK`, `TMS`, `TDI`, and `TDO`. | Digilent Nexys-A7-100T Master XDC |
| KIWI 1P5QN48XF uses a Gowin `GW1N-UV1P5QN48XF` device and includes onboard USB-JTAG plus support for external FPGA programming through a DIP switch. | Confirms the target board and the need to avoid fighting the onboard debugger. | Gowin KIWI 1P5 devkit page and OneKiwi KIWI 1P5 product page |
| Gowin JTAG configuration mode conforms to IEEE 1532 and IEEE 1149.1 boundary-scan standards. | Justifies using a JTAG TAP diagnostic sequence. | Gowin UG290 |
| Gowin `GW1N-1P5/1P5B/1P5C` devices report IDCODE `32'h0120_681B`; the Read ID instruction is `8'h11`; IR length is 8 bits for GW1N series. | Defines the expected IDCODE and opcode constants. | Gowin UG290 |
| Gowin JTAG reset requires TMS high for at least 5 TCK cycles; after writing an instruction, Run-Test/Idle must be held for at least 3 TCK cycles; IR data is shifted LSB-first. | Defines the required JTAG engine sequencing. | Gowin UG290 |
| Native FIFO interfaces provide `clk`, reset, `din`, `wr_en`, `rd_en`, `dout`, `full`, `empty`, optional `almost_full`, `valid`, and `underflow` style status signals. | Matches the generated FIFO event buffer interface. | AMD FIFO Generator documentation |

## Vivado Project Structure

The project keeps the simplified Vivado-created layout:

```text
FaultAnalyzer.xpr
RoughPlan.md
FaultAnalyzer.srcs/
  sources_1/
    new/
      TopModule.v
      JTAG.v
      StatusReg.v
      UartTx.v
      VGA.v
      LedStatus.v
    ip/
      fifo_event_buffer/
        fifo_event_buffer.xci
  sim_1/
    new/
      FaultAnalyzer_tb.v
      FaultAnalyzerTbDefines.vh
      TopModule_tb.vh
      JTAG_tb.vh
      StatusReg_tb.vh
      fifo_event_buffer_tb.vh
      LedStatus_tb.vh
      UartTx_tb.vh
      VGA_tb.vh
  constrs_1/
    new/
      FaultAnalyzer.xdc
```

No additional source tree is required. The generated `fifo_event_buffer` IP is
used directly by the top-level design.

## Module Responsibilities

| Module or IP | Responsibility |
| --- | --- |
| `TopModule.v` | Structural top level. Owns board I/O, instantiates project modules, directly instantiates `fifo_event_buffer`, and wires status paths. |
| `JTAG.v` | Generates TCK, controls the TAP FSM, shifts the `8'h11` Read ID instruction, captures the 32-bit IDCODE, compares it, and emits a 64-bit event word. |
| `StatusReg.v` | Stores the latest event fields, scan-done state, match/mismatch state, FIFO state, and local error flags. |
| `UartTx.v` | Sends a compact UART diagnostic report from status fields at 115200 baud. |
| `VGA.v` | Generates VGA timing and displays scan status, IDCODE, pass/fail, and FIFO state. |
| `LedStatus.v` | Maps scan status, IDCODE match, FIFO status, JTAG state, and live JTAG pins to LEDs. |
| `fifo_event_buffer` | Generated AMD FIFO Generator IP used directly as the 64-bit scan event queue. |

## JTAG Operation

The required diagnostic flow is:

1. Drive TMS high for at least 5 TCK cycles to enter Test-Logic-Reset.
2. Move to Run-Test/Idle.
3. Move through Select-DR-Scan and Select-IR-Scan into Shift-IR.
4. Shift `8'h11` LSB-first on TDI.
5. Assert TMS with the final IR bit to exit Shift-IR, update IR, and return to Run-Test/Idle.
6. Hold Run-Test/Idle for at least 3 TCK cycles.
7. Move to Shift-DR and clock 32 bits from TDO.
8. Assert TMS with the final DR bit to exit Shift-DR, update DR, and return to Run-Test/Idle.
9. Compare the captured value against `32'h0120_681B`.
10. Write one FIFO event and update status outputs.

Recommended hardware TCK is 2 MHz from the 100 MHz system clock. This is below
the Gowin JTAG timing limit and is slow enough for bring-up with external
wires. Simulation may use scaled timing as long as the same TAP sequence is
preserved.

## FIFO Event Buffer

The generated IP remains named `fifo_event_buffer` and is instantiated directly.
Its current `.xci` settings are:

| Parameter | Value |
| --- | --- |
| Interface | Native |
| Implementation | Common-clock block RAM FIFO |
| Read mode | Standard FIFO |
| Reset | Synchronous reset through `srst` |
| Write width | 64 bits |
| Read width | 64 bits |
| Write depth | 64 words |
| Read depth | 64 words |
| Enabled outputs | `full`, `almost_full`, `empty`, `valid`, `underflow` |
| Disabled options | `overflow`, data counts, ECC |

The IP port list to use is:

```verilog
fifo_event_buffer u_fifo (
  .clk(clk),
  .srst(rst),
  .din(event_word),
  .wr_en(event_wr_en),
  .rd_en(fifo_rd_en),
  .dout(fifo_dout),
  .full(fifo_full),
  .almost_full(fifo_almost_full),
  .empty(fifo_empty),
  .valid(fifo_valid),
  .underflow(fifo_underflow)
);
```

The FIFO event word is:

| Bits | Field |
| ---: | --- |
| 63:32 | Captured IDCODE |
| 31 | IDCODE match |
| 30 | TDO stuck-high error |
| 29 | TDO stuck-low error |
| 28 | JTAG timeout |
| 27:24 | Final JTAG state |
| 23:16 | Event type |
| 15:0 | Timestamp |

If overflow reporting is needed, implement it in project logic as
`event_wr_en && fifo_full`; do not connect an `overflow` output to the current
IP.

## Top-Level Wiring

Top-level board ports should be named to match the constraints:

| Signal | Nexys A7 FPGA Pin | Direction | Use |
| --- | --- | --- | --- |
| `CLK100MHZ` | E3 | Input | 100 MHz system clock |
| `jtag_tck` | C17, JA1 | Output | Nexys to Kiwi TCK |
| `jtag_tms` | D18, JA2 | Output | Nexys to Kiwi TMS |
| `jtag_tdi` | E18, JA3 | Output | Nexys to Kiwi TDI |
| `jtag_tdo` | G17, JA4 | Input | Kiwi to Nexys TDO |

All JA JTAG signals use `LVCMOS33`. Connect Nexys ground to Kiwi ground. Keep
the Kiwi board powered from its own input; the Nexys only drives the JTAG logic
signals.

Internal wiring should follow this flow:

```text
buttons/switches
  -> TopModule control wires
  -> JTAG
  -> event_word/event_wr_en
  -> fifo_event_buffer
  -> StatusReg
  -> LedStatus, UartTx, VGA
```

## Testbench Structure

`FaultAnalyzer_tb.v` is the only simulation top. It should:

- include `FaultAnalyzerTbDefines.vh`
- instantiate the DUT and any module-level DUTs needed for isolated tests
- generate `tb_clk`
- drive test reset
- define only shared helper tasks such as reset, wait, and compare helpers
- include one task header per module or IP
- invoke each module task from the main initial block

Each module/IP has one separate `.vh` file named as the module or IP name
followed by `_tb.vh`. Each file defines exactly one non-module task and
contains no testbench module declaration:

```verilog
`include "TopModule_tb.vh"         // tb_test_topmodule
`include "JTAG_tb.vh"              // tb_test_jtag
`include "StatusReg_tb.vh"         // tb_test_statusreg
`include "fifo_event_buffer_tb.vh" // tb_test_fifo_event_buffer
`include "LedStatus_tb.vh"         // tb_test_ledstatus
`include "UartTx_tb.vh"            // tb_test_uarttx
`include "VGA_tb.vh"               // tb_test_vga
```

The main testbench calls `tb_test_topmodule()`, `tb_test_jtag()`,
`tb_test_statusreg()`, `tb_test_fifo_event_buffer()`,
`tb_test_ledstatus()`, `tb_test_uarttx()`, and `tb_test_vga()` directly. It
should not contain module-specific stimulus beyond helper tasks and dispatch.

Required scenarios:

| Test Task | Minimum Scenario |
| --- | --- |
| `tb_test_topmodule` | Reset, idle outputs, direct module connectivity smoke check. |
| `tb_test_jtag` | Good IDCODE scan, wrong IDCODE scan, stuck-low TDO, stuck-high TDO, timeout. |
| `tb_test_statusreg` | Event capture, match/mismatch flag decode, local overflow flag decode. |
| `tb_test_fifo_event_buffer` | Reset empty, write one event, read one event, underflow attempt. |
| `tb_test_ledstatus` | LED mapping for scan done, pass/fail, FIFO status, JTAG pin monitor. |
| `tb_test_uarttx` | 115200 baud bit timing and one diagnostic message frame. |
| `tb_test_vga` | 640x480 sync timing and status field changes. |

## Implementation Parameters

| Name | Value | Purpose |
| --- | --- | --- |
| `CLK_FREQ_HZ` | `100_000_000` | Nexys A7 board clock |
| `JTAG_TCK_HZ` | `2_000_000` | Default external JTAG clock target |
| `JTAG_TCK_DIVIDER` | `25` | Half-period divider for 2 MHz TCK from 100 MHz |
| `EXPECTED_GOWIN_IDCODE` | `32'h0120_681B` | Expected target IDCODE |
| `JTAG_IDCODE_OPCODE` | `8'h11` | Gowin Read ID instruction |
| `JTAG_IR_BITS` | `8` | Gowin GW1N instruction register length |
| `JTAG_IDCODE_BITS` | `32` | IDCODE data register length |
| `FIFO_EVENT_WIDTH` | `64` | FIFO event word width |
| `FIFO_EVENT_DEPTH` | `64` | FIFO entry count, not total bits |
| `UART_BAUD` | `115200` | UART diagnostic output baud |
| `VGA_H_ACTIVE` | `640` | VGA active horizontal pixels |
| `VGA_V_ACTIVE` | `480` | VGA active vertical lines |
| `TB_CLK_PERIOD_NS` | `10` | Testbench 100 MHz clock period |
| `TB_TIMEOUT_CYCLES` | `10000` | Default simulation timeout |

## Validation Sources

| Source | URL | Facts Used |
| --- | --- | --- |
| Digilent Nexys A7 Reference Manual | https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf | Nexys A7-100T device, 100 MHz clock, user I/O, VGA, UART, Pmod hardware, seven-segment behavior. |
| Digilent Nexys-A7-100T Master XDC | https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc | `CLK100MHZ` pin E3 and Pmod JA pin/package mappings with `LVCMOS33`. |
| Gowin KIWI 1P5 devkit page | https://www.gowinsemi.com/en/support/devkits_detail/71/ | KIWI 1P5QN48XF target, `GW1N-UV1P5QN48XF`, onboard USB-JTAG, onboard USB-UART, external programming DIP switch support. |
| OneKiwi KIWI 1P5 product page | https://onekiwi.com.vn/products/kiwi-1p5-fpga-board/ | KIWI 1P5 board features, 1,584 LUT target, onboard debugger, USB-UART, external FPGA programming support. |
| Gowin UG290 Programming and Configuration Guide | https://cdn.gowinsemi.com.cn/UG290E.pdf | JTAG conformance, timing limits, TAP reset, IR/DR scan behavior, 8-bit IR, Read ID opcode `0x11`, expected GW1N-1P5 IDCODE `32'h0120_681B`. |
| AMD FIFO Generator native interface documentation | https://docs.amd.com/r/en-US/pg327-emb-fifo-gen/Native-FIFO-Interface-Signals | Native FIFO signal meanings for `clk`, reset, `din`, `wr_en`, `rd_en`, `dout`, `full`, `empty`, `almost_full`, `valid`, and `underflow`. |
