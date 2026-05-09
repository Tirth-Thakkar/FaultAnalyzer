`ifndef FAULT_ANALYZER_TB_UARTRX_TASK_VH
`define FAULT_ANALYZER_TB_UARTRX_TASK_VH

task automatic tb_test_uartrx;
  begin
    $display("TEST: UartRx constants");
    tb_expect_equal32(`TB_UART_BAUD, 32'd115200, "UART RX baud");
  end
endtask

`endif
