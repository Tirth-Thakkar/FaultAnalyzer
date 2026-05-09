`ifndef FAULT_ANALYZER_TB_JTAG_TASK_VH
`define FAULT_ANALYZER_TB_JTAG_TASK_VH

task automatic tb_test_jtag;
  begin
    $display("TEST: JTAG parameters and reset state");

    tb_expect_equal32(`TB_EXPECTED_GOWIN_IDCODE, 32'h0120_681B, "expected IDCODE constant");
    tb_expect_equal32({24'h0, `TB_JTAG_IDCODE_OPCODE}, 32'h0000_0011,
                      "JTAG IDCODE opcode constant");
    tb_expect_equal32(`TB_JTAG_TCK_HZ, 32'd2000000, "JTAG TCK target");
    tb_expect_equal32(dut.u_jtag.TCK_HALF_DIVIDER, `TB_JTAG_TCK_HALF_DIVIDER,
                      "JTAG TCK half divider");
    tb_expect_equal32({24'h0, dut.u_jtag.IDCODE_OPCODE}, {24'h0, `TB_JTAG_IDCODE_OPCODE},
                      "JTAG instantiated opcode");

    tb_apply_reset();
    #1;
    tb_expect_equal32({31'd0, tb_jtag_tck}, 32'd0, "JTAG TCK reset low");
    tb_expect_equal32({31'd0, tb_jtag_tms}, 32'd1, "JTAG TMS reset high");
    tb_expect_equal32({31'd0, tb_jtag_tdi}, 32'd0, "JTAG TDI reset low");
    tb_expect_equal32({31'd0, dut.u_jtag.busy}, 32'd0, "JTAG idle after reset");
  end
endtask

`endif
