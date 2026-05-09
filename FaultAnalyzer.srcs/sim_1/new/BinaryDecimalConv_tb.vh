`ifndef FAULT_ANALYZER_TB_BINARYDECIMALCONV_TASK_VH
`define FAULT_ANALYZER_TB_BINARYDECIMALCONV_TASK_VH

task automatic tb_test_binarydecimalconv;
  begin
    $display("TEST: BinaryDecimalConv conversion");
    tb_binary_in = 16'd1234;
    #1;
    tb_expect_equal32({16'd0, tb_decimal_out}, 32'h0000_1234, "binary to packed decimal");
  end
endtask

`endif
