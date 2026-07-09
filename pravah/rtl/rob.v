module rob #(
    parameter ROB_SIZE = 8,
    parameter PHYS_ADDR_W = 6,
    parameter ARCH_ADDR_W = 5,
    parameter ROB_ADDR_W = 3  // log2(8)
) (
    input wire clk_i,
    input wire reset_i,

    // Dispatch ports (slot A and slot B)
    input wire alloc_A_i,
    input wire writes_rd_A_i,
    input wire [ARCH_ADDR_W-1:0] arch_dest_A_i,
    input wire [PHYS_ADDR_W-1:0] phys_dest_A_i,
    input wire [PHYS_ADDR_W-1:0] old_phys_dest_A_i,

    input wire alloc_B_i,
    input wire writes_rd_B_i,
    input wire [ARCH_ADDR_W-1:0] arch_dest_B_i,
    input wire [PHYS_ADDR_W-1:0] phys_dest_B_i,
    input wire [PHYS_ADDR_W-1:0] old_phys_dest_B_i,

    // Outputs for dispatch
    output wire [ROB_ADDR_W-1:0] tail_o,
    output wire full_o,

    // Mark-ready ports (from FUs)
    input wire mark_ready_0_en_i,
    input wire [ROB_ADDR_W-1:0] mark_ready_0_idx_i,
    input wire mark_ready_1_en_i,
    input wire [ROB_ADDR_W-1:0] mark_ready_1_idx_i,

    // Commit ports (to rename unit)
    output wire commit_A_valid_o,
    output wire [PHYS_ADDR_W-1:0] commit_A_old_phys_o,
    output wire commit_B_valid_o,
    output wire [PHYS_ADDR_W-1:0] commit_B_old_phys_o
);

  // ROB entry storage (decomposed into parallel arrays for clarity)
  reg rob_valid[0:ROB_SIZE-1];
  reg rob_ready[0:ROB_SIZE-1];
  reg rob_writes_rd[0:ROB_SIZE-1];
  reg [ARCH_ADDR_W-1:0] rob_arch_dest[0:ROB_SIZE-1];
  reg [PHYS_ADDR_W-1:0] rob_phys_dest[0:ROB_SIZE-1];
  reg [PHYS_ADDR_W-1:0] rob_old_phys[0:ROB_SIZE-1];

  // Pointers and count
  reg [ROB_ADDR_W-1:0] head, tail;
  reg [ROB_ADDR_W:0] count;  // extra bit to represent ROB_SIZE

  //--------Combinational outputs-------
  assign tail_o = tail;
  assign full_o = (count == ROB_SIZE);

  //--------Commit logic (combinational selection)-------
  // Slot A: head entry committable iff valid and ready
  wire head_committable = rob_valid[head] & rob_ready[head];
  wire [ROB_ADDR_W-1:0] head1_idx = (head + 1) % ROB_SIZE;
  wire head1_committable = rob_valid[head1_idx] & rob_ready[head1_idx] & head_committable;

  assign commit_A_valid_o = head_committable;
  assign commit_A_old_phys_o = rob_old_phys[head];
  assign commit_B_valid_o = head1_committable;
  assign commit_B_old_phys_o = rob_old_phys[head1_idx];

  //--------Helpers for state updates-------
  wire do_alloc_A = alloc_A_i;
  wire do_alloc_B = alloc_B_i;
  wire do_commit_A = head_committable;
  wire do_commit_B = head1_committable;

  wire [1:0] num_allocs = do_alloc_A + do_alloc_B;
  wire [1:0] num_commits = do_commit_A + do_commit_B;

  //--------Synchronous updates-------
  integer i;
  always @(posedge clk_i) begin
    if (reset_i) begin
      for (i = 0; i < ROB_SIZE; i = i + 1) begin
        rob_valid[i] <= 1'b0;
        rob_ready[i] <= 1'b0;
      end
      head  <= 0;
      tail  <= 0;
      count <= 0;
    end else begin

      // Allocate at tail (slot A)
      if (do_alloc_A) begin
        rob_valid[tail] <= 1'b1;
        rob_ready[tail] <= 1'b0;
        rob_writes_rd[tail] <= writes_rd_A_i;
        rob_arch_dest[tail] <= arch_dest_A_i;
        rob_phys_dest[tail] <= phys_dest_A_i;
        rob_old_phys[tail] <= old_phys_dest_A_i;
      end

      // Allocate at tail+1 (slot B), only if slot A also allocated
      if (do_alloc_A & do_alloc_B) begin
        rob_valid[(tail+1)%ROB_SIZE] <= 1'b1;
        rob_ready[(tail+1)%ROB_SIZE] <= 1'b0;
        rob_writes_rd[(tail+1)%ROB_SIZE] <= writes_rd_B_i;
        rob_arch_dest[(tail+1)%ROB_SIZE] <= arch_dest_B_i;
        rob_phys_dest[(tail+1)%ROB_SIZE] <= phys_dest_B_i;
        rob_old_phys[(tail+1)%ROB_SIZE] <= old_phys_dest_B_i;
      end

      // Mark-ready from FUs
      if (mark_ready_0_en_i) rob_ready[mark_ready_0_idx_i] <= 1'b1;
      if (mark_ready_1_en_i) rob_ready[mark_ready_1_idx_i] <= 1'b1;

      // Commit: invalidate head entries
      if (do_commit_A) rob_valid[head] <= 1'b0;
      if (do_commit_B) rob_valid[(head+1)%ROB_SIZE] <= 1'b0;

      // Advance pointers
      tail  <= (tail + num_allocs) % ROB_SIZE;
      head  <= (head + num_commits) % ROB_SIZE;
      count <= count + num_allocs - num_commits;
    end
  end

endmodule
