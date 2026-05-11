`timescale 1ns / 1ps

// Demo-oriented VGA status panel for the Nexus A100T OneKiwi 1P5 JTAG scan.
// It intentionally stays text-free and resource-light: colored blocks encode scan, so preeety
module VGA #(
    parameter integer H_ACTIVE = 640,
    parameter integer H_FRONT_PORCH = 16,
    parameter integer H_SYNC_PULSE = 96,
    parameter integer H_BACK_PORCH = 48,

    parameter integer V_ACTIVE = 480,
    parameter integer V_FRONT_PORCH = 10,
    parameter integer V_SYNC_PULSE = 2,
    parameter integer V_BACK_PORCH = 33
) (
    input wire clk,
    input wire rst,

    input wire [31:0] idcode,
    input wire id_match,
    input wire scan_done,
    input wire scan_busy,

    input wire fifo_empty,
    input wire fifo_full,
    input wire fifo_valid,
    input wire fifo_underflow,
    input wire fifo_overflow,

    input wire tdo_stuck_high,
    input wire tdo_stuck_low,
    input wire timeout_error,

    input wire [3:0] jtag_state,
    input wire [7:0] event_type,
    input wire [15:0] event_count,
    input wire [15:0] sw,
    input wire [4:0] buttons,
    input wire uart_rx_valid,
    input wire [7:0] uart_rx_byte,

    output reg [3:0] vga_red,
    output reg [3:0] vga_green,
    output reg [3:0] vga_blue,
    output wire vga_hs,
    output wire vga_vs
);

    // -------------------------------------------------------------------------
    // VGA timing
    // -------------------------------------------------------------------------

    localparam integer PIXEL_DIVIDE = 4;
    localparam integer PIXEL_DIVIDER_WIDTH = 2;
    localparam [PIXEL_DIVIDER_WIDTH-1:0] PIXEL_TICK_COUNT = PIXEL_DIVIDE - 1;

    localparam integer H_SYNC_START = H_ACTIVE + H_FRONT_PORCH;
    localparam integer H_SYNC_END = H_SYNC_START + H_SYNC_PULSE;
    localparam integer H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    localparam integer V_SYNC_START = V_ACTIVE + V_FRONT_PORCH;
    localparam integer V_SYNC_END = V_SYNC_START + V_SYNC_PULSE;
    localparam integer V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    // -------------------------------------------------------------------------
    // Pixel layout
    // -------------------------------------------------------------------------

    localparam integer HEADER_LEFT = 0;
    localparam integer HEADER_TOP = 0;
    localparam integer HEADER_HEIGHT = 64;

    localparam integer IDCODE_X = 40;
    localparam integer IDCODE_Y = 96;
    localparam integer IDCODE_DIGITS = 8;
    localparam integer DIGIT_WIDTH = 34;
    localparam integer DIGIT_HEIGHT = 60;
    localparam integer DIGIT_PITCH = 48;

    localparam integer FIFO_BOX_Y = 210;
    localparam integer FIFO_BOX_WIDTH = 140;
    localparam integer FIFO_BOX_HEIGHT = 72;
    localparam integer FIFO_EMPTY_BOX_X = 40;
    localparam integer FIFO_FULL_BOX_X = 220;
    localparam integer FIFO_ERROR_BOX_X = 400;

    localparam integer FLAG_BOX_Y = 296;
    localparam integer FLAG_BOX_WIDTH = 120;
    localparam integer FLAG_BOX_HEIGHT = 32;
    localparam integer FLAG_TDO_HIGH_X = 40;
    localparam integer FLAG_TDO_LOW_X = 180;
    localparam integer FLAG_TIMEOUT_X = 320;
    localparam integer FLAG_UART_X = 460;

    localparam integer STATE_BAR_X = 40;
    localparam integer STATE_BAR_Y = 348;
    localparam integer STATE_BAR_WIDTH = 512;
    localparam integer STATE_BAR_HEIGHT = 48;
    localparam integer STATE_BAR_SEGMENT_WIDTH = 32;

    localparam integer EVENT_STRIP_X = 40;
    localparam integer EVENT_STRIP_Y = 410;
    localparam integer EVENT_STRIP_SEGMENT_WIDTH = 28;
    localparam integer EVENT_STRIP_HEIGHT = 18;

    localparam integer SWITCH_STRIP_X = 40;
    localparam integer SWITCH_STRIP_Y = 442;
    localparam integer SWITCH_STRIP_SEGMENT_WIDTH = 28;
    localparam integer SWITCH_STRIP_HEIGHT = 24;

    localparam integer BUTTON_STRIP_X = 508;
    localparam integer BUTTON_STRIP_Y = 442;
    localparam integer BUTTON_STRIP_SEGMENT_WIDTH = 20;
    localparam integer BUTTON_STRIP_HEIGHT = 24;

    // -------------------------------------------------------------------------
    // Seven-segment glyph geometry for IDCODE drawing
    // -------------------------------------------------------------------------

    localparam integer SEG_THICKNESS = 6;
    localparam integer SEG_X_LEFT = 0;
    localparam integer SEG_X_INNER_LEFT = 6;
    localparam integer SEG_X_INNER_RIGHT = 28;
    localparam integer SEG_Y_TOP = 0;
    localparam integer SEG_Y_UPPER_TOP = 6;
    localparam integer SEG_Y_UPPER_BOTTOM = 28;
    localparam integer SEG_Y_MID_TOP = 27;
    localparam integer SEG_Y_MID_BOTTOM = 33;
    localparam integer SEG_Y_LOWER_TOP = 32;
    localparam integer SEG_Y_LOWER_BOTTOM = 54;

    localparam integer SEG_BIT_TOP = 6;
    localparam integer SEG_BIT_UPPER_RIGHT = 5;
    localparam integer SEG_BIT_LOWER_RIGHT = 4;
    localparam integer SEG_BIT_BOTTOM = 3;
    localparam integer SEG_BIT_LOWER_LEFT = 2;
    localparam integer SEG_BIT_UPPER_LEFT = 1;
    localparam integer SEG_BIT_MIDDLE = 0;

    // -------------------------------------------------------------------------
    // Colors, packed as {red, green, blue}
    // -------------------------------------------------------------------------

    localparam [11:0] COLOR_BLACK = 12'h000;
    localparam [11:0] COLOR_IDLE = 12'h222;
    localparam [11:0] COLOR_SCAN_BUSY = 12'h04F;
    localparam [11:0] COLOR_SCAN_PASS = 12'h0B2;
    localparam [11:0] COLOR_SCAN_FAIL = 12'hD11;
    localparam [11:0] COLOR_IDCODE_OK = 12'h2F2;
    localparam [11:0] COLOR_IDCODE_PENDING = 12'hFE2;
    localparam [11:0] COLOR_FIFO_EMPTY = 12'h228;
    localparam [11:0] COLOR_FIFO_ACTIVE = 12'h088;
    localparam [11:0] COLOR_FIFO_FULL = 12'hD60;
    localparam [11:0] COLOR_FIFO_OK = 12'h082;
    localparam [11:0] COLOR_FIFO_ERROR = 12'hF00;
    localparam [11:0] COLOR_STATE_ACTIVE = 12'h84F;
    localparam [11:0] COLOR_STATE_INACTIVE = 12'h111;
    localparam [11:0] COLOR_CONTROL_ON = 12'h0C4;
    localparam [11:0] COLOR_CONTROL_OFF = 12'h333;
    localparam [11:0] COLOR_UART_RX = 12'h0AF;

    // -------------------------------------------------------------------------
    // Timing state
    // -------------------------------------------------------------------------

    reg [PIXEL_DIVIDER_WIDTH-1:0] pixel_divider;
    reg [9:0] h_count;
    reg [9:0] v_count;

    wire pixel_tick;
    wire horizontal_active;
    wire vertical_active;
    wire active_video;
    wire horizontal_sync_active;
    wire vertical_sync_active;

    // -------------------------------------------------------------------------
    // Pixel-generation state
    // -------------------------------------------------------------------------

    integer digit_index;
    integer digit_left;
    integer strip_index;
    integer strip_left;
    reg [3:0] strip_bit;
    reg [3:0] digit_nibble;
    reg [5:0] digit_x;
    reg [5:0] digit_y;
    reg [6:0] digit_segments;
    reg digit_region_hit;
    reg digit_segment_hit;
    reg switch_region_hit;
    reg switch_bit_value;
    reg event_region_hit;
    reg event_bit_value;
    reg event_type_region_hit;
    reg event_type_bit_value;
    reg button_region_hit;
    reg button_bit_value;
    reg [11:0] pixel_color;

    wire header_region;
    wire idcode_region;
    wire fifo_empty_region;
    wire fifo_full_region;
    wire fifo_error_region;
    wire tdo_high_region;
    wire tdo_low_region;
    wire timeout_region;
    wire uart_region;
    wire state_bar_region;

    assign pixel_tick = (pixel_divider == PIXEL_TICK_COUNT);

    assign horizontal_active = (h_count < H_ACTIVE);
    assign vertical_active = (v_count < V_ACTIVE);
    assign active_video = horizontal_active && vertical_active;

    assign horizontal_sync_active = (h_count >= H_SYNC_START) && (h_count < H_SYNC_END);
    assign vertical_sync_active = (v_count >= V_SYNC_START) && (v_count < V_SYNC_END);

    assign vga_hs = ~horizontal_sync_active;
    assign vga_vs = ~vertical_sync_active;

    assign header_region = (h_count >= HEADER_LEFT) &&
                           (h_count < H_ACTIVE) &&
                           (v_count >= HEADER_TOP) &&
                           (v_count < HEADER_TOP + HEADER_HEIGHT);

    assign idcode_region = (h_count >= IDCODE_X) &&
                           (h_count < IDCODE_X + (IDCODE_DIGITS * DIGIT_PITCH)) &&
                           (v_count >= IDCODE_Y) &&
                           (v_count < IDCODE_Y + DIGIT_HEIGHT);

    assign fifo_empty_region = (h_count >= FIFO_EMPTY_BOX_X) &&
                               (h_count < FIFO_EMPTY_BOX_X + FIFO_BOX_WIDTH) &&
                               (v_count >= FIFO_BOX_Y) &&
                               (v_count < FIFO_BOX_Y + FIFO_BOX_HEIGHT);

    assign fifo_full_region = (h_count >= FIFO_FULL_BOX_X) &&
                              (h_count < FIFO_FULL_BOX_X + FIFO_BOX_WIDTH) &&
                              (v_count >= FIFO_BOX_Y) &&
                              (v_count < FIFO_BOX_Y + FIFO_BOX_HEIGHT);

    assign fifo_error_region = (h_count >= FIFO_ERROR_BOX_X) &&
                               (h_count < FIFO_ERROR_BOX_X + FIFO_BOX_WIDTH) &&
                               (v_count >= FIFO_BOX_Y) &&
                               (v_count < FIFO_BOX_Y + FIFO_BOX_HEIGHT);

    assign tdo_high_region = (h_count >= FLAG_TDO_HIGH_X) &&
                             (h_count < FLAG_TDO_HIGH_X + FLAG_BOX_WIDTH) &&
                             (v_count >= FLAG_BOX_Y) &&
                             (v_count < FLAG_BOX_Y + FLAG_BOX_HEIGHT);

    assign tdo_low_region = (h_count >= FLAG_TDO_LOW_X) &&
                            (h_count < FLAG_TDO_LOW_X + FLAG_BOX_WIDTH) &&
                            (v_count >= FLAG_BOX_Y) &&
                            (v_count < FLAG_BOX_Y + FLAG_BOX_HEIGHT);

    assign timeout_region = (h_count >= FLAG_TIMEOUT_X) &&
                            (h_count < FLAG_TIMEOUT_X + FLAG_BOX_WIDTH) &&
                            (v_count >= FLAG_BOX_Y) &&
                            (v_count < FLAG_BOX_Y + FLAG_BOX_HEIGHT);

    assign uart_region = (h_count >= FLAG_UART_X) &&
                         (h_count < FLAG_UART_X + FLAG_BOX_WIDTH) &&
                         (v_count >= FLAG_BOX_Y) &&
                         (v_count < FLAG_BOX_Y + FLAG_BOX_HEIGHT);

    assign state_bar_region = (h_count >= STATE_BAR_X) &&
                              (h_count < STATE_BAR_X + STATE_BAR_WIDTH) &&
                              (v_count >= STATE_BAR_Y) &&
                              (v_count < STATE_BAR_Y + STATE_BAR_HEIGHT);

    always @(*) begin : proc_idcode_digit_select
        digit_region_hit = 1'b0;
        digit_nibble = 4'h0;
        digit_x = 6'd0;
        digit_y = 6'd0;
        digit_left = IDCODE_X;

        if (idcode_region) begin
            for (
                digit_index = 0;
                digit_index < IDCODE_DIGITS;
                digit_index = digit_index + 1
            ) begin
                digit_left = IDCODE_X + (digit_index * DIGIT_PITCH);

                if ((h_count >= digit_left) &&
                    (h_count < digit_left + DIGIT_WIDTH)) begin
                    digit_region_hit = 1'b1;
                    digit_x = h_count - digit_left;
                    digit_y = v_count - IDCODE_Y;

                    case (digit_index[2:0])
                        3'd0: digit_nibble = idcode[31:28];
                        3'd1: digit_nibble = idcode[27:24];
                        3'd2: digit_nibble = idcode[23:20];
                        3'd3: digit_nibble = idcode[19:16];
                        3'd4: digit_nibble = idcode[15:12];
                        3'd5: digit_nibble = idcode[11:8];
                        3'd6: digit_nibble = idcode[7:4];
                        default: digit_nibble = idcode[3:0];
                    endcase
                end
            end
        end
    end

    always @(*) begin : proc_control_strip_select
        switch_region_hit = 1'b0;
        switch_bit_value = 1'b0;
        event_region_hit = 1'b0;
        event_bit_value = 1'b0;
        event_type_region_hit = 1'b0;
        event_type_bit_value = 1'b0;
        button_region_hit = 1'b0;
        button_bit_value = 1'b0;
        strip_left = SWITCH_STRIP_X;
        strip_bit = 4'd0;

        for (strip_index = 0; strip_index < 16; strip_index = strip_index + 1) begin
            strip_left = SWITCH_STRIP_X + (strip_index * SWITCH_STRIP_SEGMENT_WIDTH);
            strip_bit = strip_index[3:0];

            if ((h_count >= strip_left) &&
                (h_count < strip_left + SWITCH_STRIP_SEGMENT_WIDTH - 4) &&
                (v_count >= SWITCH_STRIP_Y) &&
                (v_count < SWITCH_STRIP_Y + SWITCH_STRIP_HEIGHT)) begin
                switch_region_hit = 1'b1;
                switch_bit_value = sw[strip_bit];
            end

            strip_left = EVENT_STRIP_X + (strip_index * EVENT_STRIP_SEGMENT_WIDTH);

            if ((h_count >= strip_left) &&
                (h_count < strip_left + EVENT_STRIP_SEGMENT_WIDTH - 4) &&
                (v_count >= EVENT_STRIP_Y) &&
                (v_count < EVENT_STRIP_Y + EVENT_STRIP_HEIGHT)) begin
                event_region_hit = 1'b1;
                event_bit_value = event_count[strip_bit];

                if (strip_index < 8) begin
                    event_type_region_hit = 1'b1;
                    event_type_bit_value = event_type[strip_bit[2:0]];
                end
            end
        end

        for (strip_index = 0; strip_index < 5; strip_index = strip_index + 1) begin
            strip_left = BUTTON_STRIP_X + (strip_index * BUTTON_STRIP_SEGMENT_WIDTH);

            if ((h_count >= strip_left) &&
                (h_count < strip_left + BUTTON_STRIP_SEGMENT_WIDTH - 4) &&
                (v_count >= BUTTON_STRIP_Y) &&
                (v_count < BUTTON_STRIP_Y + BUTTON_STRIP_HEIGHT)) begin
                button_region_hit = 1'b1;
                button_bit_value = buttons[strip_index[2:0]];
            end
        end
    end

    always @(*) begin : proc_hex_segment_decode
        case (digit_nibble)
            4'h0: digit_segments = 7'b1111110;
            4'h1: digit_segments = 7'b0110000;
            4'h2: digit_segments = 7'b1101101;
            4'h3: digit_segments = 7'b1111001;
            4'h4: digit_segments = 7'b0110011;
            4'h5: digit_segments = 7'b1011011;
            4'h6: digit_segments = 7'b1011111;
            4'h7: digit_segments = 7'b1110000;
            4'h8: digit_segments = 7'b1111111;
            4'h9: digit_segments = 7'b1111011;
            4'hA: digit_segments = 7'b1110111;
            4'hB: digit_segments = 7'b0011111;
            4'hC: digit_segments = 7'b1001110;
            4'hD: digit_segments = 7'b0111101;
            4'hE: digit_segments = 7'b1001111;
            default: digit_segments = 7'b1000111;
        endcase
    end

    always @(*) begin : proc_digit_segment_hit_decode
        digit_segment_hit = 1'b0;

        if (digit_region_hit) begin
            if (digit_segments[SEG_BIT_TOP] &&
                (digit_x >= SEG_X_INNER_LEFT) &&
                (digit_x < SEG_X_INNER_RIGHT) &&
                (digit_y >= SEG_Y_TOP) &&
                (digit_y < SEG_Y_TOP + SEG_THICKNESS)) begin
                digit_segment_hit = 1'b1;
            end

            if (digit_segments[SEG_BIT_UPPER_RIGHT] &&
                (digit_x >= SEG_X_INNER_RIGHT) &&
                (digit_x < SEG_X_INNER_RIGHT + SEG_THICKNESS) &&
                (digit_y >= SEG_Y_UPPER_TOP) &&
                (digit_y < SEG_Y_UPPER_BOTTOM)) begin
                digit_segment_hit = 1'b1;
            end

            if (digit_segments[SEG_BIT_LOWER_RIGHT] &&
                (digit_x >= SEG_X_INNER_RIGHT) &&
                (digit_x < SEG_X_INNER_RIGHT + SEG_THICKNESS) &&
                (digit_y >= SEG_Y_LOWER_TOP) &&
                (digit_y < SEG_Y_LOWER_BOTTOM)) begin
                digit_segment_hit = 1'b1;
            end

            if (digit_segments[SEG_BIT_BOTTOM] &&
                (digit_x >= SEG_X_INNER_LEFT) &&
                (digit_x < SEG_X_INNER_RIGHT) &&
                (digit_y >= SEG_Y_LOWER_BOTTOM) &&
                (digit_y < SEG_Y_LOWER_BOTTOM + SEG_THICKNESS)) begin
                digit_segment_hit = 1'b1;
            end

            if (digit_segments[SEG_BIT_LOWER_LEFT] &&
                (digit_x >= SEG_X_LEFT) &&
                (digit_x < SEG_X_LEFT + SEG_THICKNESS) &&
                (digit_y >= SEG_Y_LOWER_TOP) &&
                (digit_y < SEG_Y_LOWER_BOTTOM)) begin
                digit_segment_hit = 1'b1;
            end

            if (digit_segments[SEG_BIT_UPPER_LEFT] &&
                (digit_x >= SEG_X_LEFT) &&
                (digit_x < SEG_X_LEFT + SEG_THICKNESS) &&
                (digit_y >= SEG_Y_UPPER_TOP) &&
                (digit_y < SEG_Y_UPPER_BOTTOM)) begin
                digit_segment_hit = 1'b1;
            end

            if (digit_segments[SEG_BIT_MIDDLE] &&
                (digit_x >= SEG_X_INNER_LEFT) &&
                (digit_x < SEG_X_INNER_RIGHT) &&
                (digit_y >= SEG_Y_MID_TOP) &&
                (digit_y < SEG_Y_MID_BOTTOM)) begin
                digit_segment_hit = 1'b1;
            end
        end
    end

    always @(posedge clk) begin : proc_vga_timing_counters
        if (rst) begin
            pixel_divider <= {PIXEL_DIVIDER_WIDTH{1'b0}};
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

    always @(*) begin : proc_vga_pixel_mux
        pixel_color = COLOR_BLACK;

        if (active_video) begin
            pixel_color = COLOR_IDLE;

            if (header_region) begin
                if (scan_busy) begin
                    pixel_color = COLOR_SCAN_BUSY;
                end else if (scan_done && id_match) begin
                    pixel_color = COLOR_SCAN_PASS;
                end else if (scan_done) begin
                    pixel_color = COLOR_SCAN_FAIL;
                end
            end

            if (idcode_region && digit_segment_hit) begin
                if (scan_done && id_match) begin
                    pixel_color = COLOR_IDCODE_OK;
                end else begin
                    pixel_color = COLOR_IDCODE_PENDING;
                end
            end

            if (fifo_empty_region) begin
                pixel_color = fifo_empty ? COLOR_FIFO_EMPTY : COLOR_FIFO_ACTIVE;
            end

            if (fifo_full_region) begin
                pixel_color = fifo_full ? COLOR_FIFO_FULL : COLOR_FIFO_OK;
            end

            if (fifo_error_region) begin
                pixel_color = (fifo_underflow || fifo_overflow) ? COLOR_FIFO_ERROR :
                    (fifo_valid ? COLOR_FIFO_ACTIVE : COLOR_FIFO_OK);
            end

            if (tdo_high_region) begin
                pixel_color = tdo_stuck_high ? COLOR_FIFO_ERROR : COLOR_FIFO_OK;
            end

            if (tdo_low_region) begin
                pixel_color = tdo_stuck_low ? COLOR_FIFO_ERROR : COLOR_FIFO_OK;
            end

            if (timeout_region) begin
                pixel_color = timeout_error ? COLOR_FIFO_ERROR : COLOR_FIFO_OK;
            end

            if (uart_region) begin
                pixel_color = uart_rx_valid ? COLOR_UART_RX :
                    (uart_rx_byte[0] ? COLOR_CONTROL_ON : COLOR_CONTROL_OFF);
            end

            if (state_bar_region) begin
                if ((h_count - STATE_BAR_X) < (jtag_state * STATE_BAR_SEGMENT_WIDTH)) begin
                    pixel_color = COLOR_STATE_ACTIVE;
                end else begin
                    pixel_color = COLOR_STATE_INACTIVE;
                end
            end

            if (event_region_hit) begin
                pixel_color = event_bit_value ? COLOR_STATE_ACTIVE : COLOR_STATE_INACTIVE;
            end

            if (event_type_region_hit) begin
                pixel_color = event_type_bit_value ? COLOR_UART_RX : pixel_color;
            end

            if (switch_region_hit) begin
                pixel_color = switch_bit_value ? COLOR_CONTROL_ON : COLOR_CONTROL_OFF;
            end

            if (button_region_hit) begin
                pixel_color = button_bit_value ? COLOR_IDCODE_PENDING : COLOR_CONTROL_OFF;
            end
        end

        vga_red = pixel_color[11:8];
        vga_green = pixel_color[7:4];
        vga_blue = pixel_color[3:0];
    end

endmodule
