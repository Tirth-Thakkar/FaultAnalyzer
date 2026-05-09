`ifndef FAULT_ANALYZER_TB_LEDSTATUS_TASK_VH
`define FAULT_ANALYZER_TB_LEDSTATUS_TASK_VH

task automatic tb_test_ledstatus;
  begin
    $display("TEST: LedStatus scaffold");
    tb_apply_reset();
  end
endtask

`endif
