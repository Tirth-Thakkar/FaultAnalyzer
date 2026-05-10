`timescale 1ns / 1ps

module TopModule (
    input wire clk_i,
    input wire [15:0] sw_i,

    input wire btnc_i,
    input wire btnd_i,

    input wire jtag_tdo_i,
    output wire jtag_tck_o,
    output wire jtag_tms_o,
    output wire jtag_tdi_o,
    output wire [15:0] led_o,

    output wire [6:0] seg_o,
    output wire [7:0] an_o,
    output wire dp_o,

    output wire uart_txd_o,
    input wire uart_rxd_i,

    output wire [3:0] vga_red_o,
    output wire [3:0] vga_green_o,
    output wire [3:0] vga_blue_o,
    output wire vga_hs_o,
    output wire vga_vs_o
);

    // Board clock and protocol parameters
    localparam integer CLK_FREQ_HZ = 100_000_000;
    localparam integer JTAG_TCK_HZ = 2_000_000;
    localparam integer UART_BAUD = 115200;

    localparam integer UART_CLK_DIVISOR_BITS = 2;
    localparam integer UART_CLK_DIVISOR = 1 << UART_CLK_DIVISOR_BITS;
    localparam integer UART_CLK_HZ = CLK_FREQ_HZ / UART_CLK_DIVISOR;
    localparam integer UART_CLKS_PER_BIT = UART_CLK_HZ / UART_BAUD;


    // Boundary-scan parameters
    localparam [31:0] EXPECTED_GOWIN_IDCODE = 32'h0000_0000;
    localparam [7:0] EXPECTED_BOUNDARY_DATA = 8'h00;
    localparam [1:0] JTAG_BOUNDARY_OPCODE = 2'b01;


    // Board control mapping
    localparam integer SW_START_SCAN = 0;
    localparam integer SW_BOUNDARY_A = 1;
    localparam integer SW_BOUNDARY_B = 2;
    localparam integer SW_BOUNDARY_C = 3;
    localparam integer SW_BOUNDARY_D = 4;
    localparam integer BTN_CENTER = 0;
    localparam integer BTN_DOWN = 1;


    // UART diagnostic message format
    localparam [2:0] UART_STATE_IDLE = 3'd0;
    localparam [2:0] UART_STATE_SEND = 3'd1;
    localparam [2:0] UART_STATE_WAIT_DONE = 3'd2;

    localparam integer UART_STATUS_LENGTH = 15;
    localparam [3:0] UART_LAST_CHAR_INDEX = UART_STATUS_LENGTH - 1;

    localparam [7:0] UART_CHAR_PASS = "P";
    localparam [7:0] UART_CHAR_FAIL = "F";
    localparam [7:0] UART_CHAR_SPACE = " ";
    localparam [7:0] UART_CHAR_I = "I";
    localparam [7:0] UART_CHAR_D = "D";
    localparam [7:0] UART_CHAR_EQUALS = "=";
    localparam [7:0] UART_CHAR_CR = 8'h0D;
    localparam [7:0] UART_CHAR_LF = 8'h0A;


    // Synchronized board controls
    wire [1:0] button_raw;
    wire [15:0] sw_sync;
    wire [1:0] button_sync;
    wire rst;
    wire start_scan;

    reg [15:0] sw_meta_reg = 16'd0;
    reg [15:0] sw_sync_reg = 16'd0;
    reg [1:0] button_meta_reg = 2'd0;
    reg [1:0] button_sync_reg = 2'd0;


    // JTAG scan
    wire jtag_busy;
    wire jtag_done;
    wire jtag_match;
    wire jtag_tdo_stuck_high;
    wire jtag_tdo_stuck_low;
    wire jtag_timeout;
    wire [3:0] jtag_state;
    wire [31:0] jtag_idcode;
    wire [7:0] jtag_boundary_data;
    wire [63:0] jtag_event_word;
    wire jtag_event_valid;
    wire boundary_i;
    wire boundary_j;
    wire boundary_tdo;
    wire [3:0] boundary_state;
    wire [3:0] boundary_inputs;


    // FIFO event buffer
    wire [63:0] fifo_dout;
    wire fifo_full;
    wire fifo_almost_full;
    wire fifo_empty;
    wire fifo_valid;
    wire fifo_underflow;
    wire fifo_rd_en;
    wire fifo_wr_en;
    wire fifo_overflow_attempt;


    // Decoded status interface
    wire [31:0] status_idcode;
    wire status_match;
    wire status_scan_done;
    wire status_tdo_stuck_high;
    wire status_tdo_stuck_low;
    wire status_timeout;
    wire [3:0] status_jtag_state;
    wire [7:0] status_event_type;
    wire [15:0] status_timestamp;
    wire status_fifo_underflow_latched;
    wire status_fifo_overflow_latched;
    wire [15:0] status_event_count;
    wire [15:0] status_led_bus;


    // UART diagnostic adapter
    reg uart_clk = 1'b0;
    reg [UART_CLK_DIVISOR_BITS-1:0] uart_clk_divider = {UART_CLK_DIVISOR_BITS{1'b0}};
    reg uart_event_toggle_sys = 1'b0;
    reg uart_event_match_sys = 1'b0;
    reg [31:0] uart_event_idcode_sys = 32'd0;
    reg [2:0] uart_event_toggle_sync = 3'd0;
    reg uart_event_toggle_seen = 1'b0;
    reg uart_event_match = 1'b0;
    reg [31:0] uart_event_idcode = 32'd0;
    reg [2:0] uart_state = UART_STATE_IDLE;
    reg [3:0] uart_char_index = 4'd0;
    reg uart_tx_dv = 1'b0;
    reg [7:0] uart_tx_byte = 8'd0;
    reg [3:0] uart_status_nibble;
    reg [7:0] uart_hex_ascii;
    reg [7:0] uart_status_byte;

    wire uart_tx_active;
    wire uart_tx_serial;
    wire uart_tx_done;
    wire uart_rx_valid;
    wire [7:0] uart_rx_byte;


    // Display interfaces
    wire [3:0] seg_nibble;
    wire [31:0] seven_seg_value;


    // Board control and subsystem wiring
    assign button_raw = {btnd_i, btnc_i};
    assign sw_sync = sw_sync_reg;
    assign button_sync = button_sync_reg;
    assign rst = button_sync[BTN_DOWN];
    assign start_scan = button_sync[BTN_CENTER] | sw_sync[SW_START_SCAN];
    assign boundary_inputs = {
        sw_sync[SW_BOUNDARY_D],
        sw_sync[SW_BOUNDARY_C],
        sw_sync[SW_BOUNDARY_B],
        sw_sync[SW_BOUNDARY_A]
    };

    assign fifo_wr_en = jtag_event_valid && !fifo_full;
    assign fifo_overflow_attempt = jtag_event_valid && fifo_full;
    assign fifo_rd_en = 1'b0;

    assign seven_seg_value = status_scan_done ? status_idcode : EXPECTED_GOWIN_IDCODE;
    assign dp_o = 1'b1;
    assign uart_txd_o = uart_tx_active ? uart_tx_serial : 1'b1;


    // UART diagnostic message decode
    always @(*) begin : proc_uart_status_nibble_mux
        case (uart_char_index)
            4'd5: uart_status_nibble = uart_event_idcode[31:28];
            4'd6: uart_status_nibble = uart_event_idcode[27:24];
            4'd7: uart_status_nibble = uart_event_idcode[23:20];
            4'd8: uart_status_nibble = uart_event_idcode[19:16];
            4'd9: uart_status_nibble = uart_event_idcode[15:12];
            4'd10: uart_status_nibble = uart_event_idcode[11:8];
            4'd11: uart_status_nibble = uart_event_idcode[7:4];
            4'd12: uart_status_nibble = uart_event_idcode[3:0];
            default: uart_status_nibble = 4'h0;
        endcase
    end

    always @(*) begin : proc_uart_hex_ascii_decode
        case (uart_status_nibble)
            4'h0: uart_hex_ascii = "0";
            4'h1: uart_hex_ascii = "1";
            4'h2: uart_hex_ascii = "2";
            4'h3: uart_hex_ascii = "3";
            4'h4: uart_hex_ascii = "4";
            4'h5: uart_hex_ascii = "5";
            4'h6: uart_hex_ascii = "6";
            4'h7: uart_hex_ascii = "7";
            4'h8: uart_hex_ascii = "8";
            4'h9: uart_hex_ascii = "9";
            4'hA: uart_hex_ascii = "A";
            4'hB: uart_hex_ascii = "B";
            4'hC: uart_hex_ascii = "C";
            4'hD: uart_hex_ascii = "D";
            4'hE: uart_hex_ascii = "E";
            default: uart_hex_ascii = "F";
        endcase
    end

    always @(*) begin : proc_uart_status_byte_mux
        case (uart_char_index)
            4'd0: uart_status_byte = uart_event_match ? UART_CHAR_PASS : UART_CHAR_FAIL;
            4'd1: uart_status_byte = UART_CHAR_SPACE;
            4'd2: uart_status_byte = UART_CHAR_I;
            4'd3: uart_status_byte = UART_CHAR_D;
            4'd4: uart_status_byte = UART_CHAR_EQUALS;
            // Character slots 5-12 are the eight IDCODE hex digits.
            // The default remains LF for the final terminator/fallback.
            4'd5,
            4'd6,
            4'd7,
            4'd8,
            4'd9,
            4'd10,
            4'd11,
            4'd12: uart_status_byte = uart_hex_ascii;
            4'd13: uart_status_byte = UART_CHAR_CR;
            default: uart_status_byte = UART_CHAR_LF;
        endcase
    end


    // Clocked processes
    always @(posedge clk_i) begin : proc_input_synchronizers
        sw_meta_reg <= sw_i;
        sw_sync_reg <= sw_meta_reg;
        button_meta_reg <= button_raw;
        button_sync_reg <= button_meta_reg;
    end

    always @(posedge clk_i) begin : proc_uart_clock_divider
        if (rst) begin
            uart_clk_divider <= {UART_CLK_DIVISOR_BITS{1'b0}};
            uart_clk <= 1'b0;
        end else begin
            uart_clk_divider <= uart_clk_divider + 1'b1;
            uart_clk <= uart_clk_divider[UART_CLK_DIVISOR_BITS-1];
        end
    end

    always @(posedge clk_i) begin : proc_uart_event_capture_sys
        if (rst) begin
            uart_event_toggle_sys <= 1'b0;
            uart_event_match_sys <= 1'b0;
            uart_event_idcode_sys <= 32'd0;
        end else if (jtag_event_valid) begin
            uart_event_toggle_sys <= ~uart_event_toggle_sys;
            uart_event_match_sys <= jtag_event_word[31];
            uart_event_idcode_sys <= jtag_event_word[63:32];
        end
    end

    always @(posedge uart_clk) begin : proc_uart_event_sender
        if (rst) begin
            uart_event_toggle_sync <= 3'd0;
            uart_event_toggle_seen <= 1'b0;
            uart_event_match <= 1'b0;
            uart_event_idcode <= 32'd0;
            uart_state <= UART_STATE_IDLE;
            uart_char_index <= 4'd0;
            uart_tx_dv <= 1'b0;
            uart_tx_byte <= 8'd0;
        end else begin
            uart_event_toggle_sync <= {uart_event_toggle_sync[1:0], uart_event_toggle_sys};
            uart_tx_dv <= 1'b0;

            case (uart_state)
                UART_STATE_IDLE: begin
                    if (uart_event_toggle_sync[2] != uart_event_toggle_seen) begin
                        uart_event_toggle_seen <= uart_event_toggle_sync[2];
                        uart_event_match <= uart_event_match_sys;
                        uart_event_idcode <= uart_event_idcode_sys;
                        uart_char_index <= 4'd0;
                        uart_state <= UART_STATE_SEND;
                    end
                end

                UART_STATE_SEND: begin
                    if (!uart_tx_active) begin
                        uart_tx_byte <= uart_status_byte;
                        uart_tx_dv <= 1'b1;
                        uart_state <= UART_STATE_WAIT_DONE;
                    end
                end

                UART_STATE_WAIT_DONE: begin
                    if (uart_tx_done) begin
                        if (uart_char_index == UART_LAST_CHAR_INDEX) begin
                            uart_state <= UART_STATE_IDLE;
                        end else begin
                            uart_char_index <= uart_char_index + 1'b1;
                            uart_state <= UART_STATE_SEND;
                        end
                    end
                end

                default: begin
                    uart_state <= UART_STATE_IDLE;
                end
            endcase
        end
    end


    // JTAG scanner and event FIFO
    JTAG #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .TCK_HZ(JTAG_TCK_HZ),
        .EXPECTED_BOUNDARY_DATA(EXPECTED_BOUNDARY_DATA),
        .BOUNDARY_OPCODE(JTAG_BOUNDARY_OPCODE)
    ) u_jtag (
        .clk(clk_i),
        .rst(rst),
        .start(start_scan),
        .compare_enable(1'b1),

        .tdo(jtag_tdo_i),
        .use_internal_target(1'b1),
        .boundary_inputs(boundary_inputs),
        .boundary_scan_data(8'h00),
        .tck(jtag_tck_o),
        .tms(jtag_tms_o),
        .tdi(jtag_tdi_o),
        .busy(jtag_busy),
        .done(jtag_done),

        .captured_idcode(jtag_idcode),
        .captured_boundary(jtag_boundary_data),
        .id_match(jtag_match),

        .tdo_stuck_high(jtag_tdo_stuck_high),
        .tdo_stuck_low(jtag_tdo_stuck_low),
        .timeout_error(jtag_timeout),

        .jtag_state(jtag_state),
        .event_word(jtag_event_word),
        .event_valid(jtag_event_valid),
        .boundary_i(boundary_i),
        .boundary_j(boundary_j),
        .boundary_tdo(boundary_tdo),
        .boundary_state(boundary_state)
    );

    fifo_event_buffer u_fifo (
        .clk(clk_i),
        .srst(rst),

        .din(jtag_event_word),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),

        .dout(fifo_dout),
        .full(fifo_full),
        .almost_full(fifo_almost_full),
        .empty(fifo_empty),
        .valid(fifo_valid),
        .underflow(fifo_underflow)
    );

    // Status decoding and front-panel indicators
    StatusReg u_status (
        .clk(clk_i),
        .rst(rst),

        .event_valid(jtag_event_valid),
        .event_word(jtag_event_word),

        .scan_busy(jtag_busy),

        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_almost_full(fifo_almost_full),
        .fifo_valid(fifo_valid),
        .fifo_underflow(fifo_underflow),
        .fifo_overflow_attempt(fifo_overflow_attempt),

        .jtag_tck(jtag_tck_o),
        .jtag_tms(jtag_tms_o),
        .jtag_tdi(jtag_tdi_o),
        .jtag_tdo(jtag_tdo_i),

        .latest_idcode(status_idcode),
        .id_match(status_match),
        .scan_done(status_scan_done),
        .tdo_stuck_high(status_tdo_stuck_high),
        .tdo_stuck_low(status_tdo_stuck_low),
        .timeout_error(status_timeout),
        .jtag_state(status_jtag_state),
        .event_type(status_event_type),
        .timestamp(status_timestamp),
        .fifo_underflow_latched(status_fifo_underflow_latched),
        .fifo_overflow_latched(status_fifo_overflow_latched),
        .event_count(status_event_count),
        .status_led_bus(status_led_bus)
    );

    // Front-panel indicators
    assign led_o[0] = jtag_busy;
    assign led_o[1] = status_scan_done;
    assign led_o[2] = status_scan_done && status_match;
    assign led_o[3] = status_scan_done && !status_match;
    assign led_o[4] = status_timeout;
    assign led_o[5] = status_tdo_stuck_low;
    assign led_o[6] = status_tdo_stuck_high;
    assign led_o[7] = fifo_full | status_fifo_overflow_latched;
    assign led_o[11:8] = status_jtag_state;
    assign led_o[12] = uart_tx_active;
    assign led_o[13] = boundary_i;
    assign led_o[14] = boundary_j;
    assign led_o[15] = boundary_tdo;


    // Seven-segment display
    TimeMux #(
        .NUM_DIGITS(8),
        .DIGIT_WIDTH(4),
        .REFRESH_LSB(13),
        .REFRESH_WIDTH(20),
        .DIGIT_SELECT_WIDTH(3)
    ) u_sseg_mux (
        .clk(clk_i),
        .reset(rst),
        .vals(seven_seg_value),
        .seg(seg_nibble),
        .anodes(an_o)
    );

    SevenSegDecoder u_sseg_decoder (
        .reset(rst),
        .val(seg_nibble),
        .anodes(an_o),
        .seg(seg_o)
    );


    // UART IP instances
    uart_tx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) u_uart_tx (
        .i_Clock(uart_clk),
        .i_Tx_DV(uart_tx_dv),
        .i_Tx_Byte(uart_tx_byte),
        .o_Tx_Active(uart_tx_active),
        .o_Tx_Serial(uart_tx_serial),
        .o_Tx_Done(uart_tx_done)
    );

    uart_rx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) u_uart_rx (
        .i_Clock(uart_clk),
        .i_Rx_Serial(uart_rxd_i),
        .o_Rx_DV(uart_rx_valid),
        .o_Rx_Byte(uart_rx_byte)
    );


    // VGA status display
    VGA u_vga (
        .clk(clk_i),
        .rst(rst),
        .idcode(status_idcode),
        .id_match(status_match),
        .scan_done(status_scan_done),
        .scan_busy(jtag_busy),
        .fifo_empty(fifo_empty),
        .fifo_full(fifo_full),
        .fifo_underflow(status_fifo_underflow_latched),
        .fifo_overflow(status_fifo_overflow_latched),
        .jtag_state(status_jtag_state),
        .vga_red(vga_red_o),
        .vga_green(vga_green_o),
        .vga_blue(vga_blue_o),
        .vga_hs(vga_hs_o),
        .vga_vs(vga_vs_o)
    );

endmodule
