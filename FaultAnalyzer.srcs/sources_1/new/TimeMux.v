`timescale 1ns / 1ps

module TimeMux #(
    parameter integer NUM_DIGITS = 4,
    parameter integer DIGIT_WIDTH = 4,
    parameter integer REFRESH_LSB = 13,
    parameter integer REFRESH_WIDTH = 16,
    parameter integer DIGIT_SELECT_WIDTH = 3
) (
    input wire clk,
    input wire reset,
    input wire [NUM_DIGITS*DIGIT_WIDTH-1:0] vals,

    output reg [DIGIT_WIDTH-1:0] seg,
    output reg [ NUM_DIGITS-1:0] anodes
);

  reg [REFRESH_WIDTH-1:0] refresh_counter;
  wire [DIGIT_SELECT_WIDTH-1:0] digit_select;


  assign digit_select = refresh_counter[REFRESH_LSB+:DIGIT_SELECT_WIDTH];

  always @(posedge clk or posedge reset) begin : proc_dsp_time_mux
    if (reset) begin
      refresh_counter <= {REFRESH_WIDTH{1'b0}};
      seg <= {DIGIT_WIDTH{1'b0}};
      anodes <= {NUM_DIGITS{1'b1}};
    end else begin
      refresh_counter <= refresh_counter + 1'b1;
      seg <= vals[digit_select*DIGIT_WIDTH+:DIGIT_WIDTH];
      anodes <= ~({{(NUM_DIGITS - 1) {1'b0}}, 1'b1} << digit_select);
    end
  end
endmodule
