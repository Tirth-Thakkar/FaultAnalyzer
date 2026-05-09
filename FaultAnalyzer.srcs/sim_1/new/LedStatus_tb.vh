`ifndef FAULT_ANALYZER_TB_LEDSTATUS_TASK_VH
`define FAULT_ANALYZER_TB_LEDSTATUS_TASK_VH

task automatic tb_test_ledstatus;
  begin
    $display("TEST: LedStatus bit mapping");

    force dut.status_scan_done = 1'b1;
    force dut.status_match = 1'b1;
    force dut.fifo_empty = 1'b0;
    force dut.fifo_full = 1'b1;
    force dut.status_fifo_underflow_latched = 1'b1;
    force dut.status_fifo_overflow_latched = 1'b0;
    force dut.uart_tx_active = 1'b1;
    force dut.status_jtag_state = 4'hA;
    force dut.jtag_tck_o = 1'b1;
    force dut.jtag_tms_o = 1'b0;
    force dut.jtag_tdi_o = 1'b1;
    force dut.jtag_tdo_i = 1'b0;

    #1;
    tb_expect_equal32({16'd0, tb_led}, 32'h0000_5AD3, "LedStatus packed LED bus");

    release dut.status_scan_done;
    release dut.status_match;
    release dut.fifo_empty;
    release dut.fifo_full;
    release dut.status_fifo_underflow_latched;
    release dut.status_fifo_overflow_latched;
    release dut.uart_tx_active;
    release dut.status_jtag_state;
    release dut.jtag_tck_o;
    release dut.jtag_tms_o;
    release dut.jtag_tdi_o;
    release dut.jtag_tdo_i;
  end
endtask

`endif
