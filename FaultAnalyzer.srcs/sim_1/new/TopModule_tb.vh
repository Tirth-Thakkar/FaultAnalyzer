`ifndef FAULT_ANALYZER_TB_TOPMODULE_TASK_VH
`define FAULT_ANALYZER_TB_TOPMODULE_TASK_VH

task automatic tb_test_topmodule;
  begin
    $display("TEST: TopModule scaffold");
    tb_apply_reset();
  end
endtask

`endif
