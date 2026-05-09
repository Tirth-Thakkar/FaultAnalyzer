`ifndef FAULT_ANALYZER_TB_JTAG_TASK_VH
`define FAULT_ANALYZER_TB_JTAG_TASK_VH

task automatic tb_test_jtag;
  begin
    $display("TEST: JTAG constants");
    tb_expect_equal32(`TB_EXPECTED_GOWIN_IDCODE, 32'h0120_681B, "expected IDCODE constant");
    tb_expect_equal32({24'h0, `TB_JTAG_IDCODE_OPCODE}, 32'h0000_0011,
                      "JTAG IDCODE opcode constant");
    tb_expect_equal32(`TB_JTAG_TCK_HZ, 32'd2000000, "JTAG TCK target");
  end
endtask

`endif
