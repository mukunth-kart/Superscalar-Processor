## Week 3

Week 3's content introduced me to Physical Registers vs Architectural Registers. Modern processors use physical register file indices as tags, compared to the reservation station names according to classical Tomasulo's.

The physical reg file is the actual hardware storage, whereas the architectural reg file is what the programmer sees. The **Rename Map** is what maps these both - arch reg R is actually stored in phys reg P. **Free List** is a queue of free phys regs.

The **Reorder Buffer (ROB)** is a buffer of entries, allocated in program order at dispatch, that helps in rollback of the registers when a branch fails.
There are 3 stages to the ROB - Dispatch, Completion and Commit.

In the register_file.v - most important thing - **Write-before-read forwarding** -> if a write port and a read port target the same address in the same cycle, the read will return the new data with ready bit set.

Also, Allocation happens at dispatch whereas writing happens at the end of execution.

In the rename_unit.v - We used single issue for this week, and the most important thing was **WAW dissolution** - the renamer assigns 2 different physical regs to the back to back dispatches writing the same arch reg.

I faced some errors while simulating the rename unit in tests 3,4 & 6.

Errors regarding tests 3 & 4 were due to blocking and non-blocking assignments - the idle task's scheduled assignment accidentally overwrote the immediate assignment in the next test. Fixed it by adding a "@(posedge clk);" and synchronizing the simulation.

In test 6, leaving the dispatch signal HIGH after the loop caused the hardware to stall. Hardware doesn't know a loop ended - so I manually pulled the inputs LOW to fix it.

---

## Week 4

In this week, I have learned the theory on branch prediction. I started with the basic 60% accurate static prediction and then improved to the 80% accurate 1-bit dynamic predictor, then to the 2-bit saturating counter with accuracy known to be 90%. The 2-bit counter is the standard; Each branch has a 2-bit state machine. It also eliminates the loop re-entry mispredict and limits the mispredictions for a loop to be 1 - at exit only.

Branch History Table (BHT) follows the best effort prediction. It gives us the direction - Taken or Not Taken. BHT is an array of 2-bit counters indexed by the PC, typically consists of 1024 entries - PC[11:2]. Aliasing/Collisions between different branches are the main source of error.

Branch Target Buffer (BTB) caches the PC -> target_address map, so that a predicted-taken branch can redirect fetch in the same cycle!
BTB gives us the target.

Together, fetch read BHT and BTB in parallel with the instruction fetch, updates the PC speculatively and corrects on EX-stage resolution.

Our PRAVAH design uses 2-bit BHT of 256 entries - PC[7:2] and no BTB - for simplicity.

Then I went on to the **Reservation Station** micro-architecture. In every cycle, each RS does 3 things in parallel - Snoop(early in cycle), Select(mid-cycle) and Issue(late in cycle) and then it starts executing. After issuing, RS clears its busy bit immediately.

PRAVAH uses 4 RS for ALU, 2 for MUL and 2 for LSU.

Next I went on to testing the RS code - I faced compilation errors with the unpacked array ports, so I flattened them to a single wide bus and sliced them in the testbench.

In the testbench, I have added 2 more tests to the skeleton - mid execution reset & refilling a freed slot.

Errors I faced with the testbench were in test 4- the testbench set the ready bits of P10, P11 and P13 high before P12 clocked out. So the priority encoder saw P10 and cleared it's slot before P12's. I fixed it by inserting a clock edge to let P12 be freed before waking up the others.

Also in test 6 - I immediately pulled the disp_valid <= 0 before checking the stall. A processor doesn't stall just because the reservation station is full; it only stalls if it is actively trying to dispatch a new instruction and there is no room. I fixed this by checking for stall while the disp_valid was still high.

---

## Week 5

In this week, I learnt about the transition from single-issue to a 2-wide superscalar front-end. I learnt about fetch, decode, rename (widened) and dispatch. 2-wide actually means that every pipeline stage now has parallel lanes, A - the first and then B - the next slot for the instructions. Fetch reads 2 instructions per cycle, Decode runs 2 independent decoders, Rename does 6 reads(2 src + 1 dst) and 2 writes per cycle and then dispatch allocates 2 RS and 2 RoB entries per cycle. Also, going wider than 2 has more complexity and less returns! The new complexities introduced due to going wider - Intra bundle dependencies in rename and dispatch.

