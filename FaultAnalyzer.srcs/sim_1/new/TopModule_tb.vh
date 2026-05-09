`ifndef FAULT_ANALYZER_TB_TOPMODULE_TASK_VH
`define FAULT_ANALYZER_TB_TOPMODULE_TASK_VH

task automatic tb_test_topmodule;
  integer char_index;
  reg [7:0] expected_char;
  begin
    $display("TEST: TopModule controls and UART status formatter");

    tb_sw = 16'd0;
    tb_btnc = 1'b0;
    tb_btnu = 1'b0;
    tb_btnl = 1'b0;
    tb_btnr = 1'b0;
    tb_uart_rxd = 1'b1;
    tb_jtag_tdo = 1'b0;
    tb_apply_reset();

    tb_expect_equal32({31'd0, tb_uart_txd}, 32'd1, "TopModule UART TX idle high");
    tb_expect_equal32({31'd0, dut.rst}, 32'd0, "TopModule synchronized reset released");

    tb_btnc = 1'b1;
    tb_wait_cycles(3);
    #1;
    tb_expect_equal32({31'd0, dut.start_scan}, 32'd1, "TopModule start from BTNC");
    tb_btnc = 1'b0;
    tb_wait_cycles(3);

    tb_sw[0] = 1'b1;
    tb_wait_cycles(3);
    #1;
    tb_expect_equal32({31'd0, dut.start_scan}, 32'd1, "TopModule start from SW0");
    tb_sw[0] = 1'b0;
    tb_wait_cycles(3);

    force dut.uart_event_match = 1'b1;
    force dut.uart_event_idcode = `TB_EXPECTED_GOWIN_IDCODE;

    for (char_index = 0; char_index < `TB_UART_STATUS_LENGTH; char_index = char_index + 1) begin
      tb_uart_char_index_force = char_index[3:0];
      force dut.uart_char_index = tb_uart_char_index_force;

      case (char_index)
        0: expected_char = "P";
        1: expected_char = " ";
        2: expected_char = "I";
        3: expected_char = "D";
        4: expected_char = "=";
        5: expected_char = "0";
        6: expected_char = "1";
        7: expected_char = "2";
        8: expected_char = "0";
        9: expected_char = "6";
        10: expected_char = "8";
        11: expected_char = "1";
        12: expected_char = "B";
        13: expected_char = 8'h0D;
        default: expected_char = 8'h0A;
      endcase

      #1;
      tb_expect_equal32({24'd0, dut.uart_status_byte},
                        {24'd0, expected_char},
                        "TopModule UART status byte");
    end

    tb_uart_char_index_force = 4'd0;
    force dut.uart_char_index = tb_uart_char_index_force;
    force dut.uart_event_match = 1'b0;
    #1;
    tb_expect_equal32({24'd0, dut.uart_status_byte}, {24'd0, "F"},
                      "TopModule UART fail status byte");

    release dut.uart_char_index;
    release dut.uart_event_idcode;
    release dut.uart_event_match;
  end
endtask

`endif
