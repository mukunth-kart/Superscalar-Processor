`timescale 1ns / 1ps

module tb_frontend ();

  // --------------------------------------------------------
  // Parameters
  // --------------------------------------------------------
  parameter PC_WIDTH = 32;
  parameter ARCH_ADDR_W = 5;
  parameter PHYS_ADDR_W = 6;
  parameter OP_WIDTH = 4;
  parameter ROB_ADDR_W = 3;
  parameter NUM_RS = 4;

  // --------------------------------------------------------
  // Clock and Reset
  // --------------------------------------------------------
  reg clk;
  reg reset;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // --------------------------------------------------------
  // Interconnect Wires
  // --------------------------------------------------------

  // Fetch -> Decode
  wire [PC_WIDTH-1:0] pc_A, pc_B;
  wire [31:0] instr_A, instr_B;
  wire fetch_valid_A, fetch_valid_B;

  // Decode -> Rename & Dispatch (Slot A)
  wire [OP_WIDTH-1:0] dec_A_op;
  wire [ARCH_ADDR_W-1:0] dec_A_rs1, dec_A_rs2, dec_A_rd;
  wire dec_A_writes_rd, dec_A_is_branch, dec_A_is_memory, dec_A_valid;
  wire [1:0] dec_A_fu_type;
  wire [31:0] dec_A_imm;

  // Decode -> Rename & Dispatch (Slot B)
  wire [OP_WIDTH-1:0] dec_B_op;
  wire [ARCH_ADDR_W-1:0] dec_B_rs1, dec_B_rs2, dec_B_rd;
  wire dec_B_writes_rd, dec_B_is_branch, dec_B_is_memory, dec_B_valid;
  wire [ 1:0] dec_B_fu_type;
  wire [31:0] dec_B_imm;

  // Rename -> Dispatch (Slot A)
  wire [PHYS_ADDR_W-1:0] ren_A_rs1_phys, ren_A_rs2_phys, ren_A_rd_phys, ren_A_rd_old_phys;
  wire ren_stall_A;

  // Rename -> Dispatch (Slot B)
  wire [PHYS_ADDR_W-1:0] ren_B_rs1_phys, ren_B_rs2_phys, ren_B_rd_phys, ren_B_rd_old_phys;
  wire ren_stall_B;

  // Dispatch -> Fetch
  wire fe_stall;

  // Dispatch -> ROB (Stubs)
  wire rob_alloc_A, rob_alloc_B;
  wire [ARCH_ADDR_W-1:0] rob_A_arch_dest, rob_B_arch_dest;
  wire [PHYS_ADDR_W-1:0] rob_A_phys_dest, rob_B_phys_dest;
  wire [PHYS_ADDR_W-1:0] rob_A_old_phys_dest, rob_B_old_phys_dest;
  wire rob_A_writes_rd, rob_B_writes_rd;

  // Dispatch -> RS (Slot A)
  wire rs_disp_A_valid;
  wire [OP_WIDTH-1:0] rs_disp_A_op;
  wire [PHYS_ADDR_W-1:0] rs_disp_A_pj, rs_disp_A_pk, rs_disp_A_pd;
  wire [ROB_ADDR_W-1:0] rs_disp_A_rob_idx;

  // Dispatch -> RS (Slot B)
  wire rs_disp_B_valid;
  wire [OP_WIDTH-1:0] rs_disp_B_op;
  wire [PHYS_ADDR_W-1:0] rs_disp_B_pj, rs_disp_B_pk, rs_disp_B_pd;
  wire [ROB_ADDR_W-1:0] rs_disp_B_rob_idx;

  // RS Outputs (Unused this week since execution is stubbed)
  wire rs_disp_stall_A, rs_disp_stall_B;
  wire [(NUM_RS*PHYS_ADDR_W)-1:0] snoop_pj_addr, snoop_pk_addr;
  wire issue_valid;
  wire [OP_WIDTH-1:0] issue_op;
  wire [PHYS_ADDR_W-1:0] issue_pj, issue_pk, issue_pd;
  wire [ROB_ADDR_W-1:0] issue_rob_idx;

  // --------------------------------------------------------
  // Stubs for Back-End (ROB & PRF)
  // --------------------------------------------------------
  reg [ROB_ADDR_W-1:0] rob_tail;
  wire rob_full = 1'b0;  // Assume infinite ROB for testing

  // Fake PRF ready bits tied to 0. 
  // Document specifies: "so RS wakeup doesn't fire, since we don't have execution yet"
  wire [NUM_RS-1:0] fake_prf_ready = {NUM_RS{1'b0}};

  // Fake commit port tied to 0
  wire commit_valid = 1'b0;
  wire [PHYS_ADDR_W-1:0] commit_old_phys = {PHYS_ADDR_W{1'b0}};

  // Advance ROB Tail
  always @(posedge clk) begin
    if (reset) begin
      rob_tail <= 0;
    end else begin
      rob_tail <= rob_tail + rob_alloc_A + rob_alloc_B;
    end
  end

  // --------------------------------------------------------
  // Module Instantiations
  // --------------------------------------------------------
  fetch #(
      .PC_WIDTH  (PC_WIDTH),
      .IMEM_DEPTH(256)
  ) fetch_inst (
      .clk_i(clk),
      .reset_i(reset),
      .fe_stall_i(fe_stall),
      .pc_A_o(pc_A),
      .instr_A_o(instr_A),
      .valid_A_o(fetch_valid_A),
      .pc_B_o(pc_B),
      .instr_B_o(instr_B),
      .valid_B_o(fetch_valid_B)
  );

  decode #(
      .ARCH_ADDR_W(ARCH_ADDR_W),
      .OP_WIDTH(OP_WIDTH)
  ) decode_A_inst (
      .instr_i(instr_A),
      .valid_i(fetch_valid_A),
      .op_o(dec_A_op),
      .rs1_arch_o(dec_A_rs1),
      .rs2_arch_o(dec_A_rs2),
      .rd_arch_o(dec_A_rd),
      .writes_rd_o(dec_A_writes_rd),
      .imm_o(dec_A_imm),
      .is_branch_o(dec_A_is_branch),
      .is_memory_o(dec_A_is_memory),
      .fu_type_o(dec_A_fu_type),
      .valid_o(dec_A_valid)
  );

  decode #(
      .ARCH_ADDR_W(ARCH_ADDR_W),
      .OP_WIDTH(OP_WIDTH)
  ) decode_B_inst (
      .instr_i(instr_B),
      .valid_i(fetch_valid_B),
      .op_o(dec_B_op),
      .rs1_arch_o(dec_B_rs1),
      .rs2_arch_o(dec_B_rs2),
      .rd_arch_o(dec_B_rd),
      .writes_rd_o(dec_B_writes_rd),
      .imm_o(dec_B_imm),
      .is_branch_o(dec_B_is_branch),
      .is_memory_o(dec_B_is_memory),
      .fu_type_o(dec_B_fu_type),
      .valid_o(dec_B_valid)
  );

  rename_unit #(
      .NUM_ARCH_REGS(32),
      .NUM_PHYS_REGS(48),
      .ARCH_ADDR_W  (ARCH_ADDR_W),
      .PHYS_ADDR_W  (PHYS_ADDR_W)
  ) rename_inst (
      .clk_i(clk),
      .reset_i(reset),
      // Slot A
      .disp_A_valid_i(dec_A_valid),
      .disp_A_rs1_arch_i(dec_A_rs1),
      .disp_A_rs2_arch_i(dec_A_rs2),
      .disp_A_rd_arch_i(dec_A_rd),
      .disp_A_writes_rd_i(dec_A_writes_rd),
      .disp_A_rs1_phys_o(ren_A_rs1_phys),
      .disp_A_rs2_phys_o(ren_A_rs2_phys),
      .disp_A_rd_phys_o(ren_A_rd_phys),
      .disp_A_rd_old_phys_o(ren_A_rd_old_phys),
      // Slot B
      .disp_B_valid_i(dec_B_valid),
      .disp_B_rs1_arch_i(dec_B_rs1),
      .disp_B_rs2_arch_i(dec_B_rs2),
      .disp_B_rd_arch_i(dec_B_rd),
      .disp_B_writes_rd_i(dec_B_writes_rd),
      .disp_B_rs1_phys_o(ren_B_rs1_phys),
      .disp_B_rs2_phys_o(ren_B_rs2_phys),
      .disp_B_rd_phys_o(ren_B_rd_phys),
      .disp_B_rd_old_phys_o(ren_B_rd_old_phys),
      // Stalls & Commits
      .stall_A_o(ren_stall_A),
      .stall_B_o(ren_stall_B),
      .commit_valid_i(commit_valid),
      .commit_old_phys_i(commit_old_phys)
  );

  dispatch #(
      .ARCH_ADDR_W(ARCH_ADDR_W),
      .PHYS_ADDR_W(PHYS_ADDR_W),
      .OP_WIDTH(OP_WIDTH),
      .ROB_ADDR_W(ROB_ADDR_W)
  ) dispatch_inst (
      .clk_i(clk),
      .reset_i(reset),
      // Decode Slot A
      .decode_A_valid_i(dec_A_valid),
      .decode_A_op_i(dec_A_op),
      .decode_A_rs1_arch_i(dec_A_rs1),
      .decode_A_rs2_arch_i(dec_A_rs2),
      .decode_A_rd_arch_i(dec_A_rd),
      .decode_A_writes_rd_i(dec_A_writes_rd),
      .decode_A_fu_type_i(dec_A_fu_type),
      // Decode Slot B
      .decode_B_valid_i(dec_B_valid),
      .decode_B_op_i(dec_B_op),
      .decode_B_rs1_arch_i(dec_B_rs1),
      .decode_B_rs2_arch_i(dec_B_rs2),
      .decode_B_rd_arch_i(dec_B_rd),
      .decode_B_writes_rd_i(dec_B_writes_rd),
      .decode_B_fu_type_i(dec_B_fu_type),
      // Rename Slot A
      .rename_A_rs1_phys_i(ren_A_rs1_phys),
      .rename_A_rs2_phys_i(ren_A_rs2_phys),
      .rename_A_rd_phys_i(ren_A_rd_phys),
      .rename_A_rd_old_phys_i(ren_A_rd_old_phys),
      .rename_stall_A_i(ren_stall_A),
      // Rename Slot B
      .rename_B_rs1_phys_i(ren_B_rs1_phys),
      .rename_B_rs2_phys_i(ren_B_rs2_phys),
      .rename_B_rd_phys_i(ren_B_rd_phys),
      .rename_B_rd_old_phys_i(ren_B_rd_old_phys),
      .rename_stall_B_i(ren_stall_B),
      // ROB interface
      .rob_tail_i(rob_tail),
      .rob_full_i(rob_full),
      .rob_alloc_A_o(rob_alloc_A),
      .rob_A_arch_dest_o(rob_A_arch_dest),
      .rob_A_phys_dest_o(rob_A_phys_dest),
      .rob_A_old_phys_dest_o(rob_A_old_phys_dest),
      .rob_A_writes_rd_o(rob_A_writes_rd),
      .rob_alloc_B_o(rob_alloc_B),
      .rob_B_arch_dest_o(rob_B_arch_dest),
      .rob_B_phys_dest_o(rob_B_phys_dest),
      .rob_B_old_phys_dest_o(rob_B_old_phys_dest),
      .rob_B_writes_rd_o(rob_B_writes_rd),
      // RS Slot A
      .rs_disp_A_valid_o(rs_disp_A_valid),
      .rs_disp_A_op_o(rs_disp_A_op),
      .rs_disp_A_pj_o(rs_disp_A_pj),
      .rs_disp_A_pk_o(rs_disp_A_pk),
      .rs_disp_A_pd_o(rs_disp_A_pd),
      .rs_disp_A_rob_idx_o(rs_disp_A_rob_idx),
      // RS Slot B
      .rs_disp_B_valid_o(rs_disp_B_valid),
      .rs_disp_B_op_o(rs_disp_B_op),
      .rs_disp_B_pj_o(rs_disp_B_pj),
      .rs_disp_B_pk_o(rs_disp_B_pk),
      .rs_disp_B_pd_o(rs_disp_B_pd),
      .rs_disp_B_rob_idx_o(rs_disp_B_rob_idx),
      // Fetch Back-pressure
      .fe_stall_o(fe_stall)
  );

  reservation_station #(
      .NUM_RS(NUM_RS),
      .PHYS_ADDR_W(PHYS_ADDR_W),
      .ROB_ADDR_W(ROB_ADDR_W),
      .OP_WIDTH(OP_WIDTH)
  ) rs_inst (
      .clk_i(clk),
      .reset_i(reset),
      // Disp A
      .disp_A_valid_i(rs_disp_A_valid),
      .disp_A_op_i(rs_disp_A_op),
      .disp_A_pj_i(rs_disp_A_pj),
      .disp_A_pk_i(rs_disp_A_pk),
      .disp_A_pd_i(rs_disp_A_pd),
      .disp_A_rob_idx_i(rs_disp_A_rob_idx),
      .disp_stall_A_o(rs_disp_stall_A),
      // Disp B
      .disp_B_valid_i(rs_disp_B_valid),
      .disp_B_op_i(rs_disp_B_op),
      .disp_B_pj_i(rs_disp_B_pj),
      .disp_B_pk_i(rs_disp_B_pk),
      .disp_B_pd_i(rs_disp_B_pd),
      .disp_B_rob_idx_i(rs_disp_B_rob_idx),
      .disp_stall_B_o(rs_disp_stall_B),
      // Snoops
      .snoop_pj_addr_o(snoop_pj_addr),
      .snoop_pk_addr_o(snoop_pk_addr),
      .snoop_pj_ready_i(fake_prf_ready),
      .snoop_pk_ready_i(fake_prf_ready),
      // Issue
      .issue_valid_o(issue_valid),
      .issue_op_o(issue_op),
      .issue_pj_o(issue_pj),
      .issue_pk_o(issue_pk),
      .issue_pd_o(issue_pd),
      .issue_rob_idx_o(issue_rob_idx)
  );

  // --------------------------------------------------------
  // Simulation Control & Monitoring
  // --------------------------------------------------------

  integer i;  // Declare i outside the block!

  initial begin
    // Load test memory
    $readmemh("../../programs/test1.hex", fetch_inst.imem);

    // Reset sequence
    reset = 1;
    #15 reset = 0;

    // Run for roughly 20 cycles
    #200;

    // Print final rename map
    $display("\n--- FINAL RENAME MAP ---");
    for (i = 1; i <= 8; i = i + 1) begin
      $display("R%0d -> P%0d", i, rename_inst.rename_map[i]);
    end

    $stop;
  end

  // Cycle-by-cycle logging of dispatch
  always @(posedge clk) begin
    if (!reset) begin
      if (rs_disp_A_valid) begin
        $display(
            "Cycle %0t: SLOT A Dispatched -> OP:%0d, Dest:P%0d (Old:P%0d), Src1:P%0d, Src2:P%0d",
            $time, rs_disp_A_op, rs_disp_A_pd, ren_A_rd_old_phys, rs_disp_A_pj, rs_disp_A_pk);
      end
      if (rs_disp_B_valid) begin
        $display(
            "Cycle %0t: SLOT B Dispatched -> OP:%0d, Dest:P%0d (Old:P%0d), Src1:P%0d, Src2:P%0d",
            $time, rs_disp_B_op, rs_disp_B_pd, ren_B_rd_old_phys, rs_disp_B_pj, rs_disp_B_pk);
      end

      if (fe_stall) begin
        $display("Cycle %0t: FRONT-END STALLED", $time);
      end
    end
  end

endmodule
