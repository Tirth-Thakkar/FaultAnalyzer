`ifndef FAULT_ANALYZER_TB_FIFO_EVENT_BUFFER_TASK_VH
`define FAULT_ANALYZER_TB_FIFO_EVENT_BUFFER_TASK_VH

task automatic tb_test_fifo_event_buffer;
  begin
    $display("TEST: fifo_event_buffer constants");
    tb_expect_equal32(`TB_FIFO_EVENT_WIDTH, 32'd64, "FIFO event width");
    tb_expect_equal32(`TB_FIFO_EVENT_DEPTH, 32'd64, "FIFO event depth");
  end
endtask

`endif
