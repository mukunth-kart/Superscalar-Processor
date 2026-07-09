`timescale 1ns / 1ps

module tb_register_file ();

  // DUT signals
  reg clk, reset;
  reg [5:0] rd_addr1, rd_addr2, rd_addr3, rd_addr4;
  wire [31:0] rd_data1, rd_data2, rd_data3, rd_data4;
  wire rd_ready1, rd_ready2, rd_ready3, rd_ready4;
  reg wr_en1, wr_en2;
  reg [5:0] wr_addr1, wr_addr2;
  reg [31:0] wr_data1, wr_data2;
  reg alloc_en;
  reg [5:0] alloc_addr;

  // Instantiate DUT
  register_file dut (
      .clk_i  (clk),
      .reset_i(reset),

      .rd_addr1_i(rd_addr1),
      .rd_addr2_i(rd_addr2),
      .rd_addr3_i(rd_addr3),
      .rd_addr4_i(rd_addr4),

      .rd_data1_o(rd_data1),
      .rd_data2_o(rd_data2),
      .rd_data3_o(rd_data3),
      .rd_data4_o(rd_data4),

      .rd_ready1_o(rd_ready1),
      .rd_ready2_o(rd_ready2),
      .rd_ready3_o(rd_ready3),
      .rd_ready4_o(rd_ready4),

      .wr_en1_i  (wr_en1),
      .wr_addr1_i(wr_addr1),
      .wr_data1_i(wr_data1),

      .wr_en2_i  (wr_en2),
      .wr_addr2_i(wr_addr2),
      .wr_data2_i(wr_data2),

      .alloc_en_i  (alloc_en),
      .alloc_addr_i(alloc_addr)
  );

  // Clock
  always #5 clk = ~clk;  // 100 MHz

  // Self-checking helper
  integer errors = 0;

  task check_data;
    input [31:0] actual;
    input [31:0] expected;
    input [255:0] label;
    begin
      if (actual === expected) $display("PASS: %s (got %h)", label, actual);
      else begin
        $display("FAIL: %s (expected %h, got %h)", label, expected, actual);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    // Init
    clk = 0;
    reset = 1;
    wr_en1 = 0;
    wr_en2 = 0;
    alloc_en = 0;
    rd_addr1 = 0;
    rd_addr2 = 0;
    rd_addr3 = 0;
    rd_addr4 = 0;

    #20;
    reset = 0;

    // Test 1: Read after reset -> 0
    rd_addr1 = 6'd5;
    #1;
    check_data(rd_data1, 32'h0, "Read after reset");

    // Test 2: Write then read
    @(posedge clk);
    wr_en1   <= 1;
    wr_addr1 <= 6'd5;
    wr_data1 <= 32'hDEAD_BEEF;

    @(posedge clk);
    wr_en1 <= 0;

    #1;
    rd_addr1 = 6'd5;
    #1;
    check_data(rd_data1, 32'hDEAD_BEEF, "Write then read");

    // Test 3: Write-before-read bypass
    @(posedge clk);
    wr_en1   <= 1;
    wr_addr1 <= 6'd10;
    wr_data1 <= 32'hCAFE_BABE;
    rd_addr1 <= 6'd10;

    #1;
    check_data(rd_data1, 32'hCAFE_BABE, "Write-before-read bypass");

    // Test 4: Simultaneous writes to different addresses
    @(posedge clk);
    wr_en1   <= 1;
    wr_addr1 <= 6'd20;
    wr_data1 <= 32'h1111_1111;

    wr_en2   <= 1;
    wr_addr2 <= 6'd21;
    wr_data2 <= 32'h2222_2222;

    @(posedge clk);
    wr_en1 <= 0;
    wr_en2 <= 0;

    rd_addr1 = 6'd20;
    rd_addr2 = 6'd21;

    #1;
    check_data(rd_data1, 32'h1111_1111, "Simultaneous write port 1");
    check_data(rd_data2, 32'h2222_2222, "Simultaneous write port 2");

    // Test 5: Four simultaneous reads
    rd_addr1 = 6'd5;
    rd_addr2 = 6'd10;
    rd_addr3 = 6'd20;
    rd_addr4 = 6'd21;

    #1;
    check_data(rd_data1, 32'hDEAD_BEEF, "4-way read port 1");
    check_data(rd_data2, 32'hCAFE_BABE, "4-way read port 2");
    check_data(rd_data3, 32'h1111_1111, "4-way read port 3");
    check_data(rd_data4, 32'h2222_2222, "4-way read port 4");

    // Test 6: Allocate clears ready bit
    @(posedge clk);
    alloc_en   <= 1;
    alloc_addr <= 6'd5;

    @(posedge clk);
    alloc_en <= 0;

    #1;
    rd_addr1 = 6'd5;
    #1;

    if (rd_ready1 === 1'b0) $display("PASS: Allocate clears ready bit");
    else begin
      $display("FAIL: Allocate did not clear ready (got %b)", rd_ready1);
      errors = errors + 1;
    end

    // Test 7: Write after allocate sets ready bit back
    @(posedge clk);
    wr_en1   <= 1;
    wr_addr1 <= 6'd5;
    wr_data1 <= 32'h99;

    @(posedge clk);
    wr_en1 <= 0;

    #1;
    rd_addr1 = 6'd5;
    #1;

    if (rd_ready1 === 1'b1) $display("PASS: Write sets ready bit");
    else begin
      $display("FAIL: Write did not set ready (got %b)", rd_ready1);
      errors = errors + 1;
    end

    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("FAILED %0d TESTS", errors);

    $finish;
  end

endmodule
