`timescale 1ns / 1ps

`include "FaultAnalyzerTbDefines.vh"

module FaultAnalyzer_tb;

  reg tb_clk;
  reg tb_rst;
  reg [5:0] tb_sw;
  reg tb_btnc;
  reg tb_btnu;
  reg tb_jtag_tdo;
  reg tb_uart_rxd;
  wire tb_jtag_tck;
  wire tb_jtag_tms;
  wire tb_jtag_tdi;
  wire [15:0] tb_led;
  wire [6:0] tb_seg;
  wire [7:0] tb_an;
  wire tb_dp;
  wire tb_uart_txd;
  wire [3:0] tb_vga_red;
  wire [3:0] tb_vga_green;
  wire [3:0] tb_vga_blue;
  wire tb_vga_hs;
  wire tb_vga_vs;
  reg [15:0] tb_binary_in;
  wire [15:0] tb_decimal_out;
  reg tb_sseg_reset;
  reg [3:0] tb_sseg_val;
  reg [7:0] tb_sseg_anodes;
  wire [6:0] tb_sseg_seg;
  reg [15:0] tb_timemux_vals;
  wire [3:0] tb_timemux_seg;
  wire [3:0] tb_timemux_anodes;
  reg [3:0] tb_uart_char_index_force;
  reg [63:0] tb_status_event_word;
  integer tb_fail_count;

  TopModule dut (
      .clk_i(tb_clk),
      .sw_start_scan_i(tb_sw[0]),
      .sw_boundary_a_i(tb_sw[1]),
      .sw_boundary_b_i(tb_sw[2]),
      .sw_boundary_c_i(tb_sw[3]),
      .sw_boundary_d_i(tb_sw[4]),
      .sw_fifo_read_i(tb_sw[5]),
      .btnc_i(tb_btnc),
      .btnu_i(tb_btnu),
      .btnd_i(tb_rst),
      .jtag_tdo_i(tb_jtag_tdo),
      .jtag_tck_o(tb_jtag_tck),
      .jtag_tms_o(tb_jtag_tms),
      .jtag_tdi_o(tb_jtag_tdi),
      .led_o(tb_led),
      .seg_o(tb_seg),
      .an_o(tb_an),
      .dp_o(tb_dp),
      .uart_txd_o(tb_uart_txd),
      .uart_rxd_i(tb_uart_rxd),
      .vga_red_o(tb_vga_red),
      .vga_green_o(tb_vga_green),
      .vga_blue_o(tb_vga_blue),
      .vga_hs_o(tb_vga_hs),
      .vga_vs_o(tb_vga_vs)
  );

  BinaryDecimalConv u_tb_binary_decimal_conv (
      .binary_in  (tb_binary_in),
      .decimal_out(tb_decimal_out)
  );

  SevenSegDecoder u_tb_seven_seg_decoder (
      .reset(tb_sseg_reset),
      .val(tb_sseg_val),
      .anodes(tb_sseg_anodes),
      .seg(tb_sseg_seg)
  );

  TimeMux #(
      .NUM_DIGITS(4),
      .DIGIT_WIDTH(4),
      .REFRESH_LSB(0),
      .REFRESH_WIDTH(4),
      .DIGIT_SELECT_WIDTH(2)
  ) u_tb_timemux (
      .clk(tb_clk),
      .reset(tb_rst),
      .vals(tb_timemux_vals),
      .seg(tb_timemux_seg),
      .anodes(tb_timemux_anodes)
  );

  initial begin
    tb_clk = 1'b0;
  end

  always #(`TB_CLK_PERIOD_NS / 2) begin
    tb_clk = ~tb_clk;
  end

  task automatic tb_wait_cycles;
    input integer cycles;
    integer i;
    begin
      for (i = 0; i < cycles; i = i + 1) begin
        @(posedge tb_clk);
      end
    end
  endtask

  task automatic tb_apply_reset;
    begin
      tb_rst = 1'b1;
      tb_wait_cycles(`TB_RESET_CYCLES);
      tb_rst = 1'b0;
      tb_wait_cycles(`TB_RESET_RELEASE_CYCLES);
    end
  endtask

  task automatic tb_expect_equal32;
    input [31:0] actual;
    input [31:0] expected;
    input [1023:0] label;
    begin
      if (actual !== expected) begin
        tb_fail_count = tb_fail_count + 1;
        $display("FAIL: %0s actual=0x%08h expected=0x%08h", label, actual, expected);
      end else begin
        $display("PASS: %0s value=0x%08h", label, actual);
      end
    end
  endtask

  `include "TopModule_tb.vh"
  `include "JTAG_tb.vh"
  `include "StatusReg_tb.vh"
  `include "fifo_event_buffer_tb.vh"
  `include "LedStatus_tb.vh"
  `include "UartTx_tb.vh"
  `include "UartRx_tb.vh"
  `include "VGA_tb.vh"
  `include "BinaryDecimalConv_tb.vh"
  `include "SevenSegDecoder_tb.vh"
  `include "TimeMux_tb.vh"

  initial begin
    tb_rst = 1'b0;
    tb_sw = 6'd0;
    tb_btnc = 1'b0;
    tb_btnu = 1'b0;
    tb_jtag_tdo = 1'b0;
    tb_uart_rxd = 1'b1;
    tb_binary_in = 16'd0;
    tb_sseg_reset = 1'b0;
    tb_sseg_val = 4'd0;
    tb_sseg_anodes = 8'hFF;
    tb_timemux_vals = 16'd0;
    tb_uart_char_index_force = 4'd0;
    tb_status_event_word = 64'd0;
    tb_fail_count = 0;

    tb_test_topmodule();
    tb_test_jtag();
    tb_test_statusreg();
    tb_test_fifo_event_buffer();
    tb_test_ledstatus();
    tb_test_uarttx();
    tb_test_uartrx();
    tb_test_vga();
    tb_test_binarydecimalconv();
    tb_test_sevensegdecoder();
    tb_test_timemux();

    if (tb_fail_count == 0) begin
      $display("FAULT_ANALYZER_TB PASS");
    end else begin
      $display("FAULT_ANALYZER_TB FAIL count=%0d", tb_fail_count);
    end

    $finish;
  end

endmodule
