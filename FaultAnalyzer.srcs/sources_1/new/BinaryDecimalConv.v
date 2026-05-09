`timescale 1ns / 1ps

module BinaryDecimalConv #(
    parameter integer WIDTH = 16
)(
    input wire [WIDTH-1:0] binary_in,
    output wire [WIDTH-1:0] decimal_out
    );

    reg [3:0] ones;
    reg [3:0] tens;
    reg [3:0] hundreds;
    reg [3:0] thousands;

    always @(*) begin
        ones = binary_in % 10;
        tens = (binary_in / 10) % 10;
        hundreds = (binary_in / 100) % 10;
        thousands = (binary_in / 1000) % 10;
    end

    assign decimal_out = {thousands, hundreds, tens, ones};

endmodule
