`ifndef FAULT_ANALYZER_TB_VGA_TASK_VH
`define FAULT_ANALYZER_TB_VGA_TASK_VH

task automatic tb_test_vga;
  begin
    $display("TEST: VGA timing parameters and status colors");

    tb_expect_equal32(`TB_VGA_H_ACTIVE, 32'd640, "VGA horizontal active pixels");
    tb_expect_equal32(`TB_VGA_V_ACTIVE, 32'd480, "VGA vertical active lines");

    force dut.u_vga.h_count = 10'd1;
    force dut.u_vga.v_count = 10'd1;
    force dut.u_vga.scan_busy = 1'b1;
    force dut.u_vga.scan_done = 1'b0;
    force dut.u_vga.id_match = 1'b0;
    #1;
    tb_expect_equal32({20'd0, tb_vga_red, tb_vga_green, tb_vga_blue},
                      {20'd0, `TB_VGA_COLOR_SCAN_BUSY},
                      "VGA header busy color");

    force dut.u_vga.scan_busy = 1'b0;
    force dut.u_vga.scan_done = 1'b1;
    force dut.u_vga.id_match = 1'b1;
    #1;
    tb_expect_equal32({20'd0, tb_vga_red, tb_vga_green, tb_vga_blue},
                      {20'd0, `TB_VGA_COLOR_SCAN_PASS},
                      "VGA header pass color");

    force dut.u_vga.h_count = 10'd46;
    force dut.u_vga.v_count = 10'd96;
    force dut.u_vga.idcode = `TB_EXPECTED_GOWIN_IDCODE;
    #1;
    tb_expect_equal32({20'd0, tb_vga_red, tb_vga_green, tb_vga_blue},
                      {20'd0, `TB_VGA_COLOR_IDCODE_OK},
                      "VGA IDCODE digit color");

    release dut.u_vga.h_count;
    release dut.u_vga.v_count;
    release dut.u_vga.scan_busy;
    release dut.u_vga.scan_done;
    release dut.u_vga.id_match;
    release dut.u_vga.idcode;
  end
endtask

`endif