Fetch keeps on reading 2 consecutive instructions per cycle irrespective of branch - prediction = NT. It advances PC by 8 each cycle and PRAVAH sidesteps the alignment problem(What if the current PC is misaligned with the memory's natural 64-bit boundary?) by requiring test programs to start at PC=0 with an even instr count.

Decode is purely combinational wiring, extracts stuff via case statements. 2 independent decoders run for A & B with no interaction.

Intra-bundle dependencies - total of 5 cases ->
case-1 : B reads what A writes(RAW within bundle);
case-2 : A & B write the same reg(WAW within bundle);
case-3 : B reads what A reads;
case-4 : A is a branch that squashes B;
case-5 : A or B cannot dispatch - stalls(only 1 free phys reg => dispatch A, hold B).

Then Dispatch is the bridge between frontend and backend. For each slot, it calls rename, finds a free RS for the target FU, writes the RS entry and allocates a RoB entry. RoB isn't built this week, dispaych only talks to a stubbed interface - testbench takes care of it.

In Verilog, I have coded fetch.v, decode.v, widened the rename_unit.v, dispatch.v and then widened the reservation_station.v before finally writing the testbench - tb_frontend.v .

While running the simulation, I have faced a simulation error in the tb_frontend while trying to read test1.hex. I then realized that $readmemh requires strict ASCII/UTF-8, but my test1.hex was in UTF-16 encoding => nulls between each character, which Modelsim cannot read! It is fixed by changing it to UTF-8.

I then successfully verified the bypass logic through the simulation of the given 10-instructions.

## Week 6

This week was the most important task in the whole project, the integration phase! I've successfully integrated an OoO execution with an in-order commit using the Reorder Buffer, RoB.

This week, I was asked to execute a program that does dot product of 2 vectors. It consisted a total of 9 instructions, only ADDI and ADD. While simulating the testbench, I faced 3 main bugs:

1. the combinational loop - vsim-3601 iteration limit reached: simulation froze at 75ns! I have identified that the root cause was an infinite loop between dispatch and RS, the RS stall signal depended on the dispatch valid signal but the dispatch valid signal dropped because of the stall - endless feedback loop! - `disp_stall_o = disp_valid & (rs_free == 0)`

I fixed it by removing the dependance of RS stall on dispatch valid - `disp_stall_o = (rs_free == 0)`

2. the 1-bit wire truncation - X cascade in the waveform: The RoB skipped from index 6 to 1, causing the rename unit to give out the same phys reg twice, leading to double-wire collisions and X/unknown states. In rob.v, I wrote `wire head1_idx = (head + 1) % ROB_SIZE` => Verilog defaulted the head1_idx to 1-bit, so 7 = 111 was truncated to just 1.

I fixed it by just declaring the bit width for the head_idx.

3. the PRF[0] collision/Pipeline flush: At the very end of the simulation, multiple X states appeared on the writeback buses. To safely flush the pipeline, I have padded the instruction memory with NOPs (`addi x0, x0, 0`). However the decode module flagged `writes_rd = 1` without checking that rd = 0! => Both ALUs executed a NOP and tried to write to a phys reg 0 at the same time, causing multiple driver collision.

I fixed this by adding a strict `rd_arch_o != 5'd0` check in the decoder => NOP never triggers a phys reg allocation or writeback.

## Week 7

The main thing I did this week was IPC measurement using a performance monitoring, non-synthesizable testbench. I also analyzed the IPC gap between theoretical and actual performance. I saw how RAW data dependencies actually limit the throughput of the processor. I also learnt about ILP - Instruction Level Parallelism and how the mixed benchmark was made to maximize it. I also saw the effect of pipeline fill & drain in the IPC gap between end to end and steady state.

While simulating, I noticed that the use of non-blocking assignments in separate if blocks to icrement the commit counter for A & B, made them overwrite each other if both commit simultaneously!
