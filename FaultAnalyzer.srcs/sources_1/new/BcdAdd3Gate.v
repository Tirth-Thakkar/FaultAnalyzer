`timescale 1ns / 1ps

module BcdAdd3Gate ( // 4 bit in/out to convert to 1 bcd digit
    input  wire [3:0] bcd_in,
    output wire [3:0] bcd_out
);

    wire ge_five;

    wire s0;
    wire s1;
    wire s2;
    wire s3;

    wire c1;
    wire c2;
    wire c3;

    // ge_five = bcd_in >= 5
    assign ge_five = bcd_in[3] | (bcd_in[2] & (bcd_in[1] | bcd_in[0]));

    // Add either 0000 or 0011.
    // Bit 0: bcd_in[0] + ge_five
    assign s0 = bcd_in[0] ^ ge_five;
    assign c1 = bcd_in[0] & ge_five;

    // Bit 1: bcd_in[1] + ge_five + c1
    assign s1 = bcd_in[1] ^ ge_five ^ c1;
    assign c2 = (bcd_in[1] & ge_five) |
                (bcd_in[1] & c1)       |
                (ge_five  & c1);

    // Bit 2: bcd_in[2] + c2
    assign s2 = bcd_in[2] ^ c2;
    assign c3 = bcd_in[2] & c2;

    // Bit 3: bcd_in[3] + c3
    assign s3 = bcd_in[3] ^ c3;

    assign bcd_out = {s3, s2, s1, s0};

endmodule