`ifndef FAULT_ANALYZER_TB_JTAG_TASK_VH
`define FAULT_ANALYZER_TB_JTAG_TASK_VH

task automatic tb_test_jtag;
  begin
    $display("TEST: JTAG boundary-scan parameters and reset state");

    tb_expect_equal32(dut.u_jtag.TCK_HALF_DIVIDER, `TB_JTAG_TCK_HALF_DIVIDER,
                      "JTAG TCK half divider");
    tb_expect_equal32({24'h0, dut.u_jtag.BOUNDARY_OPCODE}, 32'h0000_0001,
                      "JTAG SAMPLE/PRELOAD opcode");
    tb_expect_equal32(dut.u_jtag.BOUNDARY_REGISTER_BITS, `TB_JTAG_BOUNDARY_BITS,
                      "JTAG BSDL boundary register length");
    tb_expect_equal32(dut.u_jtag.BOUNDARY_PIN_COUNT, `TB_JTAG_BOUNDARY_PIN_COUNT,
                      "JTAG BSDL pin event count");

    tb_apply_reset();
    #1;
    tb_expect_equal32({31'd0, tb_jtag_tck}, 32'd0, "JTAG TCK reset low");
    tb_expect_equal32({31'd0, tb_jtag_tms}, 32'd1, "JTAG TMS reset high");
    tb_expect_equal32({31'd0, tb_jtag_tdi}, 32'd0, "JTAG TDI reset low");
    tb_expect_equal32({31'd0, dut.u_jtag.busy}, 32'd0, "JTAG idle after reset");
    tb_expect_equal32({24'd0, dut.u_jtag.captured_boundary}, 32'd0,
                      "JTAG captured boundary reset clear");
    tb_expect_equal32({28'd0, dut.u_jtag.boundary_state}, 32'd0,
                      "Known boundary target TAP reset state");
  end
endtask

`endif
