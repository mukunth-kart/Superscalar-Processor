`timescale 1ns / 1ps

module tb_pravah_top;

  reg clk = 0;
  reg reset = 1;

  // Clock generation: 10ns period (100 MHz)
  always #5 clk = ~clk;

  // Instantiate the top module
  pravah_top dut (
      .clk_i  (clk),
      .reset_i(reset)
  );

  // Load instruction memory and handle reset
  initial begin
    // NOTE: Make sure the hierarchical path matches your fetch module's memory array name!
    $readmemh("../../programs/dot_product.hex", dut.u_fetch.imem);

    #20 reset = 0;

    // Failsafe timeout
    #2000 $finish;
  end

  // Display every commit for debugging and verification
  always @(posedge clk) begin
    if (dut.u_rob.do_commit_A) begin
      $display("Cycle %0d: COMMIT slot A: rob_idx=%0d, arch=%0d, phys=%0d, val=%0d", $time,
               dut.u_rob.head, dut.u_rob.rob_arch_dest[dut.u_rob.head],
               dut.u_rob.rob_phys_dest[dut.u_rob.head],
               dut.u_prf.regs[dut.u_rob.rob_phys_dest[dut.u_rob.head]]);
    end

    if (dut.u_rob.do_commit_B) begin
      $display("Cycle %0d: COMMIT slot B: rob_idx=%0d, arch=%0d, phys=%0d, val=%0d", $time,
               dut.u_rob.head1_idx, dut.u_rob.rob_arch_dest[dut.u_rob.head1_idx],
               dut.u_rob.rob_phys_dest[dut.u_rob.head1_idx],
               dut.u_prf.regs[dut.u_rob.rob_phys_dest[dut.u_rob.head1_idx]]);
    end
  end

  // At the end, verify the architectural register file by reading via rename map
  initial begin
    // Wait long enough for the program to finish executing
    #1500;

    $display("\n========================================");
    $display("Final architectural state:");
    $display("========================================");

    // NOTE: Make sure 'rename_map' and 'regs' match the exact array names 
    // in your Week 5 rename_unit.v and Week 3 register_file.v
    $display("  x1 = %0d (expected 2)", dut.u_prf.regs[dut.u_rename.rename_map[1]]);
    $display("  x2 = %0d (expected 3)", dut.u_prf.regs[dut.u_rename.rename_map[2]]);
    $display("  x3 = %0d (expected 5)", dut.u_prf.regs[dut.u_rename.rename_map[3]]);
    $display("  x4 = %0d (expected 7)", dut.u_prf.regs[dut.u_rename.rename_map[4]]);
    $display("  x5 = %0d (expected 34)", dut.u_prf.regs[dut.u_rename.rename_map[5]]);
    $display("  x6 = %0d (expected 36)", dut.u_prf.regs[dut.u_rename.rename_map[6]]);
    $display("  x7 = %0d (expected 17)", dut.u_prf.regs[dut.u_rename.rename_map[7]]);

    $display("========================================");
    $finish;
  end

endmodule
