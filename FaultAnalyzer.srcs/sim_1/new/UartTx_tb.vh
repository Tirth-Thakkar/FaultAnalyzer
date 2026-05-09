`ifndef FAULT_ANALYZER_TB_UARTTX_TASK_VH
`define FAULT_ANALYZER_TB_UARTTX_TASK_VH

task automatic tb_test_uarttx;
  begin
    $display("TEST: UartTx constants");
    tb_expect_equal32(`TB_UART_BAUD, 32'd115200, "UART baud");
  end
endtask

`endif
