`timescale 1ns / 1ps

// Adds 3 to a BCD digit when the digit is >= 5.
// Written structurally with gate design pls dont judge me I needed gate-lever so 
// the module I am calling (BCDADD3Gate) does it for me :). 

module BinaryDecimalConv #(
    parameter integer WIDTH = 16,
    parameter integer BCD_DIGITS = WIDTH / 4
)(
    input  wire [WIDTH-1:0] binary_in,
    output wire [(BCD_DIGITS*4)-1:0] decimal_out
);

    localparam integer BCD_WIDTH = BCD_DIGITS * 4;

    wire [BCD_WIDTH-1:0] shift_stage [0:WIDTH];
    wire [BCD_WIDTH-1:0] add3_stage  [0:WIDTH-1];

    genvar bit_index;
    genvar digit_index;

    assign shift_stage[0] = {BCD_WIDTH{1'b0}};

    generate
        for (bit_index = 0; bit_index < WIDTH; bit_index = bit_index + 1) begin : DOUBLE_DABBLE_BIT

            for (digit_index = 0; digit_index < BCD_DIGITS; digit_index = digit_index + 1) begin : DOUBLE_DABBLE_DIGIT

                BcdAdd3Gate u_bcd_add3_gate (
                    .bcd_in  (shift_stage[bit_index][(digit_index*4)+3 : digit_index*4]),
                    .bcd_out (add3_stage[bit_index][(digit_index*4)+3 : digit_index*4])
                );

            end

            assign shift_stage[bit_index+1] = {
                add3_stage[bit_index][BCD_WIDTH-2:0],
                binary_in[WIDTH-1-bit_index]
            };

        end
    endgenerate

    assign decimal_out = shift_stage[WIDTH];

endmodule