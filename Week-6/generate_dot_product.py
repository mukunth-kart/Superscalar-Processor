# generate_dot_product.py

def encode_r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i_type(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def addi(rd, rs1, imm):
    return encode_i_type(imm, rs1, 0b000, rd, 0b0010011)

def add(rd, rs1, rs2):
    return encode_r_type(0b0000000, rs2, rs1, 0b000, rd, 0b0110011)

instructions = [
    # Pre-load values
    addi(1, 0, 2),   # addi x1, x0, 2
    addi(2, 0, 3),   # addi x2, x0, 3
    addi(3, 0, 5),   # addi x3, x0, 5
    addi(4, 0, 7),   # addi x4, x0, 7
    
    # Compute partial products
    add(5, 1, 2),    # add x5, x1, x2  (x5 = 2 + 3 = 5)
    add(6, 3, 4),    # add x6, x3, x4  (x6 = 5 + 7 = 12)
    
    # Sum the partial products
    add(7, 5, 6),    # add x7, x5, x6  (x7 = 5 + 12 = 17)
    
    # Final WAW + WAR for test coverage
    add(5, 7, 7),    # add x5, x7, x7  (x5 = 17 + 17 = 34)
    add(6, 5, 1),    # add x6, x5, x1  (x6 = 34 + 2 = 36)
]

# Pad the end of the memory with 20 NOPs to prevent fetching uninitialized 'X' memory
for _ in range(20):
    instructions.append(addi(0, 0, 0))

for ins in instructions:
    print(f"{ins:08X}")