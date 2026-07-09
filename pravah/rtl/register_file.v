module register_file #(
    parameter NUM_PHYS_REGS = 48,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 6  // log2(48) rounded up
) (
    input wire clk_i,
    input wire reset_i,

    // Four read ports (each returns value + ready bit)
    input wire [ADDR_WIDTH-1:0] rd_addr1_i,
    input wire [ADDR_WIDTH-1:0] rd_addr2_i,
    input wire [ADDR_WIDTH-1:0] rd_addr3_i,
    input wire [ADDR_WIDTH-1:0] rd_addr4_i,
    output wire [DATA_WIDTH-1:0] rd_data1_o,
    output wire [DATA_WIDTH-1:0] rd_data2_o,
    output wire [DATA_WIDTH-1:0] rd_data3_o,
    output wire [DATA_WIDTH-1:0] rd_data4_o,
    output wire rd_ready1_o,
    output wire rd_ready2_o,
    output wire rd_ready3_o,
    output wire rd_ready4_o,

    // Two write ports (each sets value AND sets ready=1)
    input wire wr_en1_i,
    input wire [ADDR_WIDTH-1:0] wr_addr1_i,
    input wire [DATA_WIDTH-1:0] wr_data1_i,
    input wire wr_en2_i,
    input wire [ADDR_WIDTH-1:0] wr_addr2_i,
    input wire [DATA_WIDTH-1:0] wr_data2_i,

    // NEW FOR WEEK 6: Two Allocate ports 
    // (clears ready bit when a register is newly allocated)
    input wire alloc_en1_i,
    input wire [ADDR_WIDTH-1:0] alloc_addr1_i,
    input wire alloc_en2_i,
    input wire [ADDR_WIDTH-1:0] alloc_addr2_i
);

  // Storage: value array and ready-bit array
  reg [DATA_WIDTH-1:0] regs[0:NUM_PHYS_REGS-1];
  reg ready[0:NUM_PHYS_REGS-1];
  integer i;

  //----Synchronous state update---
  always @(posedge clk_i) begin
    if (reset_i) begin
      for (i = 0; i < NUM_PHYS_REGS; i = i + 1) begin
        regs[i]  <= 32'b0;
        ready[i] <= 1'b1;  // At reset, all PRF entries are "ready" (hold valid zero)
      end
    end else begin
      // 1. Writes set value AND ready bit
      if (wr_en1_i) begin
        regs[wr_addr1_i]  <= wr_data1_i;
        ready[wr_addr1_i] <= 1'b1;
      end
      if (wr_en2_i) begin
        regs[wr_addr2_i]  <= wr_data2_i;
        ready[wr_addr2_i] <= 1'b1;
      end

      // 2. Allocation clears the ready bit (Port 1)
      if (alloc_en1_i &&
          !(wr_en1_i && (wr_addr1_i == alloc_addr1_i)) &&
          !(wr_en2_i && (wr_addr2_i == alloc_addr1_i))) begin
        ready[alloc_addr1_i] <= 1'b0;
      end

      // 3. Allocation clears the ready bit (Port 2)
      if (alloc_en2_i &&
          !(wr_en1_i && (wr_addr1_i == alloc_addr2_i)) &&
          !(wr_en2_i && (wr_addr2_i == alloc_addr2_i))) begin
        ready[alloc_addr2_i] <= 1'b0;
      end
    end
  end

  //----Combinational reads with write-before-read bypass---
  assign rd_data1_o = (wr_en1_i && (wr_addr1_i == rd_addr1_i)) 
        ? wr_data1_i : (wr_en2_i && (wr_addr2_i == rd_addr1_i))
            ? wr_data2_i : regs[rd_addr1_i];

  assign rd_ready1_o = (wr_en1_i && (wr_addr1_i == rd_addr1_i))
        ? 1'b1 : (wr_en2_i && (wr_addr2_i == rd_addr1_i))
            ? 1'b1 : ready[rd_addr1_i];

  assign rd_data2_o = (wr_en1_i && (wr_addr1_i == rd_addr2_i))
        ? wr_data1_i : (wr_en2_i && (wr_addr2_i == rd_addr2_i))
            ? wr_data2_i : regs[rd_addr2_i];

  assign rd_ready2_o = (wr_en1_i && (wr_addr1_i == rd_addr2_i))
        ? 1'b1 : (wr_en2_i && (wr_addr2_i == rd_addr2_i))
            ? 1'b1 : ready[rd_addr2_i];

  assign rd_data3_o = (wr_en1_i && (wr_addr1_i == rd_addr3_i))
        ? wr_data1_i : (wr_en2_i && (wr_addr2_i == rd_addr3_i))
            ? wr_data2_i : regs[rd_addr3_i];

  assign rd_ready3_o = (wr_en1_i && (wr_addr1_i == rd_addr3_i))
        ? 1'b1 : (wr_en2_i && (wr_addr2_i == rd_addr3_i))
            ? 1'b1 : ready[rd_addr3_i];

  assign rd_data4_o = (wr_en1_i && (wr_addr1_i == rd_addr4_i))
        ? wr_data1_i : (wr_en2_i && (wr_addr2_i == rd_addr4_i))
            ? wr_data2_i : regs[rd_addr4_i];

  assign rd_ready4_o = (wr_en1_i && (wr_addr1_i == rd_addr4_i))
        ? 1'b1 : (wr_en2_i && (wr_addr2_i == rd_addr4_i))
            ? 1'b1 : ready[rd_addr4_i];

endmodule
