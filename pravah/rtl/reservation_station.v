module reservation_station #(
    parameter NUM_RS = 4,
    parameter PHYS_ADDR_W = 6,  // log2(48)
    parameter ROB_ADDR_W = 3,  // log2(8 ROB entries)
    parameter OP_WIDTH = 4,  // op encoding bits
    parameter DATA_WIDTH = 32  // 32-bit immediate
) (
    input wire clk_i,
    input wire reset_i,

    // Dispatch port - SLOT A
    input wire disp_A_valid_i,
    input wire [OP_WIDTH-1:0] disp_A_op_i,
    input wire [PHYS_ADDR_W-1:0] disp_A_pj_i,
    input wire [PHYS_ADDR_W-1:0] disp_A_pk_i,
    input wire [PHYS_ADDR_W-1:0] disp_A_pd_i,
    input wire [ROB_ADDR_W-1:0] disp_A_rob_idx_i,
    input wire [DATA_WIDTH-1:0] disp_A_imm_i,
    input wire disp_A_use_imm_i,
    output wire disp_stall_A_o,

    // Dispatch port - SLOT B
    input wire disp_B_valid_i,
    input wire [OP_WIDTH-1:0] disp_B_op_i,
    input wire [PHYS_ADDR_W-1:0] disp_B_pj_i,
    input wire [PHYS_ADDR_W-1:0] disp_B_pk_i,
    input wire [PHYS_ADDR_W-1:0] disp_B_pd_i,
    input wire [ROB_ADDR_W-1:0] disp_B_rob_idx_i,
    input wire [DATA_WIDTH-1:0] disp_B_imm_i,
    input wire disp_B_use_imm_i,
    output wire disp_stall_B_o,

    // PRF ready-bit snoop
    output wire [(NUM_RS*PHYS_ADDR_W)-1:0] snoop_pj_addr_o,
    output wire [(NUM_RS*PHYS_ADDR_W)-1:0] snoop_pk_addr_o,
    input wire [NUM_RS-1:0] snoop_pj_ready_i,
    input wire [NUM_RS-1:0] snoop_pk_ready_i,

    // Issue port 0 (to ALU0)
    output wire issue_0_valid_o,
    output wire [OP_WIDTH-1:0] issue_0_op_o,
    output wire [PHYS_ADDR_W-1:0] issue_0_pj_o,
    output wire [PHYS_ADDR_W-1:0] issue_0_pk_o,
    output wire [PHYS_ADDR_W-1:0] issue_0_pd_o,
    output wire [ROB_ADDR_W-1:0] issue_0_rob_idx_o,
    output wire [DATA_WIDTH-1:0] issue_0_imm_o,
    output wire issue_0_use_imm_o,

    // Issue port 1 (to ALU1)
    output wire issue_1_valid_o,
    output wire [OP_WIDTH-1:0] issue_1_op_o,
    output wire [PHYS_ADDR_W-1:0] issue_1_pj_o,
    output wire [PHYS_ADDR_W-1:0] issue_1_pk_o,
    output wire [PHYS_ADDR_W-1:0] issue_1_pd_o,
    output wire [ROB_ADDR_W-1:0] issue_1_rob_idx_o,
    output wire [DATA_WIDTH-1:0] issue_1_imm_o,
    output wire issue_1_use_imm_o
);

  // Per-RS state arrays
  reg rs_busy[0:NUM_RS-1];
  reg [OP_WIDTH-1:0] rs_op[0:NUM_RS-1];
  reg [PHYS_ADDR_W-1:0] rs_pj[0:NUM_RS-1];
  reg [PHYS_ADDR_W-1:0] rs_pk[0:NUM_RS-1];
  reg [PHYS_ADDR_W-1:0] rs_pd[0:NUM_RS-1];
  reg [ROB_ADDR_W-1:0] rs_rob_idx[0:NUM_RS-1];
  reg [DATA_WIDTH-1:0] rs_imm[0:NUM_RS-1];
  reg rs_use_imm[0:NUM_RS-1];

  wire [NUM_RS-1:0] rs_wakeup_ready;
  wire [NUM_RS-1:0] rs_free;

  // 2-Wide Issue Signals
  wire [NUM_RS-1:0] issue_select_0;
  wire [NUM_RS-1:0] remaining_rs;
  wire [NUM_RS-1:0] issue_select_1;

  // 2-Wide Dispatch signals
  wire [NUM_RS-1:0] mask_A;
  wire [NUM_RS-1:0] dispatch_select_A;
  wire [NUM_RS-1:0] rs_free_after_A;
  wire [NUM_RS-1:0] mask_B;
  wire [NUM_RS-1:0] dispatch_select_B;

  integer i;
  genvar g;

  generate
    for (g = 0; g < NUM_RS; g = g + 1) begin : snoop_gen
      assign snoop_pj_addr_o[(g*PHYS_ADDR_W)+:PHYS_ADDR_W] = rs_pj[g];
      assign snoop_pk_addr_o[(g*PHYS_ADDR_W)+:PHYS_ADDR_W] = rs_pk[g];
    end
  endgenerate

  generate
    for (g = 0; g < NUM_RS; g = g + 1) begin : wakeup_gen
      // Wakeup logic ignores pk_ready if use_imm is 1
      assign rs_wakeup_ready[g] = rs_busy[g] & snoop_pj_ready_i[g] & (rs_use_imm[g] | snoop_pk_ready_i[g]);
      assign rs_free[g] = ~rs_busy[g];
    end
  endgenerate

  // --- 2-Wide Issue Logic (Mask-and-Encode) ---

  // Pick first issue (ALU0)
  assign issue_select_0[0] = rs_wakeup_ready[0];
  assign issue_select_0[1] = rs_wakeup_ready[1] & ~rs_wakeup_ready[0];
  assign issue_select_0[2] = rs_wakeup_ready[2] & ~rs_wakeup_ready[1] & ~rs_wakeup_ready[0];
  assign issue_select_0[3] = rs_wakeup_ready[3] & ~rs_wakeup_ready[2] & ~rs_wakeup_ready[1] & ~rs_wakeup_ready[0];

  // Mask out the first selection
  assign remaining_rs = rs_wakeup_ready & ~issue_select_0;

  // Pick second issue (ALU1)
  assign issue_select_1[0] = remaining_rs[0];
  assign issue_select_1[1] = remaining_rs[1] & ~remaining_rs[0];
  assign issue_select_1[2] = remaining_rs[2] & ~remaining_rs[1] & ~remaining_rs[0];
  assign issue_select_1[3] = remaining_rs[3] & ~remaining_rs[2] & ~remaining_rs[1] & ~remaining_rs[0];

  // --- Dispatch Selection Logic ---
  assign mask_A[0] = rs_free[0];
  assign mask_A[1] = rs_free[1] & ~rs_free[0];
  assign mask_A[2] = rs_free[2] & ~rs_free[1] & ~rs_free[0];
  assign mask_A[3] = rs_free[3] & ~rs_free[2] & ~rs_free[1] & ~rs_free[0];
  assign dispatch_select_A = {NUM_RS{disp_A_valid_i}} & mask_A;

  assign rs_free_after_A = rs_free & ~dispatch_select_A;

  assign mask_B[0] = rs_free_after_A[0];
  assign mask_B[1] = rs_free_after_A[1] & ~rs_free_after_A[0];
  assign mask_B[2] = rs_free_after_A[2] & ~rs_free_after_A[1] & ~rs_free_after_A[0];
  assign mask_B[3] = rs_free_after_A[3] & ~rs_free_after_A[2] & ~rs_free_after_A[1] & ~rs_free_after_A[0];
  assign dispatch_select_B = {NUM_RS{disp_B_valid_i}} & mask_B;

  assign disp_stall_A_o = (rs_free == 4'b0000);
  assign disp_stall_B_o = (rs_free_after_A == 4'b0000);

  // --- ALU0 Issue Bus ---
  assign issue_0_valid_o = |issue_select_0;

  assign issue_0_op_o = issue_select_0[0] ? rs_op[0] :
                        issue_select_0[1] ? rs_op[1] :
                        issue_select_0[2] ? rs_op[2] : rs_op[3];

  assign issue_0_pj_o = issue_select_0[0] ? rs_pj[0] :
                        issue_select_0[1] ? rs_pj[1] :
                        issue_select_0[2] ? rs_pj[2] : rs_pj[3];

  assign issue_0_pk_o = issue_select_0[0] ? rs_pk[0] :
                        issue_select_0[1] ? rs_pk[1] :
                        issue_select_0[2] ? rs_pk[2] : rs_pk[3];

  assign issue_0_pd_o = issue_select_0[0] ? rs_pd[0] :
                        issue_select_0[1] ? rs_pd[1] :
                        issue_select_0[2] ? rs_pd[2] : rs_pd[3];

  assign issue_0_rob_idx_o = issue_select_0[0] ? rs_rob_idx[0] :
                             issue_select_0[1] ? rs_rob_idx[1] :
                             issue_select_0[2] ? rs_rob_idx[2] : rs_rob_idx[3];

  assign issue_0_imm_o = issue_select_0[0] ? rs_imm[0] :
                         issue_select_0[1] ? rs_imm[1] :
                         issue_select_0[2] ? rs_imm[2] : rs_imm[3];

  assign issue_0_use_imm_o = issue_select_0[0] ? rs_use_imm[0] :
                             issue_select_0[1] ? rs_use_imm[1] :
                             issue_select_0[2] ? rs_use_imm[2] : rs_use_imm[3];

  // --- ALU1 Issue Bus ---
  assign issue_1_valid_o = |issue_select_1;

  assign issue_1_op_o = issue_select_1[0] ? rs_op[0] :
                        issue_select_1[1] ? rs_op[1] :
                        issue_select_1[2] ? rs_op[2] : rs_op[3];

  assign issue_1_pj_o = issue_select_1[0] ? rs_pj[0] :
                        issue_select_1[1] ? rs_pj[1] :
                        issue_select_1[2] ? rs_pj[2] : rs_pj[3];

  assign issue_1_pk_o = issue_select_1[0] ? rs_pk[0] :
                        issue_select_1[1] ? rs_pk[1] :
                        issue_select_1[2] ? rs_pk[2] : rs_pk[3];

  assign issue_1_pd_o = issue_select_1[0] ? rs_pd[0] :
                        issue_select_1[1] ? rs_pd[1] :
                        issue_select_1[2] ? rs_pd[2] : rs_pd[3];

  assign issue_1_rob_idx_o = issue_select_1[0] ? rs_rob_idx[0] :
                             issue_select_1[1] ? rs_rob_idx[1] :
                             issue_select_1[2] ? rs_rob_idx[2] : rs_rob_idx[3];

  assign issue_1_imm_o = issue_select_1[0] ? rs_imm[0] :
                         issue_select_1[1] ? rs_imm[1] :
                         issue_select_1[2] ? rs_imm[2] : rs_imm[3];

  assign issue_1_use_imm_o = issue_select_1[0] ? rs_use_imm[0] :
                             issue_select_1[1] ? rs_use_imm[1] :
                             issue_select_1[2] ? rs_use_imm[2] : rs_use_imm[3];

  // --- Synchronous State Update ---
  always @(posedge clk_i) begin
    if (reset_i) begin
      for (i = 0; i < NUM_RS; i = i + 1) begin
        rs_busy[i] <= 1'b0;
        rs_op[i] <= {OP_WIDTH{1'b0}};
        rs_pj[i] <= {PHYS_ADDR_W{1'b0}};
        rs_pk[i] <= {PHYS_ADDR_W{1'b0}};
        rs_pd[i] <= {PHYS_ADDR_W{1'b0}};
        rs_rob_idx[i] <= {ROB_ADDR_W{1'b0}};
        rs_imm[i] <= {DATA_WIDTH{1'b0}};
        rs_use_imm[i] <= 1'b0;
      end
    end else begin
      // Clear busy bit if issued to EITHER ALU
      for (i = 0; i < NUM_RS; i = i + 1) begin
        if (issue_select_0[i] | issue_select_1[i]) begin
          rs_busy[i] <= 1'b0;
        end
      end

      for (i = 0; i < NUM_RS; i = i + 1) begin
        // Slot A Dispatch
        if (dispatch_select_A[i]) begin
          rs_busy[i] <= 1'b1;
          rs_op[i] <= disp_A_op_i;
          rs_pj[i] <= disp_A_pj_i;
          rs_pk[i] <= disp_A_pk_i;
          rs_pd[i] <= disp_A_pd_i;
          rs_rob_idx[i] <= disp_A_rob_idx_i;
          rs_imm[i] <= disp_A_imm_i;
          rs_use_imm[i] <= disp_A_use_imm_i;
        end  // Slot B Dispatch
        else if (dispatch_select_B[i]) begin
          rs_busy[i] <= 1'b1;
          rs_op[i] <= disp_B_op_i;
          rs_pj[i] <= disp_B_pj_i;
          rs_pk[i] <= disp_B_pk_i;
          rs_pd[i] <= disp_B_pd_i;
          rs_rob_idx[i] <= disp_B_rob_idx_i;
          rs_imm[i] <= disp_B_imm_i;
          rs_use_imm[i] <= disp_B_use_imm_i;
        end
      end
    end
  end

endmodule
