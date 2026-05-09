`ifndef FAULT_ANALYZER_TB_UARTTX_TASK_VH
`define FAULT_ANALYZER_TB_UARTTX_TASK_VH

task automatic tb_test_uarttx;
  begin
    $display("TEST: UartTx instance parameters");

    tb_expect_equal32(`TB_UART_BAUD, 32'd115200, "UART baud");
    tb_expect_equal32(dut.u_uart_tx.CLKS_PER_BIT, `TB_UART_CLKS_PER_BIT,
                      "UART TX CLKS_PER_BIT after TopModule divider");
    tb_expect_equal32({31'd0, tb_uart_txd}, 32'd1, "UART TX serial idle high");
  end
endtask

`endif
