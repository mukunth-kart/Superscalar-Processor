`timescale 1ns / 1ps

module tb_pravah_perf;

  reg clk = 0, reset = 1;
  always #5 clk = ~clk;

  // Instantiate top
  pravah_top dut (
      .clk_i  (clk),
      .reset_i(reset)
  );

  // Load instruction memory
  initial begin
    $readmemh("../programs/bench_mixed.hex", dut.u_fetch.imem);
    // change this line for each benchmark
    #20 reset = 0;
  end

  // -----------------------------------------------
  // Cycle and commit counters
  // -----------------------------------------------
  integer cycle_count = 0;
  integer commit_count = 0;
  integer first_commit_cycle = -1;
  integer last_commit_cycle = 0;

  // Count every cycle after reset releases
  always @(posedge clk) begin
    if (~reset) cycle_count <= cycle_count + 1;
  end

  // Count every committed instruction
  always @(posedge clk) begin
    if (~reset) begin

      // 1. Update cycle markers if AT LEAST ONE commit happened
      if (dut.u_rob.commit_A_valid_o || dut.u_rob.commit_B_valid_o) begin
        if (first_commit_cycle < 0) first_commit_cycle <= cycle_count;
        last_commit_cycle <= cycle_count;
      end

      // 2. Increment commit count safely based on how many valid signals we have
      if (dut.u_rob.commit_A_valid_o && dut.u_rob.commit_B_valid_o) begin
        commit_count <= commit_count + 2;  // Both slots committed!
      end else if (dut.u_rob.commit_A_valid_o || dut.u_rob.commit_B_valid_o) begin
        commit_count <= commit_count + 1;  // Only one slot committed
      end

    end
  end

  // -----------------------------------------------
  // Final report
  // -----------------------------------------------
  initial begin
    #5000;  // run long enough for all instructions to commit
    $display("==========================================");
    $display("  PRAVAH Performance Report");
    $display("==========================================");
    $display("  Instructions committed : %0d", commit_count);
    $display("  Total cycles (reset to last commit) : %0d", last_commit_cycle);
    $display("  Cycles in steady state : %0d", last_commit_cycle - first_commit_cycle + 1);
    $display("  End-to-end IPC  = %f", commit_count * 1.0 / last_commit_cycle);
    $display("  Steady-state IPC = %f",
             commit_count * 1.0 / (last_commit_cycle - first_commit_cycle + 1));
    $display("==========================================");
    $finish;
  end

endmodule
