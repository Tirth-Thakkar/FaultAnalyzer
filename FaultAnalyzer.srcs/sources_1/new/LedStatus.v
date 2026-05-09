`timescale 1ns / 1ps

module LedStatus (
    input wire scan_done,
    input wire id_match,
    input wire fifo_empty,
    input wire fifo_full,
    input wire fifo_underflow,
    input wire fifo_overflow,
    input wire uart_busy,
    input wire [3:0] jtag_state,
    input wire jtag_tck,
    input wire jtag_tms,
    input wire jtag_tdi,
    input wire jtag_tdo,
    output wire [15:0] led
);

    assign led[0] = scan_done;
    assign led[1] = scan_done && id_match;
    assign led[2] = scan_done && !id_match;
    assign led[3] = fifo_empty;
    assign led[4] = fifo_full;
    assign led[5] = fifo_overflow;
    assign led[6] = fifo_underflow;
    assign led[7] = uart_busy;
    assign led[11:8] = jtag_state;
    assign led[12] = jtag_tck;
    assign led[13] = jtag_tms;
    assign led[14] = jtag_tdi;
    assign led[15] = jtag_tdo;

endmodule
