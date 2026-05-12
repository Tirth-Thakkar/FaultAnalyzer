`ifndef FAULT_ANALYZER_TB_STATUSREG_TASK_VH
`define FAULT_ANALYZER_TB_STATUSREG_TASK_VH

task automatic tb_test_statusreg;
  begin
    $display("TEST: StatusReg event decode");
    tb_apply_reset();

    tb_status_event_word = {
      `TB_EXPECTED_GOWIN_IDCODE,
      1'b1,
      1'b0,
      1'b0,
      1'b0,
      `TB_JTAG_FINAL_STATE,
      `TB_JTAG_EVENT_TYPE_IDCODE,
      16'h55AA
    };

    force dut.jtag_event_word = tb_status_event_word;
    force dut.jtag_event_valid = 1'b1;
    force dut.jtag_busy = 1'b0;
    force dut.fifo_underflow = 1'b0;
    force dut.fifo_valid = 1'b0;
    force dut.fifo_overflow_attempt = 1'b0;

    @(posedge tb_clk);
    #1;

    tb_expect_equal32(dut.status_idcode, `TB_EXPECTED_GOWIN_IDCODE, "StatusReg latest IDCODE");
    tb_expect_equal32({31'd0, dut.status_match}, 32'd1, "StatusReg match flag");
    tb_expect_equal32({31'd0, dut.status_scan_done}, 32'd1, "StatusReg scan done");
    tb_expect_equal32({24'd0, dut.status_event_type}, {24'd0, `TB_JTAG_EVENT_TYPE_IDCODE},
                      "StatusReg event type");
    tb_expect_equal32({16'd0, dut.u_status.timestamp}, 32'h0000_55AA, "StatusReg timestamp");

    release dut.jtag_event_valid;
    release dut.jtag_event_word;

    force dut.fifo_overflow_attempt = 1'b1;
    @(posedge tb_clk);
    #1;
    tb_expect_equal32({31'd0, dut.status_fifo_overflow_latched}, 32'd1,
                      "StatusReg local overflow latch");

    release dut.jtag_busy;
    release dut.fifo_underflow;
    release dut.fifo_valid;
    release dut.fifo_overflow_attempt;
  end
endtask

`endif
