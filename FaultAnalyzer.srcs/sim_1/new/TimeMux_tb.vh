`ifndef FAULT_ANALYZER_TB_TIMEMUX_TASK_VH
`define FAULT_ANALYZER_TB_TIMEMUX_TASK_VH

task automatic tb_test_timemux;
  begin
    $display("TEST: TimeMux first digit select");
    tb_timemux_vals = 16'h4321;
    @(negedge tb_clk);
    tb_rst = 1'b1;
    #1;
    tb_rst = 1'b0;
    @(posedge tb_clk);
    #1;
    tb_expect_equal32({28'd0, tb_timemux_seg}, 32'h0000_0001, "TimeMux first nibble");
    tb_expect_equal32({28'd0, tb_timemux_anodes}, 32'h0000_000E, "TimeMux first anode");
  end
endtask

`endif
