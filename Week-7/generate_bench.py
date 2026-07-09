def encode_r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i_type(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def addi(rd, rs1, imm):
    return encode_i_type(imm, rs1, 0b000, rd, 0b0010011)

def add(rd, rs1, rs2):
    return encode_r_type(0b0000000, rs2, rs1, 0b000, rd, 0b0110011)

instructions1 = [ # independent instructions
  addi(1,  0, 1),   addi(2,  0, 2),
  addi(3,  0, 3),   addi(4,  0, 4),
  addi(5,  0, 5),   addi(6,  0, 6),
  addi(7,  0, 7),   addi(8,  0, 8),
  addi(9,  0, 9),   addi(10, 0, 10),
  addi(11, 0, 11),  addi(12, 0, 12),
  addi(13, 0, 13),  addi(14, 0, 14),
  addi(15, 0, 15),  addi(16, 0, 16),
]

instructions2 = [ # chain of dependent instructions
  addi(1, 0, 1),     # x1 = 1
  add(2,  1, 1),     # x2 = x1 + x1  (depends on x1)
  add(3,  2, 2),     # x3 = x2 + x2  (depends on x2)
  add(4,  3, 3),
  add(5,  4, 4),
  add(6,  5, 5),
  add(7,  6, 6),
  add(8,  7, 7),
  add(9,  8, 8),
  add(10, 9, 9),
  add(11, 10, 10),
  add(12, 11, 11),
  add(13, 12, 12),
  add(14, 13, 13),
  add(15, 14, 14),
  add(16, 15, 15),
]

instructions3 = [ # mix of dependent and independent instructions
  addi(1, 0, 10),    addi(2, 0, 20),   # independent
  add(3,  1, 2),     add(4, 1, 2),     # both depend on x1,x2
  add(5,  3, 4),     addi(6, 0, 30),   # x5 depends; x6 independent
  add(7,  5, 6),     addi(8, 0, 40),   # x7 depends; x8 independent
  add(9,  7, 8),     addi(10, 0, 50),  # x9 depends; x10 independent
  add(11, 9, 10),    add(12, 1, 2),    # x11 depends; x12 independent
  add(13, 11, 12),   add(14, 6, 8),    # x13 depends; x14 independent
  add(15, 13, 14),   add(16, 15, 1),   # both depend
]

for ins in instructions3:
    print(f"{ins:08X}")