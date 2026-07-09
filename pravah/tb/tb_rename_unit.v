`timescale 1ns / 1ps

module tb_rename_unit ();

  // DUT signals
  reg clk, reset;
  reg disp_valid;
  reg [4:0] disp_rs1_arch, disp_rs2_arch, disp_rd_arch;
  reg disp_writes_rd;
  wire [5:0] disp_rs1_phys, disp_rs2_phys, disp_rd_phys, disp_rd_old_phys;
  wire stall;
  reg commit_valid;
  reg [5:0] commit_old_phys;

  // Instantiate DUT
  rename_unit dut (
      .clk_i             (clk),
      .reset_i           (reset),
      .disp_valid_i      (disp_valid),
      .disp_rs1_arch_i   (disp_rs1_arch),
      .disp_rs2_arch_i   (disp_rs2_arch),
      .disp_rd_arch_i    (disp_rd_arch),
      .disp_writes_rd_i  (disp_writes_rd),
      .disp_rs1_phys_o   (disp_rs1_phys),
      .disp_rs2_phys_o   (disp_rs2_phys),
      .disp_rd_phys_o    (disp_rd_phys),
      .disp_rd_old_phys_o(disp_rd_old_phys),
      .stall_o           (stall),
      .commit_valid_i    (commit_valid),
      .commit_old_phys_i (commit_old_phys)
  );

  // Clock
  always #5 clk = ~clk;

  // Error counter
  integer errors = 0;
  integer k;

  // Self-checking helpers
  task check_val;
    input [31:0] actual;
    input [31:0] expected;
    input [255:0] label;
    begin
      if (actual === expected) $display("PASS: %s (got %0d)", label, actual);
      else begin
        $display("FAIL: %s (expected %0d, got %0d)", label, expected, actual);
        errors = errors + 1;
      end
    end
  endtask

  task check_bit;
    input actual;
    input expected;
    input [255:0] label;
    begin
      if (actual === expected) $display("PASS: %s (got %b)", label, actual);
      else begin
        $display("FAIL: %s (expected %b, got %b)", label, expected, actual);
        errors = errors + 1;
      end
    end
  endtask

  // Helper: issue a dispatching instruction and wait one cycle
  task dispatch_write;
    input [4:0] rd_arch;
    input [4:0] rs1_arch;
    input [4:0] rs2_arch;
    begin
      @(posedge clk);
      disp_valid    <= 1;
      disp_writes_rd <= 1;
      disp_rd_arch  <= rd_arch;
      disp_rs1_arch <= rs1_arch;
      disp_rs2_arch <= rs2_arch;
      commit_valid  <= 0;
    end
  endtask

  task dispatch_nowrite;
    input [4:0] rs1_arch;
    input [4:0] rs2_arch;
    begin
      @(posedge clk);
      disp_valid    <= 1;
      disp_writes_rd <= 0;
      disp_rs1_arch <= rs1_arch;
      disp_rs2_arch <= rs2_arch;
      disp_rd_arch  <= 0;
      commit_valid  <= 0;
    end
  endtask

  task idle;
    begin
      @(posedge clk);
      disp_valid    <= 0;
      disp_writes_rd <= 0;
      commit_valid  <= 0;
    end
  endtask

  initial begin
    // ----------------------------------------------------------------
    // Initialization
    // ----------------------------------------------------------------
    clk             = 0;
    reset           = 1;
    disp_valid      = 0;
    disp_writes_rd  = 0;
    disp_rd_arch    = 0;
    disp_rs1_arch   = 0;
    disp_rs2_arch   = 0;
    commit_valid    = 0;
    commit_old_phys = 0;

    // Hold reset for a few cycles
    repeat (4) @(posedge clk);
    @(posedge clk);
    reset = 0;
    @(posedge clk);  // settle

    // ================================================================
    // TEST 1: Reset state
    // rename_map[i] = i for all i in [0,31]
    // free list has 16 entries (fl_count = 16)
    // ================================================================
    $display("\n--- TEST 1: Reset State ---");

    // Check a few rename map entries via source lookups
    // Since reads are combinational, set arch addr and check phys output
    disp_valid    = 1;
    disp_writes_rd = 0;

    disp_rs1_arch = 5'd0;
    disp_rs2_arch = 5'd1;
    #1;
    check_val(disp_rs1_phys, 6'd0, "Reset: map[0] = P0");
    check_val(disp_rs2_phys, 6'd1, "Reset: map[1] = P1");

    disp_rs1_arch = 5'd3;
    disp_rs2_arch = 5'd31;
    #1;
    check_val(disp_rs1_phys, 6'd3, "Reset: map[3] = P3");
    check_val(disp_rs2_phys, 6'd31, "Reset: map[31] = P31");

    // Check first free phys = P32 (head of free list)
    disp_rd_arch   = 5'd0;
    disp_writes_rd = 1;
    #1;
    check_val(disp_rd_phys, 6'd32, "Reset: first free phys = P32");

    // Stall should be 0 (free list not empty)
    check_bit(stall, 1'b0, "Reset: stall = 0");

    disp_valid    = 0;
    disp_writes_rd = 0;

    // ================================================================
    // TEST 2: Single dispatch writing R3
    // expect: disp_rd_phys = P32, disp_rd_old_phys = P3
    // ================================================================
    $display("\n--- TEST 2: Single Dispatch Writing R3 ---");

    // Check combinational outputs BEFORE the clock edge
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd3;
    disp_rs1_arch = 5'd1;
    disp_rs2_arch = 5'd2;
    #1;
    check_val(disp_rd_phys, 6'd32, "Dispatch R3: new phys = P32");
    check_val(disp_rd_old_phys, 6'd3, "Dispatch R3: old phys = P3");
    check_val(disp_rs1_phys, 6'd1, "Dispatch R3: rs1 (R1) = P1");
    check_val(disp_rs2_phys, 6'd2, "Dispatch R3: rs2 (R2) = P2");

    // Clock edge: rename_map[3] -> P32, fl_head advances
    @(posedge clk);
    #1;  // settle

    // After dispatch: rename_map[3] should now be P32
    disp_valid    = 1;
    disp_writes_rd = 0;
    disp_rs1_arch = 5'd3;
    #1;
    check_val(disp_rs1_phys, 6'd32, "After dispatch R3: map[3] = P32");

    // Next free phys should now be P33
    disp_writes_rd = 1;
    disp_rd_arch   = 5'd0;
    #1;
    check_val(disp_rd_phys, 6'd33, "After dispatch R3: next free = P33");

    disp_valid    = 0;
    disp_writes_rd = 0;
    idle;

    // ================================================================
    // TEST 3: Back-to-back dispatches writing the SAME arch register
    // Most important test — verifies WAW dissolution
    // dispatch R5 twice: should get P33 then P34
    // ================================================================
    $display("\n--- TEST 3: Back-to-Back Dispatches Same Arch Reg (WAW) ---");

    @(posedge clk);  // Wait for the next clock edge to clear the idle race!
    #1;  // Small delay to step past the edge

    // First dispatch to R5: check outputs before clock
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd5;
    disp_rs1_arch = 5'd0;
    disp_rs2_arch = 5'd0;
    commit_valid  = 0;
    #1;
    check_val(disp_rd_phys, 6'd33, "WAW dispatch 1: R5 gets P33");
    check_val(disp_rd_old_phys, 6'd5, "WAW dispatch 1: old phys = P5");

    @(posedge clk);  // rename_map[5] -> P33, fl_head -> P34
    #1;

    // Second dispatch to R5 immediately: check outputs before next clock
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd5;
    disp_rs1_arch = 5'd0;
    disp_rs2_arch = 5'd0;
    #1;
    check_val(disp_rd_phys, 6'd34, "WAW dispatch 2: R5 gets P34 (different!)");
    check_val(disp_rd_old_phys, 6'd33, "WAW dispatch 2: old phys = P33 (I1's dest)");

    @(posedge clk);  // rename_map[5] -> P34
    #1;

    // Verify map[5] is now P34
    disp_valid    = 1;
    disp_writes_rd = 0;
    disp_rs1_arch = 5'd5;
    #1;
    check_val(disp_rs1_phys, 6'd34, "WAW: map[5] = P34 after 2 dispatches");

    disp_valid = 0;
    idle;

    // ================================================================
    // TEST 4: Dispatch followed by commit returning old_phys
    // fl_count should return to same level after commit
    // ================================================================
    $display("\n--- TEST 4: Dispatch then Commit ---");

    // At this point we've dispatched: R3->P32, R5->P33, R5->P34
    // fl_count = 16 - 3 = 13 (from dispatches so far since reset)
    // Next free phys = P35

    // Dispatch R7: gets P35, old = P7
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd7;
    disp_rs1_arch = 5'd0;
    disp_rs2_arch = 5'd0;
    commit_valid  = 0;
    #1;
    check_val(disp_rd_phys, 6'd35, "Dispatch R7: gets P35");
    check_val(disp_rd_old_phys, 6'd7, "Dispatch R7: old phys = P7");

    @(posedge clk);  // fl_count drops to 12
    #1;

    // Now commit with old_phys = P3 (from Test 2's dispatch of R3)
    disp_valid      = 0;
    disp_writes_rd  = 0;
    commit_valid    = 1;
    commit_old_phys = 6'd3;

    @(posedge clk);  // fl_count rises back to 13, P3 back in free list
    #1;

    commit_valid = 0;

    // After commit: next free phys should eventually be P3 at the tail
    // and fl_count should have gone up by 1
    // Verify by checking stall is still 0
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd0;
    #1;
    check_bit(stall, 1'b0, "After commit: stall still 0 (free list not empty)");

    disp_valid = 0;
    idle;

    // ================================================================
    // TEST 5: Non-writing instruction
    // disp_writes_rd = 0: rename map and free list must NOT change
    // ================================================================
    $display("\n--- TEST 5: Non-Writing Instruction ---");

    // Record current state: next free phys
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd0;
    #1;
    begin : test5_block
      reg [5:0] free_before;
      free_before = disp_rd_phys;
      $display("INFO: free phys before non-write dispatch = P%0d", free_before);

      // Now dispatch a non-writing instruction (like a store/branch)
      @(posedge clk);
      disp_valid    <= 1;
      disp_writes_rd <= 0;
      disp_rs1_arch <= 5'd4;
      disp_rs2_arch <= 5'd5;
      disp_rd_arch  <= 5'd10; // destination present but writes_rd=0
      commit_valid  <= 0;

      @(posedge clk);
      #1;

      // Free list head should NOT have advanced
      disp_valid    = 1;
      disp_writes_rd = 1;
      disp_rd_arch  = 5'd0;
      #1;
      check_val(disp_rd_phys, free_before, "Non-write: free list unchanged");

      // map[10] should still be P10 (not updated)
      disp_writes_rd = 0;
      disp_rs1_arch  = 5'd10;
      #1;
      check_val(disp_rs1_phys, 6'd10, "Non-write: map[10] unchanged = P10");

      // stall should be 0
      check_bit(stall, 1'b0, "Non-write: stall = 0");
    end

    disp_valid = 0;
    idle;

    // ================================================================
    // TEST 6: Free list exhaustion
    // Dispatch 16 writes total (we've done 4 so far: R3,R5,R5,R7)
    // Need 12 more dispatches to empty the free list
    // Then 17th dispatch should stall
    // ================================================================
    $display("\n--- TEST 6: Free List Exhaustion ---");

    // Reset to get a clean slate for easier counting
    @(posedge clk);
    reset <= 1;
    @(posedge clk);
    @(posedge clk);
    reset <= 0;
    disp_valid    <= 0;
    disp_writes_rd <= 0;
    commit_valid  <= 0;
    @(posedge clk);
    #1;

    // Dispatch 16 writes (R0 through R15, using different arch regs each time)
    for (k = 0; k < 16; k = k + 1) begin
      @(posedge clk);
      disp_valid    <= 1;
      disp_writes_rd <= 1;
      disp_rd_arch  <= k[4:0];
      disp_rs1_arch <= 5'd0;
      disp_rs2_arch <= 5'd0;
      commit_valid  <= 0;
    end

    @(posedge clk);  // last dispatch clocks in
    // Pull inputs low before checking the stall
    disp_valid     = 0;
    disp_writes_rd = 0;
    #1;
    check_bit(stall, 1'b0, "After 16 dispatches: stall still 0");

    // 17th dispatch attempt: free list now empty, stall should assert
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd20;
    disp_rs1_arch = 5'd0;
    disp_rs2_arch = 5'd0;
    commit_valid  = 0;
    #1;
    check_bit(stall, 1'b1, "17th dispatch: stall = 1 (free list empty)");

    // Clock edge: verify stall prevents any rename map update
    // map[20] should still be P20 (identity from reset)
    disp_writes_rd = 0;
    disp_rs1_arch  = 5'd20;
    #1;
    check_val(disp_rs1_phys, 6'd20, "Stall: map[20] not updated");

    disp_valid = 0;
    idle;

    // ================================================================
    // TEST 7: Simultaneous dispatch and commit
    // fl_count should stay the same (pop one, push one)
    // ================================================================
    $display("\n--- TEST 7: Simultaneous Dispatch and Commit ---");

    // Free list is currently empty from Test 6
    // Do a commit first to put one entry back, then test simultaneous

    @(posedge clk);
    disp_valid      <= 0;
    disp_writes_rd  <= 0;
    commit_valid    <= 1;
    commit_old_phys <= 6'd3;  // return P3 to free list
    @(posedge clk);
    commit_valid <= 0;
    #1;

    // Now free list has exactly 1 entry
    // Simultaneous dispatch (needs 1 free reg) + commit (returns 1 free reg)
    // fl_count should remain 1 after the cycle
    disp_valid      = 1;
    disp_writes_rd  = 1;
    disp_rd_arch    = 5'd25;
    disp_rs1_arch   = 5'd0;
    disp_rs2_arch   = 5'd0;
    commit_valid    = 1;
    commit_old_phys = 6'd7;  // return P7 to free list simultaneously

    // Before clock: stall should be 0 (1 entry available)
    #1;
    check_bit(stall, 1'b0, "Simultaneous: stall = 0 (1 free reg available)");

    // Check dispatch outputs
    check_val(disp_rd_phys, 6'd3, "Simultaneous: dispatch gets P3");
    check_val(disp_rd_old_phys, 6'd25, "Simultaneous: old phys = P25");

    @(posedge clk);  // dispatch pops P3, commit pushes P7 -> count stays 1
    #1;

    // After: fl_count should still be 1
    // Verify: can still dispatch (not stalled), next free = P7
    disp_valid    = 1;
    disp_writes_rd = 1;
    disp_rd_arch  = 5'd0;
    commit_valid  = 0;
    #1;
    check_bit(stall, 1'b0, "Simultaneous: after cycle, stall still 0 (count unchanged)");
    check_val(disp_rd_phys, 6'd7, "Simultaneous: next free = P7 (committed entry)");

    disp_valid = 0;
    idle;

    // ================================================================
    // Final result
    // ================================================================
    $display("\n================================");
    if (errors == 0) $display("ALL TESTS PASSED (%0d errors)", errors);
    else $display("FAILED: %0d test(s) failed", errors);
    $display("================================\n");

    $finish;
  end

endmodule
