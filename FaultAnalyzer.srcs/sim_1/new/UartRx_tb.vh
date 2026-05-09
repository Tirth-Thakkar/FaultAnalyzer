`ifndef FAULT_ANALYZER_TB_UARTRX_TASK_VH
`define FAULT_ANALYZER_TB_UARTRX_TASK_VH

task automatic tb_test_uartrx;
  begin
    $display("TEST: UartRx instance parameters");

    tb_expect_equal32(`TB_UART_BAUD, 32'd115200, "UART RX baud");
    tb_expect_equal32(dut.u_uart_rx.CLKS_PER_BIT, `TB_UART_CLKS_PER_BIT,
                      "UART RX CLKS_PER_BIT after TopModule divider");
  end
endtask

`endif
