`timescale 1ns / 1ps

module JTAG #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TCK_HZ = 2_000_000,
    parameter [31:0] EXPECTED_IDCODE = 32'h0120_681B,
    parameter [7:0] IDCODE_OPCODE = 8'h11,
    parameter integer TIMEOUT_CYCLES = 1_000_000
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire compare_enable,
    input wire tdo,

    output wire tck,
    output reg tms,
    output reg tdi,
    output reg busy,
    output reg done,
    output reg [31:0] captured_idcode,
    output reg id_match,
    output reg tdo_stuck_high,
    output reg tdo_stuck_low,
    output reg timeout_error,
    output reg [3:0] jtag_state,
    output reg [63:0] event_word,
    output reg event_valid
);

    localparam integer TCK_HALF_DIVIDER = CLK_FREQ_HZ / (TCK_HZ * 2);
    localparam integer TCK_DIVIDER_WIDTH = 16;

    localparam [3:0] ST_IDLE = 4'd0;
    localparam [3:0] ST_RESET = 4'd1;
    localparam [3:0] ST_RUN_IDLE = 4'd2;
    localparam [3:0] ST_IR_SELECT_DR = 4'd3;
    localparam [3:0] ST_IR_SELECT_IR = 4'd4;
    localparam [3:0] ST_IR_CAPTURE = 4'd5;
    localparam [3:0] ST_IR_SHIFT = 4'd6;
    localparam [3:0] ST_IR_EXIT1 = 4'd7;
    localparam [3:0] ST_IR_UPDATE = 4'd8;
    localparam [3:0] ST_POST_IR_IDLE = 4'd9;
    localparam [3:0] ST_DR_SELECT = 4'd10;
    localparam [3:0] ST_DR_CAPTURE = 4'd11;
    localparam [3:0] ST_DR_SHIFT = 4'd12;
    localparam [3:0] ST_DR_EXIT1 = 4'd13;
    localparam [3:0] ST_DR_UPDATE = 4'd14;
    localparam [3:0] ST_FINISH = 4'd15;

    reg [3:0] state;
    reg [TCK_DIVIDER_WIDTH-1:0] tck_divider_count;
    reg tck_reg;
    reg start_d;
    reg [5:0] shift_count;
    reg [3:0] reset_count;
    reg [1:0] idle_count;
    reg tdo_seen_one;
    reg tdo_seen_all_one;
    reg [15:0] timestamp;
    reg [31:0] watchdog_count;
    wire tck_half_tick;
    wire tck_rising_edge;
    wire tck_falling_edge;
    wire effective_match;

    assign tck = tck_reg;
    assign tck_half_tick = (tck_divider_count == (TCK_HALF_DIVIDER - 1));
    assign tck_rising_edge = tck_half_tick && !tck_reg;
    assign tck_falling_edge = tck_half_tick && tck_reg;
    assign effective_match = compare_enable ? (captured_idcode == EXPECTED_IDCODE) : 1'b1;

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            jtag_state <= ST_IDLE;
            tck_divider_count <= {TCK_DIVIDER_WIDTH{1'b0}};
            tck_reg <= 1'b0;
            start_d <= 1'b0;
            shift_count <= 6'd0;
            reset_count <= 4'd0;
            idle_count <= 2'd0;
            tdo_seen_one <= 1'b0;
            tdo_seen_all_one <= 1'b1;
            timestamp <= 16'd0;
            watchdog_count <= 32'd0;
            tms <= 1'b1;
            tdi <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            captured_idcode <= 32'd0;
            id_match <= 1'b0;
            tdo_stuck_high <= 1'b0;
            tdo_stuck_low <= 1'b0;
            timeout_error <= 1'b0;
            event_word <= 64'd0;
            event_valid <= 1'b0;
    end else begin
        start_d <= start;
        done <= 1'b0;
        event_valid <= 1'b0;
        timestamp <= timestamp + 1'b1;
        jtag_state <= state;

        if (!busy) begin
            tck_reg <= 1'b0;
            tck_divider_count <= {TCK_DIVIDER_WIDTH{1'b0}};
            watchdog_count <= 32'd0;
        end else if (tck_half_tick) begin
            tck_divider_count <= {TCK_DIVIDER_WIDTH{1'b0}};
            tck_reg <= ~tck_reg;
            watchdog_count <= watchdog_count + 1'b1;
        end else begin
            tck_divider_count <= tck_divider_count + 1'b1;
        end

      if (busy && watchdog_count >= TIMEOUT_CYCLES) begin
        state <= ST_IDLE;
        busy <= 1'b0;
        done <= 1'b1;
        timeout_error <= 1'b1;
        id_match <= 1'b0;
        event_word <= {
          captured_idcode, 1'b0, tdo_seen_all_one, ~tdo_seen_one, 1'b1, state, 8'hEE, timestamp
        };
        event_valid <= 1'b1;
      end else if (state == ST_IDLE) begin
        tms <= 1'b1;
        tdi <= 1'b0;
        if (start && !start_d) begin
          state <= ST_RESET;
          busy <= 1'b1;
          reset_count <= 4'd0;
          shift_count <= 6'd0;
          idle_count <= 2'd0;
          captured_idcode <= 32'd0;
          tdo_seen_one <= 1'b0;
          tdo_seen_all_one <= 1'b1;
          tdo_stuck_high <= 1'b0;
          tdo_stuck_low <= 1'b0;
          timeout_error <= 1'b0;
          done <= 1'b0;
        end
      end else begin
        if (tck_rising_edge && state == ST_DR_SHIFT) begin
          captured_idcode[shift_count] <= tdo;
          tdo_seen_one <= tdo_seen_one | tdo;
          tdo_seen_all_one <= tdo_seen_all_one & tdo;
        end

        if (tck_falling_edge) begin
          case (state)
            ST_RESET: begin
              tms <= 1'b1;
              tdi <= 1'b0;
              if (reset_count == 4'd4) begin
                state <= ST_RUN_IDLE;
                tms   <= 1'b0;
              end else begin
                reset_count <= reset_count + 1'b1;
              end
            end

            ST_RUN_IDLE: begin
              state <= ST_IR_SELECT_DR;
              tms   <= 1'b1;
              tdi   <= 1'b0;
            end

            ST_IR_SELECT_DR: begin
              state <= ST_IR_SELECT_IR;
              tms   <= 1'b1;
            end

            ST_IR_SELECT_IR: begin
              state <= ST_IR_CAPTURE;
              tms   <= 1'b0;
            end

            ST_IR_CAPTURE: begin
              state <= ST_IR_SHIFT;
              shift_count <= 6'd0;
              tdi <= IDCODE_OPCODE[0];
              tms <= 1'b0;
            end

            ST_IR_SHIFT: begin
              if (shift_count == 6'd7) begin
                state <= ST_IR_EXIT1;
                tms   <= 1'b1;
                tdi   <= 1'b0;
              end else begin
                shift_count <= shift_count + 1'b1;
                tdi <= IDCODE_OPCODE[shift_count+1'b1];
                tms <= (shift_count == 6'd6);
              end
            end

            ST_IR_EXIT1: begin
              state <= ST_IR_UPDATE;
              tms   <= 1'b0;
            end

            ST_IR_UPDATE: begin
              state <= ST_POST_IR_IDLE;
              idle_count <= 2'd0;
              tms <= 1'b0;
            end

            ST_POST_IR_IDLE: begin
              tms <= 1'b0;
              if (idle_count == 2'd2) begin
                state <= ST_DR_SELECT;
                tms   <= 1'b1;
              end else begin
                idle_count <= idle_count + 1'b1;
              end
            end

            ST_DR_SELECT: begin
              state <= ST_DR_CAPTURE;
              tms   <= 1'b0;
            end

            ST_DR_CAPTURE: begin
              state <= ST_DR_SHIFT;
              shift_count <= 6'd0;
              tdi <= 1'b0;
              tms <= 1'b0;
              tdo_seen_one <= 1'b0;
              tdo_seen_all_one <= 1'b1;
            end

            ST_DR_SHIFT: begin
              tdi <= 1'b0;
              if (shift_count == 6'd31) begin
                state <= ST_DR_EXIT1;
                tms   <= 1'b1;
              end else begin
                shift_count <= shift_count + 1'b1;
                tms <= (shift_count == 6'd30);
              end
            end

            ST_DR_EXIT1: begin
              state <= ST_DR_UPDATE;
              tms   <= 1'b0;
            end

            ST_DR_UPDATE: begin
              state <= ST_FINISH;
              tms   <= 1'b0;
            end

            ST_FINISH: begin
              state <= ST_IDLE;
              busy <= 1'b0;
              done <= 1'b1;
              id_match <= effective_match;
              tdo_stuck_high <= tdo_seen_all_one;
              tdo_stuck_low <= ~tdo_seen_one;
              timeout_error <= 1'b0;
              event_word <= {
                captured_idcode,
                effective_match,
                tdo_seen_all_one,
                ~tdo_seen_one,
                1'b0,
                ST_FINISH,
                8'h01,
                timestamp
              };
              event_valid <= 1'b1;
            end

            default: begin
              state <= ST_IDLE;
              busy  <= 1'b0;
            end
          endcase
        end
      end
    end
  end

endmodule
