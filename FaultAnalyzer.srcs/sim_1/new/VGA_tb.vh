`ifndef FAULT_ANALYZER_TB_VGA_TASK_VH
`define FAULT_ANALYZER_TB_VGA_TASK_VH

task automatic tb_test_vga;
  begin
    $display("TEST: VGA constants");
    tb_expect_equal32(`TB_VGA_H_ACTIVE, 32'd640, "VGA horizontal active pixels");
    tb_expect_equal32(`TB_VGA_V_ACTIVE, 32'd480, "VGA vertical active lines");
  end
endtask

`endif
