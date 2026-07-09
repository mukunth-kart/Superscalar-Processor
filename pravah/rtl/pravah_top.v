module pravah_top (
    input wire clk_i,
    input wire reset_i
    // No external interface for now; everything is internal
);

  // =========================================================================
  // Inter-module Wires
  // =========================================================================

  // Fetch outputs
  wire [31:0] fetch_pc_A, fetch_pc_B;
  wire [31:0] fetch_instr_A, fetch_instr_B;
  wire fetch_valid_A, fetch_valid_B;

  // Decode outputs
  wire [3:0] dec_A_op, dec_B_op;
  wire [4:0] dec_A_rs1_arch, dec_A_rs2_arch, dec_A_rd_arch;
  wire [4:0] dec_B_rs1_arch, dec_B_rs2_arch, dec_B_rd_arch;
  wire dec_A_writes_rd, dec_B_writes_rd;
  wire [31:0] dec_A_imm, dec_B_imm;
  wire dec_A_use_imm, dec_B_use_imm;
  wire [1:0] dec_A_fu_type, dec_B_fu_type;
  wire dec_A_valid, dec_B_valid;

  // Rename outputs
  wire [5:0] rn_A_rs1_phys, rn_A_rs2_phys, rn_A_rd_phys, rn_A_rd_old_phys;
  wire [5:0] rn_B_rs1_phys, rn_B_rs2_phys, rn_B_rd_phys, rn_B_rd_old_phys;
  wire rn_stall_A, rn_stall_B;

  // Dispatch outputs
  wire disp_fe_stall;
  wire rob_alloc_A, rob_alloc_B;
  wire [4:0] rob_arch_dest_A, rob_arch_dest_B;
  wire [5:0] rob_phys_dest_A, rob_phys_dest_B;
  wire [5:0] rob_old_phys_A, rob_old_phys_B;
  wire rob_writes_rd_A, rob_writes_rd_B;

  wire rs_disp_A_valid, rs_disp_B_valid;
  wire [3:0] rs_disp_A_op, rs_disp_B_op;
  wire [5:0] rs_disp_A_pj, rs_disp_A_pk, rs_disp_A_pd;
  wire [5:0] rs_disp_B_pj, rs_disp_B_pk, rs_disp_B_pd;
  wire [2:0] rs_disp_A_rob_idx, rs_disp_B_rob_idx;
  wire [31:0] rs_disp_A_imm, rs_disp_B_imm;
  wire rs_disp_A_use_imm, rs_disp_B_use_imm;
  wire rs_stall_A, rs_stall_B;

  // ROB outputs
  wire [2:0] rob_tail;
  wire rob_full;
  wire rob_commit_A_valid, rob_commit_B_valid;
  wire [5:0] rob_commit_A_old_phys, rob_commit_B_old_phys;

  // RS outputs (issue buses)
  wire rs_issue_0_valid, rs_issue_1_valid;
  wire [3:0] rs_issue_0_op, rs_issue_1_op;
  wire [5:0] rs_issue_0_pj, rs_issue_1_pj, rs_issue_0_pk, rs_issue_1_pk;
  wire [5:0] rs_issue_0_pd, rs_issue_1_pd;
  wire [2:0] rs_issue_0_rob_idx, rs_issue_1_rob_idx;
  wire [31:0] rs_issue_0_imm, rs_issue_1_imm;
  wire rs_issue_0_use_imm, rs_issue_1_use_imm;

  // RS Snoop buses
  wire [23:0] rs_snoop_pj_addr, rs_snoop_pk_addr;  // 4 RS * 6 bits
  wire [3:0] rs_snoop_pj_ready, rs_snoop_pk_ready;

  // ALU outputs
  wire alu0_result_valid, alu1_result_valid;
  wire [31:0] alu0_result, alu1_result;
  wire [5:0] alu0_phys_dest, alu1_phys_dest;
  wire [2:0] alu0_rob_idx, alu1_rob_idx;

  // PRF outputs
  wire [31:0] prf_rd_data_1, prf_rd_data_2, prf_rd_data_3, prf_rd_data_4;
  wire prf_rd_ready_1, prf_rd_ready_2, prf_rd_ready_3, prf_rd_ready_4;


  // =========================================================================
  // Module Instantiations
  // =========================================================================

  fetch u_fetch (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .fe_stall_i(disp_fe_stall),
      .pc_A_o(fetch_pc_A),
      .instr_A_o(fetch_instr_A),
      .valid_A_o(fetch_valid_A),
      .pc_B_o(fetch_pc_B),
      .instr_B_o(fetch_instr_B),
      .valid_B_o(fetch_valid_B)
  );

  decode u_decode_A (
      .instr_i(fetch_instr_A),
      .valid_i(fetch_valid_A),
      .op_o(dec_A_op),
      .rs1_arch_o(dec_A_rs1_arch),
      .rs2_arch_o(dec_A_rs2_arch),
      .rd_arch_o(dec_A_rd_arch),
      .writes_rd_o(dec_A_writes_rd),
      .imm_o(dec_A_imm),
      .use_imm_o(dec_A_use_imm),
      .valid_o(dec_A_valid)
  );

  decode u_decode_B (
      .instr_i(fetch_instr_B),
      .valid_i(fetch_valid_B),
      .op_o(dec_B_op),
      .rs1_arch_o(dec_B_rs1_arch),
      .rs2_arch_o(dec_B_rs2_arch),
      .rd_arch_o(dec_B_rd_arch),
      .writes_rd_o(dec_B_writes_rd),
      .imm_o(dec_B_imm),
      .use_imm_o(dec_B_use_imm),
      .valid_o(dec_B_valid)
  );

  rename_unit u_rename (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .dec_A_valid_i(dec_A_valid),
      .dec_A_rs1_arch_i(dec_A_rs1_arch),
      .dec_A_rs2_arch_i(dec_A_rs2_arch),
      .dec_A_rd_arch_i(dec_A_rd_arch),
      .dec_A_writes_rd_i(dec_A_writes_rd),
      .dec_B_valid_i(dec_B_valid),
      .dec_B_rs1_arch_i(dec_B_rs1_arch),
      .dec_B_rs2_arch_i(dec_B_rs2_arch),
      .dec_B_rd_arch_i(dec_B_rd_arch),
      .dec_B_writes_rd_i(dec_B_writes_rd),

      // Note: For Week 6, we serialize commits to the rename unit's single port. 
      // We only feed it Slot A's commit. (Week 7 stretch goal is widening this).
      .commit_valid_i(rob_commit_A_valid),
      .commit_old_phys_i(rob_commit_A_old_phys),

      .rn_A_rs1_phys_o(rn_A_rs1_phys),
      .rn_A_rs2_phys_o(rn_A_rs2_phys),
      .rn_A_rd_phys_o(rn_A_rd_phys),
      .rn_A_rd_old_phys_o(rn_A_rd_old_phys),
      .rn_B_rs1_phys_o(rn_B_rs1_phys),
      .rn_B_rs2_phys_o(rn_B_rs2_phys),
      .rn_B_rd_phys_o(rn_B_rd_phys),
      .rn_B_rd_old_phys_o(rn_B_rd_old_phys),
      .stall_A_o(rn_stall_A),
      .stall_B_o(rn_stall_B)
  );

  dispatch u_dispatch (
      // Rename & Decode Inputs
      .rn_A_valid_i(~rn_stall_A & dec_A_valid),
      .rn_B_valid_i(~rn_stall_B & dec_B_valid),
      .dec_A_op_i(dec_A_op),
      .dec_B_op_i(dec_B_op),
      .rn_A_rs1_phys_i(rn_A_rs1_phys),
      .rn_A_rs2_phys_i(rn_A_rs2_phys),
      .rn_A_rd_phys_i(rn_A_rd_phys),
      .rn_A_rd_old_phys_i(rn_A_rd_old_phys),
      .dec_A_rd_arch_i(dec_A_rd_arch),
      .dec_A_writes_rd_i(dec_A_writes_rd),
      .dec_A_imm_i(dec_A_imm),
      .dec_A_use_imm_i(dec_A_use_imm),
      .rn_B_rs1_phys_i(rn_B_rs1_phys),
      .rn_B_rs2_phys_i(rn_B_rs2_phys),
      .rn_B_rd_phys_i(rn_B_rd_phys),
      .rn_B_rd_old_phys_i(rn_B_rd_old_phys),
      .dec_B_rd_arch_i(dec_B_rd_arch),
      .dec_B_writes_rd_i(dec_B_writes_rd),
      .dec_B_imm_i(dec_B_imm),
      .dec_B_use_imm_i(dec_B_use_imm),

      // Backpressure from Back-end
      .rs_stall_A_i(rs_stall_A),
      .rs_stall_B_i(rs_stall_B),
      .rob_full_i  (rob_full),
      .rob_tail_i  (rob_tail),

      // Outputs
      .fe_stall_o(disp_fe_stall),
      .rs_disp_A_valid_o(rs_disp_A_valid),
      .rs_disp_A_op_o(rs_disp_A_op),
      .rs_disp_A_pj_o(rs_disp_A_pj),
      .rs_disp_A_pk_o(rs_disp_A_pk),
      .rs_disp_A_pd_o(rs_disp_A_pd),
      .rs_disp_A_rob_idx_o(rs_disp_A_rob_idx),
      .rs_disp_A_imm_o(rs_disp_A_imm),
      .rs_disp_A_use_imm_o(rs_disp_A_use_imm),
      .rs_disp_B_valid_o(rs_disp_B_valid),
      .rs_disp_B_op_o(rs_disp_B_op),
      .rs_disp_B_pj_o(rs_disp_B_pj),
      .rs_disp_B_pk_o(rs_disp_B_pk),
      .rs_disp_B_pd_o(rs_disp_B_pd),
      .rs_disp_B_rob_idx_o(rs_disp_B_rob_idx),
      .rs_disp_B_imm_o(rs_disp_B_imm),
      .rs_disp_B_use_imm_o(rs_disp_B_use_imm),

      .rob_alloc_A_o(rob_alloc_A),
      .rob_A_writes_rd_o(rob_writes_rd_A),
      .rob_A_arch_dest_o(rob_arch_dest_A),
      .rob_A_phys_dest_o(rob_phys_dest_A),
      .rob_A_old_phys_dest_o(rob_old_phys_A),
      .rob_alloc_B_o(rob_alloc_B),
      .rob_B_writes_rd_o(rob_writes_rd_B),
      .rob_B_arch_dest_o(rob_arch_dest_B),
      .rob_B_phys_dest_o(rob_phys_dest_B),
      .rob_B_old_phys_dest_o(rob_old_phys_B)
  );

  reservation_station u_rs (
      .clk_i  (clk_i),
      .reset_i(reset_i),

      // Dispatch Ports
      .disp_A_valid_i(rs_disp_A_valid),
      .disp_A_op_i(rs_disp_A_op),
      .disp_A_pj_i(rs_disp_A_pj),
      .disp_A_pk_i(rs_disp_A_pk),
      .disp_A_pd_i(rs_disp_A_pd),
      .disp_A_rob_idx_i(rs_disp_A_rob_idx),
      .disp_A_imm_i(rs_disp_A_imm),
      .disp_A_use_imm_i(rs_disp_A_use_imm),
      .disp_stall_A_o(rs_stall_A),
      .disp_B_valid_i(rs_disp_B_valid),
      .disp_B_op_i(rs_disp_B_op),
      .disp_B_pj_i(rs_disp_B_pj),
      .disp_B_pk_i(rs_disp_B_pk),
      .disp_B_pd_i(rs_disp_B_pd),
      .disp_B_rob_idx_i(rs_disp_B_rob_idx),
      .disp_B_imm_i(rs_disp_B_imm),
      .disp_B_use_imm_i(rs_disp_B_use_imm),
      .disp_stall_B_o(rs_stall_B),

      // PRF Snoop Ports
      .snoop_pj_addr_o (rs_snoop_pj_addr),
      .snoop_pk_addr_o (rs_snoop_pk_addr),
      .snoop_pj_ready_i(rs_snoop_pj_ready),
      .snoop_pk_ready_i(rs_snoop_pk_ready),

      // Issue Port 0 (to ALU0)
      .issue_0_valid_o(rs_issue_0_valid),
      .issue_0_op_o(rs_issue_0_op),
      .issue_0_pj_o(rs_issue_0_pj),
      .issue_0_pk_o(rs_issue_0_pk),
      .issue_0_pd_o(rs_issue_0_pd),
      .issue_0_rob_idx_o(rs_issue_0_rob_idx),
      .issue_0_imm_o(rs_issue_0_imm),
      .issue_0_use_imm_o(rs_issue_0_use_imm),

      // Issue Port 1 (to ALU1)
      .issue_1_valid_o(rs_issue_1_valid),
      .issue_1_op_o(rs_issue_1_op),
      .issue_1_pj_o(rs_issue_1_pj),
      .issue_1_pk_o(rs_issue_1_pk),
      .issue_1_pd_o(rs_issue_1_pd),
      .issue_1_rob_idx_o(rs_issue_1_rob_idx),
      .issue_1_imm_o(rs_issue_1_imm),
      .issue_1_use_imm_o(rs_issue_1_use_imm)
  );

  register_file u_prf (
      .clk_i  (clk_i),
      .reset_i(reset_i),

      // 4 Read Ports (Operands for the ALUs)
      .rd_addr1_i (rs_issue_0_pj),
      .rd_data1_o (prf_rd_data_1),
      .rd_ready1_o(prf_rd_ready_1),
      .rd_addr2_i (rs_issue_0_pk),
      .rd_data2_o (prf_rd_data_2),
      .rd_ready2_o(prf_rd_ready_2),
      .rd_addr3_i (rs_issue_1_pj),
      .rd_data3_o (prf_rd_data_3),
      .rd_ready3_o(prf_rd_ready_3),
      .rd_addr4_i (rs_issue_1_pk),
      .rd_data4_o (prf_rd_data_4),
      .rd_ready4_o(prf_rd_ready_4),

      // 2 Write Ports (CDB Writeback from FUs)
      .wr_en1_i  (alu0_result_valid),
      .wr_addr1_i(alu0_phys_dest),
      .wr_data1_i(alu0_result),
      .wr_en2_i  (alu1_result_valid),
      .wr_addr2_i(alu1_phys_dest),
      .wr_data2_i(alu1_result),

      // 2 Allocate Ports (Clear ready bit at dispatch)
      .alloc_en1_i  (rob_alloc_A & rob_writes_rd_A),
      .alloc_addr1_i(rob_phys_dest_A),
      .alloc_en2_i  (rob_alloc_B & rob_writes_rd_B),
      .alloc_addr2_i(rob_phys_dest_B)
  );

  alu u_alu0 (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .valid_i(rs_issue_0_valid),
      .op_i(rs_issue_0_op),
      .src1_val_i(prf_rd_data_1),
      .src2_val_i(prf_rd_data_2),
      .imm_i(rs_issue_0_imm),
      .use_imm_i(rs_issue_0_use_imm),
      .phys_dest_i(rs_issue_0_pd),
      .rob_idx_i(rs_issue_0_rob_idx),

      .result_valid_o(alu0_result_valid),
      .result_o(alu0_result),
      .phys_dest_o(alu0_phys_dest),
      .rob_idx_o(alu0_rob_idx)
  );

  alu u_alu1 (
      .clk_i(clk_i),
      .reset_i(reset_i),
      .valid_i(rs_issue_1_valid),
      .op_i(rs_issue_1_op),
      .src1_val_i(prf_rd_data_3),
      .src2_val_i(prf_rd_data_4),
      .imm_i(rs_issue_1_imm),
      .use_imm_i(rs_issue_1_use_imm),
      .phys_dest_i(rs_issue_1_pd),
      .rob_idx_i(rs_issue_1_rob_idx),

      .result_valid_o(alu1_result_valid),
      .result_o(alu1_result),
      .phys_dest_o(alu1_phys_dest),
      .rob_idx_o(alu1_rob_idx)
  );

  rob u_rob (
      .clk_i  (clk_i),
      .reset_i(reset_i),

      // Dispatch Allocation
      .alloc_A_i(rob_alloc_A),
      .writes_rd_A_i(rob_writes_rd_A),
      .arch_dest_A_i(rob_arch_dest_A),
      .phys_dest_A_i(rob_phys_dest_A),
      .old_phys_dest_A_i(rob_old_phys_A),
      .alloc_B_i(rob_alloc_B),
      .writes_rd_B_i(rob_writes_rd_B),
      .arch_dest_B_i(rob_arch_dest_B),
      .phys_dest_B_i(rob_phys_dest_B),
      .old_phys_dest_B_i(rob_old_phys_B),
      .tail_o(rob_tail),
      .full_o(rob_full),

      // FU Writeback (Mark Ready)
      .mark_ready_0_en_i (alu0_result_valid),
      .mark_ready_0_idx_i(alu0_rob_idx),
      .mark_ready_1_en_i (alu1_result_valid),
      .mark_ready_1_idx_i(alu1_rob_idx),

      // Commit Output
      .commit_A_valid_o(rob_commit_A_valid),
      .commit_A_old_phys_o(rob_commit_A_old_phys),
      .commit_B_valid_o(rob_commit_B_valid),
      .commit_B_old_phys_o(rob_commit_B_old_phys)
  );

  // =========================================================================
  // Combinational Snooping Logic for RS
  // =========================================================================
  // The RS requests ready bits for up to 8 sources (4 RS * 2 sources). 
  // Since our PRF only exports 4 ready bits strictly tied to the ALU read ports,
  // we use a hierarchical reference here to access the internal 'ready' array 
  // directly for the combinational wakeup logic.

  genvar g;
  generate
    for (g = 0; g < 4; g = g + 1) begin : snoop_wire_gen
      wire [5:0] pj_addr = rs_snoop_pj_addr[(g*6)+:6];
      wire [5:0] pk_addr = rs_snoop_pk_addr[(g*6)+:6];
      assign rs_snoop_pj_ready[g] = u_prf.ready[pj_addr];
      assign rs_snoop_pk_ready[g] = u_prf.ready[pk_addr];
    end
  endgenerate

endmodule
