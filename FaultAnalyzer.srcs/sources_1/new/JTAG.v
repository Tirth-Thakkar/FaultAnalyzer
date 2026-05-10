`timescale 1ns / 1ps

module JTAG #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TCK_HZ = 2_000_000,
    parameter [7:0] EXPECTED_BOUNDARY_DATA = 8'h00,
    parameter [1:0] BOUNDARY_OPCODE = 2'b01,
    parameter integer TIMEOUT_CYCLES = 1_000_000
) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire compare_enable,
    input wire tdo,
    input wire use_internal_target,
    input wire [3:0] boundary_inputs,
    input wire [7:0] boundary_scan_data,

    output wire tck,
    output reg tms,
    output reg tdi,
    output reg busy,
    output reg done,
    output reg [31:0] captured_idcode,
    output reg [7:0] captured_boundary,
    output reg id_match,
    output reg tdo_stuck_high,
    output reg tdo_stuck_low,
    output reg timeout_error,
    output reg [3:0] jtag_state,
    output reg [63:0] event_word,
    output reg event_valid,
    output wire boundary_i,
    output wire boundary_j,
    output wire boundary_tdo,
    output wire [3:0] boundary_state
);


    // TCK generation
    localparam integer TCK_EDGES_PER_PERIOD = 2;
    localparam integer TCK_HALF_DIVIDER = CLK_FREQ_HZ / (TCK_HZ * TCK_EDGES_PER_PERIOD);
    localparam integer TCK_DIVIDER_WIDTH = 16;


    // TAP scan dimensions
    localparam integer TAP_RESET_TCKS = 5;
    localparam integer POST_IR_IDLE_TCKS = 3;
    localparam integer IR_BIT_COUNT = 2;
    localparam integer DR_BOUNDARY_BIT_COUNT = 8;

    localparam [5:0] IR_LAST_BIT_INDEX = IR_BIT_COUNT - 1;
    localparam [5:0] IR_NEXT_TO_LAST_BIT_INDEX = IR_BIT_COUNT - 2;
    localparam [5:0] DR_LAST_BIT_INDEX = DR_BOUNDARY_BIT_COUNT - 1;
    localparam [5:0] DR_NEXT_TO_LAST_BIT_INDEX = DR_BOUNDARY_BIT_COUNT - 2;

    localparam [3:0] RESET_LAST_COUNT = TAP_RESET_TCKS - 1;
    localparam [1:0] POST_IR_IDLE_LAST_COUNT = POST_IR_IDLE_TCKS - 1;


    // Event encoding
    localparam [7:0] EVENT_TYPE_BOUNDARY = 8'h02;
    localparam [7:0] EVENT_TYPE_TIMEOUT = 8'hEE;

    // JTAG TAP sequencing states
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

    // TAP state and counters
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


    // Synchronized TDO input
    reg tdo_meta;
    reg tdo_sync;


    // Derived control signals
    wire tck_half_tick;
    wire tck_rising_edge;
    wire tck_falling_edge;
    wire effective_match;
    wire selected_tdo;

    assign tck = tck_reg;
    assign tck_half_tick = (tck_divider_count == (TCK_HALF_DIVIDER - 1));
    assign tck_rising_edge = tck_half_tick && !tck_reg;
    assign tck_falling_edge = tck_half_tick && tck_reg;
    assign effective_match = compare_enable ? (captured_boundary == EXPECTED_BOUNDARY_DATA) : 1'b1;
    assign selected_tdo = use_internal_target ? boundary_tdo : tdo;

    JTAG_READY_IC u_known_boundary_target (
        .TDI(tdi),
        .TCK(tck_reg),
        .TMS(tms),
        .TRST(rst),
        .a(boundary_inputs[0]),
        .b(boundary_inputs[1]),
        .c(boundary_inputs[2]),
        .d(boundary_inputs[3]),
        .i(boundary_i),
        .j(boundary_j),
        .TDO(boundary_tdo),
        .STATE(boundary_state)
    );

    always @(posedge clk) begin : proc_tdo_synchronizer
        if (rst) begin
            tdo_meta <= 1'b0;
            tdo_sync <= 1'b0;
        end else begin
            tdo_meta <= selected_tdo;
            tdo_sync <= tdo_meta;
        end
    end

    always @(posedge clk) begin : proc_jtag_boundary_scan
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
            captured_boundary <= 8'd0;
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
                captured_idcode <= {24'd0, captured_boundary};
                event_word <= {
                    24'd0,
                    captured_boundary,
                    1'b0,
                    tdo_seen_all_one,
                    ~tdo_seen_one,
                    1'b1,
                    state,
                    EVENT_TYPE_TIMEOUT,
                    timestamp
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
                    captured_boundary <= 8'd0;
                    tdo_seen_one <= 1'b0;
                    tdo_seen_all_one <= 1'b1;
                    tdo_stuck_high <= 1'b0;
                    tdo_stuck_low <= 1'b0;
                    timeout_error <= 1'b0;
                    done <= 1'b0;
                end
            end else begin
                if (tck_rising_edge && state == ST_DR_SHIFT) begin
                    captured_boundary[shift_count] <= tdo_sync;
                    tdo_seen_one <= tdo_seen_one | tdo_sync;
                    tdo_seen_all_one <= tdo_seen_all_one & tdo_sync;
                end

                if (tck_falling_edge) begin
                    case (state)
                        ST_RESET: begin
                            tms <= 1'b1;
                            tdi <= 1'b0;

                            if (reset_count == RESET_LAST_COUNT) begin
                                state <= ST_RUN_IDLE;
                                tms <= 1'b0;
                            end else begin
                                reset_count <= reset_count + 1'b1;
                            end
                        end

                        ST_RUN_IDLE: begin
                            state <= ST_IR_SELECT_DR;
                            tms <= 1'b1;
                            tdi <= 1'b0;
                        end

                        ST_IR_SELECT_DR: begin
                            state <= ST_IR_SELECT_IR;
                            tms <= 1'b1;
                        end

                        ST_IR_SELECT_IR: begin
                            state <= ST_IR_CAPTURE;
                            tms <= 1'b0;
                        end

                        ST_IR_CAPTURE: begin
                            state <= ST_IR_SHIFT;
                            shift_count <= 6'd0;
                            tdi <= BOUNDARY_OPCODE[0];
                            tms <= 1'b0;
                        end

                        ST_IR_SHIFT: begin
                            if (shift_count == IR_LAST_BIT_INDEX) begin
                                state <= ST_IR_EXIT1;
                                tms <= 1'b1;
                                tdi <= 1'b0;
                            end else begin
                                shift_count <= shift_count + 1'b1;
                                tdi <= BOUNDARY_OPCODE[shift_count+1'b1];
                                tms <= (shift_count == IR_NEXT_TO_LAST_BIT_INDEX);
                            end
                        end

                        ST_IR_EXIT1: begin
                            state <= ST_IR_UPDATE;
                            tms <= 1'b0;
                        end

                        ST_IR_UPDATE: begin
                            state <= ST_POST_IR_IDLE;
                            idle_count <= 2'd0;
                            tms <= 1'b0;
                        end

                        ST_POST_IR_IDLE: begin
                            tms <= 1'b0;

                            if (idle_count == POST_IR_IDLE_LAST_COUNT) begin
                                state <= ST_DR_SELECT;
                                tms <= 1'b1;
                            end else begin
                                idle_count <= idle_count + 1'b1;
                            end
                        end

                        ST_DR_SELECT: begin
                            state <= ST_DR_CAPTURE;
                            tms <= 1'b0;
                        end

                        ST_DR_CAPTURE: begin
                            state <= ST_DR_SHIFT;
                            shift_count <= 6'd0;
                            tdi <= boundary_scan_data[0];
                            tms <= 1'b0;
                            tdo_seen_one <= 1'b0;
                            tdo_seen_all_one <= 1'b1;
                        end

                        ST_DR_SHIFT: begin
                            if (shift_count == DR_LAST_BIT_INDEX) begin
                                state <= ST_DR_EXIT1;
                                tms <= 1'b1;
                                tdi <= 1'b0;
                            end else begin
                                shift_count <= shift_count + 1'b1;
                                tdi <= boundary_scan_data[shift_count+1'b1];
                                tms <= (shift_count == DR_NEXT_TO_LAST_BIT_INDEX);
                            end
                        end

                        ST_DR_EXIT1: begin
                            state <= ST_DR_UPDATE;
                            tms <= 1'b0;
                        end

                        ST_DR_UPDATE: begin
                            state <= ST_FINISH;
                            tms <= 1'b0;
                        end

                        ST_FINISH: begin
                            state <= ST_IDLE;
                            busy <= 1'b0;
                            done <= 1'b1;
                            captured_idcode <= {24'd0, captured_boundary};
                            id_match <= effective_match;
                            tdo_stuck_high <= tdo_seen_all_one;
                            tdo_stuck_low <= ~tdo_seen_one;
                            timeout_error <= 1'b0;
                            event_word <= {
                                24'd0,
                                captured_boundary,
                                effective_match,
                                tdo_seen_all_one,
                                ~tdo_seen_one,
                                1'b0,
                                ST_FINISH,
                                EVENT_TYPE_BOUNDARY,
                                timestamp
                            };
                            event_valid <= 1'b1;
                        end

                        default: begin
                            state <= ST_IDLE;
                            busy <= 1'b0;
                        end
                    endcase
                end
            end
        end
    end

endmodule

module JTAG_READY_IC(TDI,TCK,TMS,TRST,a,b,c,d,i,j,TDO,STATE);
    // ports for the JTAG ready ic
    input TDI,TCK,TMS,TRST,a,b,c,d;
    output i,j,TDO;
    output[3:0] STATE;

    // wires to wire up tap controller signals with JTAG_READY_CUT
    wire ShiftIR,CaptureIR,UpdateIR;
    wire ShiftDR,CaptureDR,UpdateDR;
    wire ClockIR,ClockDR;

    // wire bus to wire instruction port of the TAP_CONTROLLER_FSM
    wire[1:0] Instruction;

    // instruction decode logic based on instruction bus
    // to set mode and MUX_OUT_SEL
    localparam [1:0] BYPASS = 2'b00, SAMPLE = 2'b01, EXTEST = 2'b10;
    wire MUX_OUT_SEL;
    wire Mode;
    wire instr_bypass = (Instruction == BYPASS);
    wire instr_sample = (Instruction == SAMPLE);
    wire instr_exttest = (Instruction == EXTEST);
    assign MUX_OUT_SEL = instr_sample | instr_exttest;
    assign Mode = instr_exttest;

    // output mux to select between cut output or IR output
    wire ir_tdo;
    wire cut_mux_out;
    wire select;
    assign select=(ShiftIR==1 || CaptureIR==1 || UpdateIR==1);
    wire mux_ir_cut;
    assign mux_ir_cut=(select)?ir_tdo:cut_mux_out;

    // negative edge output FF declaration and wiring
    reg ff;
    assign TDO = ff;
    always @(negedge TCK or posedge TRST) begin
        if(TRST) ff<=0;
        else begin
            ff<=mux_ir_cut;
        end
    end

    // wiring up the tap controller IO
    TAP_CONTROLLER_FSM tap_controller(
        .TCK(TCK),
        .TMS(TMS),
        .TRST(TRST),
        .STATE(STATE),
        .ShiftIR(ShiftIR),
        .CaptureIR(CaptureIR),
        .UpdateIR(UpdateIR),
        .ShiftDR(ShiftDR),
        .CaptureDR(CaptureDR),
        .UpdateDR(UpdateDR),
        .ClockDR(ClockDR),
        .ClockIR(ClockIR)
    );

    // wiring up the cut JTAG_READY_CUT
    JTAG_READY_CUT cut(
        .TRST(TRST),
        .TDI(TDI),
        .ShiftDR(ShiftDR),
        .ClockDR(ClockDR),
        .UpdateDR(UpdateDR),
        .CaptureDR(CaptureDR),
        .Mode(Mode),
        .MUX_OUT_SEL(MUX_OUT_SEL),
        .a(a),
        .b(b),
        .c(c),
        .d(d),
        .i(i),
        .j(j),
        .MUX_OUT(cut_mux_out)
    );

    // LSB-first
    // wiring up 2 bit instruction register
    IR_2b ir(
        .TRST(TRST),
        .TDI(TDI),
        .ShiftIR(ShiftIR),
        .ClockIR(ClockIR),
        .UpdateIR(UpdateIR),
        .TDO(ir_tdo),
        .INSTR(Instruction)
    );
endmodule

module TAP_CONTROLLER_FSM( TCK, TMS, TRST, STATE, ShiftIR, CaptureIR, UpdateIR, ClockIR, ShiftDR, CaptureDR, UpdateDR, ClockDR );
    // Defining known FSM states
    localparam TEST_LOGIC_RESET=4'd0;
    localparam RUN_TEST_IDLE =4'd1;
    localparam SELECT_DR_SCAN =4'd2;
    localparam CAPTURE_DR =4'd3;
    localparam SHIFT_DR =4'd4;
    localparam EXIT1_DR =4'd5;
    localparam PAUSE1_DR =4'd6;
    localparam EXIT2_DR =4'd7;
    localparam UPDATE_DR =4'd8;
    localparam SELECT_IR_SCAN =4'd9;
    localparam CAPTURE_IR =4'd10;
    localparam SHIFT_IR =4'd11;
    localparam EXIT1_IR =4'd12;
    localparam PAUSE1_IR =4'd13;
    localparam EXIT2_IR =4'd14;
    localparam UPDATE_IR =4'd15;

    // Defining necessary ports
    input TCK,TMS,TRST;
    output[3:0] STATE;

    // addition of control signal ports
    output ShiftIR,CaptureIR,UpdateIR,ClockIR;
    output ShiftDR,CaptureDR,UpdateDR,ClockDR;

    // Defining FSM memory
    reg[3:0] tap_state;

    // Assigning STATE output to FSM Memory
    assign STATE=tap_state;

    // Assigning FSM control signals
    assign ShiftIR=(tap_state==SHIFT_IR);
    assign CaptureIR=(tap_state==CAPTURE_IR || tap_state==SHIFT_IR);
    assign UpdateIR=(tap_state==UPDATE_IR);
    assign ShiftDR=(tap_state==SHIFT_DR);
    assign CaptureDR=(tap_state==CAPTURE_DR || tap_state==SHIFT_DR)?1'b1:1'b0;
    assign UpdateDR=(tap_state==UPDATE_DR);

    // enable clock for BSC and IR cell shifts
    assign ClockDR=(tap_state==SHIFT_DR)?TCK:1'b0;
    assign ClockIR=(tap_state==SHIFT_IR)?TCK:1'b0;

    // always block for TCK and TRST
    always @ (posedge TCK or posedge TRST) begin
        // if asyn TRST set tap_state to 0
        if (TRST) tap_state<=0;
        else begin
            // switch case for FSM implementation
            case(tap_state)
                TEST_LOGIC_RESET: tap_state<=(TMS)?TEST_LOGIC_RESET:RUN_TEST_IDLE;
                RUN_TEST_IDLE: tap_state<=(TMS)?SELECT_DR_SCAN:RUN_TEST_IDLE;
                SELECT_DR_SCAN: tap_state<=(TMS)?SELECT_IR_SCAN:CAPTURE_DR;
                CAPTURE_DR: tap_state<=(TMS)?EXIT1_DR:SHIFT_DR;
                SHIFT_DR: tap_state<=(TMS)?EXIT1_DR:SHIFT_DR;
                EXIT1_DR: tap_state<=(TMS)?UPDATE_DR:PAUSE1_DR;
                PAUSE1_DR: tap_state<=(TMS)?EXIT2_DR:PAUSE1_DR;
                EXIT2_DR: tap_state<=(TMS)?UPDATE_DR:RUN_TEST_IDLE;
                UPDATE_DR: tap_state<=(TMS)?SELECT_DR_SCAN:RUN_TEST_IDLE;
                SELECT_IR_SCAN: tap_state<=(TMS)?TEST_LOGIC_RESET:CAPTURE_IR;
                CAPTURE_IR: tap_state<=(TMS)?EXIT1_IR:SHIFT_IR;
                SHIFT_IR: tap_state<=(TMS)?EXIT1_IR:SHIFT_IR;
                EXIT1_IR: tap_state<=(TMS)?UPDATE_IR:PAUSE1_IR;
                PAUSE1_IR: tap_state<=(TMS)?EXIT2_IR:PAUSE1_IR;
                EXIT2_IR: tap_state<=(TMS)?UPDATE_IR:SHIFT_IR;
                UPDATE_IR: tap_state<=(TMS)?SELECT_DR_SCAN:RUN_TEST_IDLE;
                default: tap_state<= TEST_LOGIC_RESET;
            endcase
        end
    end
endmodule

module IR_2b(TRST,TDI,ShiftIR,ClockIR,UpdateIR,TDO,INSTR);
    // declaration of necessary ports for 2bit IR
    input TRST,TDI,ShiftIR,ClockIR,UpdateIR;
    output TDO;
    output[1:0] INSTR;

    // wire to connect ir0 with ir1
    wire tdo1_tdi0;
    wire Data;

    // data BUS is not needed
    assign Data=0;

    // wiring up ir modules
    IR ir1(TRST,Data, TDI, ShiftIR, ClockIR, UpdateIR, INSTR[1], tdo1_tdi0);
    IR ir0(TRST,Data, tdo1_tdi0, ShiftIR, ClockIR, UpdateIR, INSTR[0], TDO);
endmodule

module IR(TRST,Data, TDI, ShiftIR, ClockIR, UpdateIR, ParallelOut, TDO);
    input TRST,Data, TDI, ShiftIR, ClockIR, UpdateIR;
    output ParallelOut, TDO;
    wire Data, TDI, ShiftIR, ClockIR, UpdateIR, ParallelOut,TDO;
    reg SRFFQ, LFFQ;
    wire DfromMux;

    //here we create the Mux
    assign DfromMux=(ShiftIR)?TDI:Data;
    assign TDO=SRFFQ;
    assign ParallelOut=LFFQ;

    //here we create the SRFF
    always @ (posedge ClockIR or posedge TRST) begin
        if (TRST) SRFFQ<=0;
        else begin
            SRFFQ<=DfromMux;
        end
    end

    //here we create the LFF
    always @ (posedge UpdateIR or posedge TRST) begin
        if (TRST) LFFQ<=0;
        else begin
            LFFQ<=SRFFQ;
        end
    end
endmodule

module JTAG_READY_CUT(TRST,TDI,ShiftDR,ClockDR,UpdateDR,CaptureDR,Mode,MUX_OUT_SEL,a,b,c,d,i,j,MUX_OUT);
    // direct interface IO for the CUT
    input a,b,c,d;
    output i,j;

    // JTAG related IO
    input TRST,TDI,ShiftDR,ClockDR,UpdateDR,CaptureDR,Mode,MUX_OUT_SEL;
    output MUX_OUT;

    // wire for JTAG related blocks
    wire br_tdo,SO;

    // wires to wire up BSC to BSC
    wire bsca_bscb,bscb_bscc,bscc_bscd,bscd_bsci,bsci_bscj;

    // wires to wire up BSC to cut
    wire bsc_cut_a,bsc_cut_b,bsc_cut_c,bsc_cut_d;

    // wires to wire up cut to BSC
    wire cut_bsc_i,cut_bsc_j;

    // BSC for CUT inputs
    BSC bsc_a(TRST,a,TDI,ShiftDR,ClockDR,UpdateDR,Mode,bsca_bscb,bsc_cut_a);
    BSC bsc_b(TRST,b,bsca_bscb,ShiftDR,ClockDR,UpdateDR,Mode,bscb_bscc,bsc_cut_b);
    BSC bsc_c(TRST,c,bscb_bscc,ShiftDR,ClockDR,UpdateDR,Mode,bscc_bscd,bsc_cut_c);
    BSC bsc_d(TRST,d,bscc_bscd,ShiftDR,ClockDR,UpdateDR,Mode,bscd_bsci,bsc_cut_d);

    // BSC for CUT outputs - mode set to 0 just to get cut output response
    BSC bsc_i(TRST,cut_bsc_i,bscd_bsci,ShiftDR,ClockDR,UpdateDR,1'b0,bsci_bscj,i);
    BSC bsc_j(TRST,cut_bsc_j,bsci_bscj,ShiftDR,ClockDR,UpdateDR,1'b0,SO,j);

    // BR wire up
    BR br(ClockDR,TDI,CaptureDR,br_tdo);

    // CUT wire up
    CUT u_cut(bsc_cut_a,bsc_cut_b,bsc_cut_c,bsc_cut_d,cut_bsc_i,cut_bsc_j);

    // assigning mux output 1: bsc_j_SO 0:BYPASS
    assign MUX_OUT=(MUX_OUT_SEL)?SO:br_tdo;
endmodule

module BSC(TRST,DI,SI,ShiftDR,ClockDR,UpdateDR,Mode,SO,DO);
    // Defining necessary ports
    input TRST,DI,SI,ShiftDR,ClockDR,UpdateDR,Mode;
    output SO,DO;

    // Defining internal BSC regs
    reg CAP,UPD;

    // Defining wiring for internal connections
    wire mux_to_cap,cap_to_upd,upd_to_mux;

    // assign mux in
    assign mux_to_cap=(ShiftDR)?SI:DI;

    // assign cap output
    assign cap_to_upd=CAP;

    // assign mux out
    assign DO=(Mode)?upd_to_mux:DI;

    // assign upd to mux
    assign upd_to_mux=UPD;

    // Assign Shift out
    assign SO=cap_to_upd;

    // always block for CAP DFF
    always @ (posedge ClockDR or posedge TRST) begin
        if (TRST) CAP<=0;
        else begin
            CAP<=mux_to_cap;
        end
    end

    // always block for UPD DFF
    always @ (posedge UpdateDR or posedge TRST) begin
        if (TRST) UPD<=0;
        else begin
            UPD<=cap_to_upd;
        end
    end
endmodule

module BR(ClockDR,TDI,CaptureDR,TDO);
    // Defining necessary ports
    input ClockDR,TDI,CaptureDR;
    output TDO;

    // Defining wiring for internal connections
    wire tdi_and_captureDR;

    // Defining internal BR reg
    reg tdo_dff;

    // assign AND gate
    assign tdi_and_captureDR = TDI&CaptureDR;

    // assign TDO
    assign TDO = tdo_dff;

    // always block for TDO DFF
    always @ (posedge ClockDR) begin
        tdo_dff<=tdi_and_captureDR;
    end
endmodule

module CUT(a,b,c,d,i,j);
    input a,b,c,d;
    output i,j;

    assign i = (a & b) | c;
    assign j = (c ^ d) | a;
endmodule
