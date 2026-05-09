`ifndef FAULT_ANALYZER_TB_STATUSREG_TASK_VH
`define FAULT_ANALYZER_TB_STATUSREG_TASK_VH

task automatic tb_test_statusreg;
  begin
    $display("TEST: StatusReg scaffold");
    tb_apply_reset();
  end
endtask

`endif
