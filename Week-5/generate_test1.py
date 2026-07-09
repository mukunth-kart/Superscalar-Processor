# generate_test1.py
# Run: python3 generate_test1.py > programs/test1.hex
# Produces the 10-instruction test program as a hex file for $readmemh.

def encode_r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i_type(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def addi(rd, rs1, imm):
    return encode_i_type(imm, rs1, 0b000, rd, 0b0010011)

def add(rd, rs1, rs2):
    return encode_r_type(0b0000000, rs2, rs1, 0b000, rd, 0b0110011)

instructions = [
addi(1, 0, 10), # addi x1, x0, 10
addi(2, 0, 20), # addi x2, x0, 20
add(3, 1, 2), # add x3, x1, x2
add(4, 3, 1), # add x4, x3, x1 (intra-bundle RAW)
add(5, 1, 2), # add x5, x1, x2
add(5, 3, 4), # add x5, x3, x4 (intra-bundle WAW)
add(6, 1, 2), # add x6, x1, x2
add(7, 1, 3), # add x7, x1, x3
add(8, 6, 7), # add x8, x6, x7
add(6, 1, 1), # add x6, x1, x1 (later x6 write)
]

for ins in instructions:
    print(f"{ins:08X}")