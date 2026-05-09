`timescale 1ns / 1ps
module SevenSegDecoder #(
    parameter WIDTH = 4,
    parameter USE_BLANKING = 1'b1
) (
    input reset,
    input [WIDTH-1:0] val,
    input [7:0] anodes,
    output [6:0] seg
);

    reg [6:0] seg_decode;
    wire any_digit_active;

    assign any_digit_active = ~&anodes;

    always @(*) begin
        case (val)
            4'h0: seg_decode = 7'b1000000;
            4'h1: seg_decode = 7'b1111001;
            4'h2: seg_decode = 7'b0100100;
            4'h3: seg_decode = 7'b0110000;
            4'h4: seg_decode = 7'b0011001;
            4'h5: seg_decode = 7'b0010010;
            4'h6: seg_decode = 7'b0000010;
            4'h7: seg_decode = 7'b1111000;
            4'h8: seg_decode = 7'b0000000;
            4'h9: seg_decode = 7'b0011000;
            4'hA: seg_decode = 7'b0001000;
            4'hB: seg_decode = 7'b0000011;
            4'hC: seg_decode = 7'b1000110;
            4'hD: seg_decode = 7'b0100001;
            4'hE: seg_decode = 7'b0000110;
            4'hF: seg_decode = 7'b0001110;
            default: seg_decode = 7'b1111111;
        endcase
    end

    generate
        if (USE_BLANKING) begin : gen_blanking
            assign seg = (reset || !any_digit_active) ? 7'b1111111 : seg_decode;
        end else begin : gen_no_blanking
            assign seg = seg_decode;
        end
    endgenerate

endmodule
