module dispatch #(
    parameter ARCH_ADDR_W = 5,
    parameter PHYS_ADDR_W = 6,
    parameter OP_WIDTH = 4,
    parameter ROB_ADDR_W = 3,
    parameter DATA_WIDTH = 32
) (
    // Inputs from Rename/Decode
    input wire rn_A_valid_i,
    rn_B_valid_i,
    input wire [OP_WIDTH-1:0] dec_A_op_i,
    dec_B_op_i,
    input wire [PHYS_ADDR_W-1:0] rn_A_rs1_phys_i,
    rn_A_rs2_phys_i,
    rn_A_rd_phys_i,
    rn_A_rd_old_phys_i,
    input wire [PHYS_ADDR_W-1:0] rn_B_rs1_phys_i,
    rn_B_rs2_phys_i,
    rn_B_rd_phys_i,
    rn_B_rd_old_phys_i,
    input wire [ARCH_ADDR_W-1:0] dec_A_rd_arch_i,
    dec_B_rd_arch_i,
    input wire dec_A_writes_rd_i,
    dec_B_writes_rd_i,

    // NEW FOR WEEK 6: Immediate Inputs
    input wire [DATA_WIDTH-1:0] dec_A_imm_i,
    dec_B_imm_i,
    input wire dec_A_use_imm_i,
    dec_B_use_imm_i,

    // Backpressure Inputs
    input wire rs_stall_A_i,
    rs_stall_B_i,
    input wire rob_full_i,
    input wire [ROB_ADDR_W-1:0] rob_tail_i,

    // Fetch Backpressure Output
    output wire fe_stall_o,

    // Outputs to RS
    output wire rs_disp_A_valid_o,
    rs_disp_B_valid_o,
    output wire [OP_WIDTH-1:0] rs_disp_A_op_o,
    rs_disp_B_op_o,
    output wire [PHYS_ADDR_W-1:0] rs_disp_A_pj_o,
    rs_disp_A_pk_o,
    rs_disp_A_pd_o,
    output wire [PHYS_ADDR_W-1:0] rs_disp_B_pj_o,
    rs_disp_B_pk_o,
    rs_disp_B_pd_o,
    output wire [ROB_ADDR_W-1:0] rs_disp_A_rob_idx_o,
    rs_disp_B_rob_idx_o,

    // NEW FOR WEEK 6: Immediate Outputs to RS
    output wire [DATA_WIDTH-1:0] rs_disp_A_imm_o,
    rs_disp_B_imm_o,
    output wire rs_disp_A_use_imm_o,
    rs_disp_B_use_imm_o,

    // Outputs to ROB
    output wire rob_alloc_A_o,
    rob_alloc_B_o,
    output wire rob_A_writes_rd_o,
    rob_B_writes_rd_o,
    output wire [ARCH_ADDR_W-1:0] rob_A_arch_dest_o,
    rob_B_arch_dest_o,
    output wire [PHYS_ADDR_W-1:0] rob_A_phys_dest_o,
    rob_B_phys_dest_o,
    output wire [PHYS_ADDR_W-1:0] rob_A_old_phys_dest_o,
    rob_B_old_phys_dest_o
);

  // Combine stall logic correctly considering the Reservation Station
  wire slot_A_blocked = rs_stall_A_i | rob_full_i;
  wire slot_B_blocked = rs_stall_B_i | rob_full_i | slot_A_blocked;  // B waits if A stalls

  assign fe_stall_o = (rn_A_valid_i & slot_A_blocked) | (rn_B_valid_i & slot_B_blocked);

  // RS dispatch outputs
  assign rs_disp_A_valid_o = rn_A_valid_i & ~slot_A_blocked;
  assign rs_disp_A_op_o = dec_A_op_i;
  assign rs_disp_A_pj_o = rn_A_rs1_phys_i;
  assign rs_disp_A_pk_o = rn_A_rs2_phys_i;
  assign rs_disp_A_pd_o = rn_A_rd_phys_i;
  assign rs_disp_A_rob_idx_o = rob_tail_i;
  assign rs_disp_A_imm_o = dec_A_imm_i;
  assign rs_disp_A_use_imm_o = dec_A_use_imm_i;

  assign rs_disp_B_valid_o = rn_B_valid_i & ~slot_B_blocked;
  assign rs_disp_B_op_o = dec_B_op_i;
  assign rs_disp_B_pj_o = rn_B_rs1_phys_i;
  assign rs_disp_B_pk_o = rn_B_rs2_phys_i;
  assign rs_disp_B_pd_o = rn_B_rd_phys_i;
  assign rs_disp_B_rob_idx_o = rs_disp_A_valid_o ? (rob_tail_i + 3'd1) : rob_tail_i;
  assign rs_disp_B_imm_o = dec_B_imm_i;
  assign rs_disp_B_use_imm_o = dec_B_use_imm_i;

  // ROB outputs
  assign rob_alloc_A_o = rs_disp_A_valid_o;
  assign rob_A_arch_dest_o = dec_A_rd_arch_i;
  assign rob_A_phys_dest_o = rn_A_rd_phys_i;
  assign rob_A_old_phys_dest_o = rn_A_rd_old_phys_i;
  assign rob_A_writes_rd_o = dec_A_writes_rd_i;

  assign rob_alloc_B_o = rs_disp_B_valid_o;
  assign rob_B_arch_dest_o = dec_B_rd_arch_i;
  assign rob_B_phys_dest_o = rn_B_rd_phys_i;
  assign rob_B_old_phys_dest_o = rn_B_rd_old_phys_i;
  assign rob_B_writes_rd_o = dec_B_writes_rd_i;

endmodule
