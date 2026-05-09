`ifndef FAULT_ANALYZER_TB_SEVENSEGDECODER_TASK_VH
`define FAULT_ANALYZER_TB_SEVENSEGDECODER_TASK_VH

task automatic tb_test_sevensegdecoder;
  begin
    $display("TEST: SevenSegDecoder hex decode");
    tb_sseg_reset = 1'b0;
    tb_sseg_anodes = 8'b1111_1110;
    tb_sseg_val = 4'hA;
    #1;
    tb_expect_equal32({25'd0, tb_sseg_seg}, 32'h0000_0008, "seven-seg A pattern");
  end
endtask

`endif
