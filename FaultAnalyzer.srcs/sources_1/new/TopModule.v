`timescale 1ns / 1ps

module TopModule (
    input wire clk_i,
    input wire [15:0] sw_i,

    input wire btnc_i,
    input wire btnu_i,
    input wire btnd_i,
    input wire btnl_i,
    input wire btnr_i,

    input wire jtag_tdo_i,
    output wire jtag_tck_o,
    output wire jtag_tms_o,
    output wire jtag_tdi_o,
    output wire [15:0] led_o,

    output wire [6:0] seg_o,
    output wire [7:0] an_o,
    output wire dp_o,

    output wire uart_txd_o,
    input wire uart_rxd_i,

    output wire [3:0] vga_red_o,
    output wire [3:0] vga_green_o,
    output wire [3:0] vga_blue_o,
    output wire vga_hs_o,
    output wire vga_vs_o
);

    localparam integer CLK_FREQ_HZ = 100_000_000;
    localparam integer UART_BAUD = 115200;
    localparam integer JTAG_TCK_HZ = 2_000_000;
    localparam [31:0] EXPECTED_GOWIN_IDCODE = 32'h0120_681B;
    localparam [7:0] JtagIdcodeOpcode = 8'h11;

    wire rst;
    wire start_scan;
    wire jtag_busy;
    wire jtag_done;
    wire jtag_match;
    wire jtag_tdo_stuck_high;
    wire jtag_tdo_stuck_low;
    wire jtag_timeout;
    wire [3:0] jtag_state;
    wire [31:0] jtag_idcode;
    wire [63:0] jtag_event_word;
    wire jtag_event_valid;

    wire [63:0] fifo_dout;
    wire fifo_full;
    wire fifo_almost_full;
    wire fifo_empty;
    wire fifo_valid;
    wire fifo_underflow;
    wire fifo_rd_en;
    wire fifo_wr_en;
    wire fifo_overflow_attempt;
    wire [31:0] status_idcode;

    wire status_match;
    wire status_scan_done;
    wire status_tdo_stuck_high;
    wire status_tdo_stuck_low;
    wire status_timeout;
    wire [3:0] status_jtag_state;
    wire [7:0] status_event_type;
    wire [15:0] status_timestamp;

    wire status_fifo_underflow_latched;
    wire status_fifo_overflow_latched;

    wire [15:0] status_event_count;
    wire [15:0] status_led_bus;

    wire uart_busy;
    wire uart_done;
    wire uart_rx_valid;

    wire [7:0] uart_rx_byte;
    wire [3:0] seg_nibble;
    wire [31:0] seven_seg_value;

    assign rst = btnd_i;
    assign start_scan = btnc_i | sw_i[0];
    assign fifo_wr_en = jtag_event_valid && !fifo_full;
    assign fifo_overflow_attempt = jtag_event_valid && fifo_full;
    assign fifo_rd_en = sw_i[14] && !fifo_empty;
    assign seven_seg_value = status_scan_done ? status_idcode : EXPECTED_GOWIN_IDCODE;
    assign dp_o = 1'b1;

    JTAG #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TCK_HZ(JTAG_TCK_HZ),
        .EXPECTED_IDCODE(EXPECTED_GOWIN_IDCODE),
        .IDCODE_OPCODE(JtagIdcodeOpcode)
    ) u_jtag (
        .clk(clk_i),
        .rst(rst),
        .start(start_scan),
        .compare_enable(1'b1),
        .tdo(jtag_tdo_i),
        .tck(jtag_tck_o),
        .tms(jtag_tms_o),
        .tdi(jtag_tdi_o),
        .busy(jtag_busy),
        .done(jtag_done),
        .captured_idcode(jtag_idcode),
        .id_match(jtag_match),
        .tdo_stuck_high(jtag_tdo_stuck_high),
        .tdo_stuck_low(jtag_tdo_stuck_low),
        .timeout_error(jtag_timeout),
        .jtag_state(jtag_state),
        .event_word(jtag_event_word),
        .event_valid(jtag_event_valid)
    );

    fifo_event_buffer u_fifo (
        .clk(clk_i),
        .srst(rst),
        .din(jtag_event_word),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .dout(fifo_dout),
        .full(fifo_full),
        .almost_full(fifo_almost_full),
        .empty(fifo_empty),
        .valid(fifo_valid),
        .underflow(fifo_underflow)
    );

    StatusReg u_status (
        .clk(clk_i),
        .rst(rst),

        .event_valid(jtag_event_valid),
        .event_word(jtag_event_word),

        .scan_busy(jtag_busy),

        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_almost_full(fifo_almost_full),
        .fifo_valid(fifo_valid),
        .fifo_underflow(fifo_underflow),
        .fifo_overflow_attempt(fifo_overflow_attempt),

        .jtag_tck(jtag_tck_o),
        .jtag_tms(jtag_tms_o),
        .jtag_tdi(jtag_tdi_o),
        .jtag_tdo(jtag_tdo_i),

        .latest_idcode(status_idcode),
        .id_match(status_match),
        .scan_done(status_scan_done),
        .tdo_stuck_high(status_tdo_stuck_high),
        .tdo_stuck_low(status_tdo_stuck_low),
        .timeout_error(status_timeout),
        .jtag_state(status_jtag_state),
        .event_type(status_event_type),
        .timestamp(status_timestamp),
        .fifo_underflow_latched(status_fifo_underflow_latched),
        .fifo_overflow_latched(status_fifo_overflow_latched),
        .event_count(status_event_count),
        .status_led_bus(status_led_bus)
    );

    LedStatus u_led_status (
        .scan_done(status_scan_done),
        .id_match(status_match),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_underflow(status_fifo_underflow_latched),
        .fifo_overflow(status_fifo_overflow_latched),
        .uart_busy(uart_busy),
        .jtag_state(status_jtag_state),
        .jtag_tck(jtag_tck_o),
        .jtag_tms(jtag_tms_o),
        .jtag_tdi(jtag_tdi_o),
        .jtag_tdo(jtag_tdo_i),
        .led(led_o)
    );

  TimeMux #(
      .NUM_DIGITS(8),
      .DIGIT_WIDTH(4),
      .REFRESH_LSB(13),
      .REFRESH_WIDTH(20),
      .DIGIT_SELECT_WIDTH(3)
  ) u_sseg_mux (
      .clk(clk_i),
      .reset(rst),
      .vals(seven_seg_value),
      .seg(seg_nibble),
      .anodes(an_o)
  );

  SevenSegDecoder u_sseg_decoder (
      .reset(rst),
      .val(seg_nibble),
      .anodes(an_o),
      .seg(seg_o)
  );

  uart_tx #(
      .CLKS_PER_BIT  (CLK_FREQ_HZ/UART_BAUD) 
  ) u_uart_tx (
      .i_Clock(clk_i),
      .rst(rst),
      .send(jtag_event_valid),
      .idcode(jtag_idcode),
      .id_match(jtag_match),
      .tx(uart_txd_o),
      .busy(uart_busy),
      .done(uart_done)
  );

  uart_rx #(
      .CLK_FREQ_HZ(CLK_FREQ_HZ),
      .BAUD_RATE  (UART_BAUD)
  ) u_uart_rx (
      .clk(clk_i),
      .rst(rst),
      .rx(uart_rxd_i),
      .data_valid(uart_rx_valid),
      .data_byte(uart_rx_byte)
  );

  VGA u_vga (
      .clk(clk_i),
      .rst(rst),
      .idcode(status_idcode),
      .id_match(status_match),
      .scan_done(status_scan_done),
      .scan_busy(jtag_busy),
      .fifo_empty(fifo_empty),
      .fifo_full(fifo_full),
      .fifo_underflow(status_fifo_underflow_latched),
      .fifo_overflow(status_fifo_overflow_latched),
      .jtag_state(status_jtag_state),
      .vga_red(vga_red_o),
      .vga_green(vga_green_o),
      .vga_blue(vga_blue_o),
      .vga_hs(vga_hs_o),
      .vga_vs(vga_vs_o)
  );

endmodule
