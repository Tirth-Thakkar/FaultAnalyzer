`timescale 1ns / 1ps

module VGA (
    input wire clk,
    input wire rst,
    input wire [31:0] idcode,
    input wire id_match,
    input wire scan_done,
    input wire scan_busy,
    input wire fifo_empty,
    input wire fifo_full,
    input wire fifo_underflow,
    input wire fifo_overflow,
    input wire [3:0] jtag_state,
    output reg [3:0] vga_red,
    output reg [3:0] vga_green,
    output reg [3:0] vga_blue,
    output wire vga_hs,
    output wire vga_vs
);
// Hello Darkness, my old friend
  localparam integer H_ACTIVE = 640;
  localparam integer H_FRONT = 18;
  localparam integer H_SYNC = 92;
  localparam integer H_BACK = 50;
  localparam integer H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
  localparam integer V_ACTIVE = 480;
  localparam integer V_FRONT = 10;
  localparam integer V_SYNC = 2;
  localparam integer V_BACK = 33;
  localparam integer V_TOTAL = V_ACTIVE + V_FRONT + V_SYNC + V_BACK;

  reg [1:0] pixel_divider;
  reg [9:0] h_count;
  reg [9:0] v_count;
  integer digit_index;
  reg [3:0] digit_nibble;
  reg digit_hit;
  wire pixel_tick;
  wire active_video;

  assign pixel_tick = (pixel_divider == 2'd3);
  assign active_video = (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
  assign vga_hs = ~((h_count >= H_ACTIVE + H_FRONT) && (h_count < H_ACTIVE + H_FRONT + H_SYNC));
  assign vga_vs = ~((v_count >= V_ACTIVE + V_FRONT) && (v_count < V_ACTIVE + V_FRONT + V_SYNC));

  function [6:0] hex_segments;
    input [3:0] value;
    begin
      case (value)
        4'h0: hex_segments = 7'b1111110;
        4'h1: hex_segments = 7'b0110000;
        4'h2: hex_segments = 7'b1101101;
        4'h3: hex_segments = 7'b1111001;
        4'h4: hex_segments = 7'b0110011;
        4'h5: hex_segments = 7'b1011011;
        4'h6: hex_segments = 7'b1011111;
        4'h7: hex_segments = 7'b1110000;
        4'h8: hex_segments = 7'b1111111;
        4'h9: hex_segments = 7'b1111011;
        4'hA: hex_segments = 7'b1110111;
        4'hB: hex_segments = 7'b0011111;
        4'hC: hex_segments = 7'b1001110;
        4'hD: hex_segments = 7'b0111101;
        4'hE: hex_segments = 7'b1001111;
        4'hF: hex_segments = 7'b1000111;
        default: hex_segments = 7'b0000001;
      endcase
    end
  endfunction

  function [3:0] idcode_nibble;
    input [2:0] index;
    begin
      case (index)
        3'd0: idcode_nibble = idcode[31:28];
        3'd1: idcode_nibble = idcode[27:24];
        3'd2: idcode_nibble = idcode[23:20];
        3'd3: idcode_nibble = idcode[19:16];
        3'd4: idcode_nibble = idcode[15:12];
        3'd5: idcode_nibble = idcode[11:8];
        3'd6: idcode_nibble = idcode[7:4];
        default: idcode_nibble = idcode[3:0];
      endcase
    end
  endfunction

  function digit_pixel_on;
    input [3:0] value;
    input [5:0] x;
    input [5:0] y;
    reg [6:0] seg;
    begin
      seg = hex_segments(value);
      digit_pixel_on = 1'b0;
      if (seg[6] && (y < 6) && (x >= 6) && (x < 30)) digit_pixel_on = 1'b1;
      if (seg[5] && (x >= 28) && (x < 34) && (y >= 6) && (y < 28)) digit_pixel_on = 1'b1;
      if (seg[4] && (x >= 28) && (x < 34) && (y >= 32) && (y < 54)) digit_pixel_on = 1'b1;
      if (seg[3] && (y >= 54) && (y < 60) && (x >= 6) && (x < 30)) digit_pixel_on = 1'b1;
      if (seg[2] && (x < 6) && (y >= 32) && (y < 54)) digit_pixel_on = 1'b1;
      if (seg[1] && (x < 6) && (y >= 6) && (y < 28)) digit_pixel_on = 1'b1;
      if (seg[0] && (y >= 27) && (y < 33) && (x >= 6) && (x < 30)) digit_pixel_on = 1'b1;
    end
  endfunction

  always @(posedge clk) begin
    if (rst) begin
      pixel_divider <= 2'd0;
      h_count <= 10'd0;
      v_count <= 10'd0;
    end else begin
      pixel_divider <= pixel_divider + 1'b1;

      if (pixel_tick) begin
        if (h_count == H_TOTAL - 1) begin
          h_count <= 10'd0;
          if (v_count == V_TOTAL - 1) begin
            v_count <= 10'd0;
          end else begin
            v_count <= v_count + 1'b1;
          end
        end else begin
          h_count <= h_count + 1'b1;
        end
      end
    end
  end

  always @(*) begin
    vga_red = 4'h0;
    vga_green = 4'h0;
    vga_blue = 4'h0;
    digit_hit = 1'b0;
    digit_nibble = 4'h0;

    if (active_video) begin
      if (v_count < 10'd64) begin
        if (scan_busy) begin
          {vga_red, vga_green, vga_blue} = {4'h0, 4'h4, 4'hF};
        end else if (scan_done && id_match) begin
          {vga_red, vga_green, vga_blue} = {4'h0, 4'hB, 4'h2};
        end else if (scan_done) begin
          {vga_red, vga_green, vga_blue} = {4'hD, 4'h1, 4'h1};
        end else begin
          {vga_red, vga_green, vga_blue} = {4'h2, 4'h2, 4'h2};
        end
      end

      if ((v_count >= 10'd96) && (v_count < 10'd156)) begin
        for (digit_index = 0; digit_index < 8; digit_index = digit_index + 1) begin
          if ((h_count >= (10'd40 + digit_index * 10'd48)) &&
              (h_count < (10'd74 + digit_index * 10'd48))) begin
            digit_nibble = idcode_nibble(digit_index[2:0]);
            digit_hit = digit_pixel_on(digit_nibble, h_count - (10'd40 + digit_index * 10'd48),
                                       v_count - 10'd96);
          end
        end

        if (digit_hit) begin
          if (scan_done && id_match) begin
            {vga_red, vga_green, vga_blue} = {4'h2, 4'hF, 4'h2};
          end else begin
            {vga_red, vga_green, vga_blue} = {4'hF, 4'hE, 4'h2};
          end
        end
      end

      if ((h_count >= 10'd40) && (h_count < 10'd180) && (v_count >= 10'd210) &&
          (v_count < 10'd290)) begin
        {vga_red, vga_green, vga_blue} = fifo_empty ? {4'h2, 4'h2, 4'h8} : {4'h0, 4'h8, 4'h8};
      end

      if ((h_count >= 10'd220) && (h_count < 10'd360) && (v_count >= 10'd210) &&
          (v_count < 10'd290)) begin
        {vga_red, vga_green, vga_blue} = fifo_full ? {4'hD, 4'h6, 4'h0} : {4'h0, 4'h8, 4'h2};
      end

      if ((h_count >= 10'd400) && (h_count < 10'd540) && (v_count >= 10'd210) &&
          (v_count < 10'd290)) begin
        {vga_red, vga_green, vga_blue} =
            (fifo_underflow || fifo_overflow) ? {4'hF, 4'h0, 4'h0} : {4'h0, 4'h8, 4'h2};
      end

      if ((v_count >= 10'd340) && (v_count < 10'd420) && (h_count >= 10'd40) &&
          (h_count < 10'd552)) begin
        if (h_count[8:5] < {1'b0, jtag_state}) begin
          {vga_red, vga_green, vga_blue} = {4'h8, 4'h4, 4'hF};
        end else begin
          {vga_red, vga_green, vga_blue} = {4'h1, 4'h1, 4'h1};
        end
      end
    end
  end

endmodule
