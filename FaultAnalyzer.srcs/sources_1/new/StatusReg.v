`timescale 1ns / 1ps

module StatusReg (
    input wire clk,
    input wire rst,
    input wire event_valid,
    input wire [63:0] event_word,
    input wire scan_busy,
    input wire fifo_empty,
    input wire fifo_full,
    input wire fifo_almost_full,
    input wire fifo_valid,
    input wire fifo_underflow,
    input wire fifo_overflow_attempt,
    input wire jtag_tck,
    input wire jtag_tms,
    input wire jtag_tdi,
    input wire jtag_tdo,

    output reg [31:0] latest_idcode,
    output reg id_match,
    output reg scan_done,
    output reg tdo_stuck_high,
    output reg tdo_stuck_low,
    output reg timeout_error,
    output reg [3:0] jtag_state,
    output reg [7:0] event_type,
    output reg [15:0] timestamp,
    output reg fifo_underflow_latched,
    output reg fifo_overflow_latched,
    output reg [15:0] event_count,
    output wire [15:0] status_led_bus
);

  localparam [7:0] EVENT_TYPE_IDCODE = 8'h01;
  localparam [7:0] EVENT_TYPE_TIMEOUT = 8'hEE;

  assign status_led_bus = {
    jtag_tdo,
    jtag_tdi,
    jtag_tms,
    jtag_tck,
    jtag_state,
    scan_busy,
    fifo_overflow_latched,
    fifo_underflow_latched,
    fifo_full,
    fifo_empty,
    scan_done && !id_match,
    id_match,
    scan_done
  };

  always @(posedge clk) begin
    if (rst) begin
      latest_idcode <= 32'd0;
      id_match <= 1'b0;
      scan_done <= 1'b0;
      tdo_stuck_high <= 1'b0;
      tdo_stuck_low <= 1'b0;
      timeout_error <= 1'b0;
      jtag_state <= 4'd0;
      event_type <= 8'd0;
      timestamp <= 16'd0;
      fifo_underflow_latched <= 1'b0;
      fifo_overflow_latched <= 1'b0;
      event_count <= 16'd0;
    end else begin
      if (scan_busy) begin
        scan_done <= 1'b0;
      end

      if (event_valid) begin
        jtag_state <= event_word[27:24];
        event_type <= event_word[23:16];
        timestamp <= event_word[15:0];
        scan_done <= 1'b1;
        event_count <= event_count + 1'b1;

        if (event_word[23:16] == EVENT_TYPE_IDCODE) begin
          latest_idcode <= event_word[63:32];
          id_match <= event_word[31];
          tdo_stuck_high <= event_word[30];
          tdo_stuck_low <= event_word[29];
          timeout_error <= event_word[28];
        end else if (event_word[23:16] == EVENT_TYPE_TIMEOUT) begin
          id_match <= 1'b0;
          tdo_stuck_high <= event_word[30];
          tdo_stuck_low <= event_word[29];
          timeout_error <= event_word[28];
        end
      end

      if (fifo_underflow || fifo_valid) begin
        fifo_underflow_latched <= fifo_underflow_latched | fifo_underflow;
      end

      if (fifo_overflow_attempt) begin
        fifo_overflow_latched <= 1'b1;
      end
    end
  end

endmodule
