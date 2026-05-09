`ifndef FAULT_ANALYZER_TB_FIFO_EVENT_BUFFER_TASK_VH
`define FAULT_ANALYZER_TB_FIFO_EVENT_BUFFER_TASK_VH

task automatic tb_test_fifo_event_buffer;
  begin
    $display("TEST: fifo_event_buffer parameters and top-level gating");

    tb_expect_equal32(`TB_FIFO_EVENT_WIDTH, 32'd64, "FIFO event width");
    tb_expect_equal32(`TB_FIFO_EVENT_DEPTH, 32'd64, "FIFO event depth");

    force dut.jtag_event_valid = 1'b1;
    force dut.fifo_full = 1'b0;
    #1;
    tb_expect_equal32({31'd0, dut.fifo_wr_en}, 32'd1, "FIFO write enabled when not full");
    tb_expect_equal32({31'd0, dut.fifo_overflow_attempt}, 32'd0,
                      "FIFO overflow attempt clear when not full");

    force dut.fifo_full = 1'b1;
    #1;
    tb_expect_equal32({31'd0, dut.fifo_wr_en}, 32'd0, "FIFO write blocked when full");
    tb_expect_equal32({31'd0, dut.fifo_overflow_attempt}, 32'd1,
                      "FIFO overflow attempt generated locally");

    release dut.fifo_full;
    release dut.jtag_event_valid;
  end
endtask

`endif
