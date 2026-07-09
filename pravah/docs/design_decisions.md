# PRAVAH Design Decisions

**Status:** Locked at Week 4, Milestone 2.
**Changes** beyond this point require explicit approval and a documented reason in the project report.

This document is the architectural contract for the PRAVAH 2-wide out-of-order superscalar RISC-V processor. Every parameter below is a number we commit to for the remainder of the project.

---

## Pipeline width

| Parameter      | Value | Rationale                                |
| -------------- | ----- | ---------------------------------------- |
| Fetch width    | 2     | Matches issue width to simplify dispatch |
| Decode width   | 2     | Must match fetch width                   |
| Rename width   | 2     | Both instr renamed in the same cycle     |
| Dispatch width | 2     | For 2-wide design                        |
| Issue width    | 2     | For 2-wide design                        |
| Commit width   | 2     | To avoid bottlenecks                     |

---

## Register file

| Parameter           | Value | Rationale                         |
| ------------------- | ----- | --------------------------------- |
| Architectural regs  | 32    | RV32I                             |
| Physical regs (PRF) | 48    | 32 + 16 in-flight margin          |
| Free list size      | 16    | = 48 − 32                         |
| Read ports          | 4     | 2 for ALU0 (rs1, rs2), 2 for ALU1 |
| Write ports         | 2     | One per ALU, no contention        |
| Allocate ports      | 2     | One per dispatch slot             |

The PRF uses **per-register ready bits** (one bit per phys reg). Reservation stations snoop these bits combinationally to detect when their sources are ready. Write-before-read bypass returns same-cycle write data on a read.

---

## Reservation stations

| Parameter | Value | Rationale                                   |
| --------- | ----- | ------------------------------------------- |
| ALU RSs   | 4     | sufficient for 4 in-flight ALU instr        |
| MUL RSs   | 2     | 2 entries enough for single MUL unit        |
| LSU RSs   | 2     | 2 entries sufficient for single-port memory |
| **Total** | **8** | Typical small-machine ratio                 |

Rationale for total: With a ROB depth of 8 and 2-wide dispatch, 8 RS
slots means we can have the entire ROB filled without RS structural
stalls in the common case (all-ALU workloads). MUL and LSU get 2 each
since their functional units are single and their latencies are bounded.

---

## Reorder buffer

| Parameter        | Value | Rationale                               |
| ---------------- | ----- | --------------------------------------- |
| Depth            | 8     | Sufficient enough to show OoO behaviour |
| Dispatch ports   | 2     | Matches dispatch width                  |
| Mark-ready ports | 2     | Matches FU count (ALU0, ALU1)           |
| Commit ports     | 2     | Matches commit width                    |

The ROB enforces **in-order commit** even when execution is out-of-order. Each entry stores `{valid, ready, writes_rd, arch_dest, phys_dest, old_phys}`. On commit, `old_phys` returns to the rename unit's free list.

---

## Functional units

| FU  | Count | Latency                 | Notes                                                                                                                   |
| --- | ----- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| ALU | 2     | 1 cycle (combinational) | eg.Add/Sub/And/Or/Xor/Sll/Srl/Slt/Addi                                                                                  |
| MUL | 1     | 3-cycle pipelined       | **Module built and standalone-verified (16/16 tests). Awaiting top-level integration; see `docs/integration_plan.md`.** |
| LSU | 1     | 1-cycle blocking        | **Module built (`lsu.v` + `dmem.v`). Awaiting top-level integration; see `docs/integration_plan.md`.**                  |

`mul.v`, `lsu.v`, and `dmem.v` are all in `rtl/` and compile clean. They are not yet wired into `pravah_top.v` in the baseline. The integration steps are to be documented in `docs/integration_plan.md` in case you are planning to do.

---

## Branch predictor

| Parameter              | Value     | Rationale                                                                                  |
| ---------------------- | --------- | ------------------------------------------------------------------------------------------ |
| Predictor type         | 2-bit BHT | Standard                                                                                   |
| BHT entries            | 256       | Indexed by PC[9:2], sufficient enough                                                      |
| BTB                    | None      | Omitted for simplicity, taken branches pay 1 extra cycle for target computation via decode |
| Resolution stage       | EX        | Branch outcome known after ALU comparison                                                  |
| Misprediction handling | None      | Straight-line code only                                                                    |

The baseline PRAVAH executes only straight-line code. Branches and JAL are decoded and ROB-allocated, but the front-end keeps fetching PC+8 regardless. **All test programs use only ALU and ADDI instructions.**

---

## ISA subset

PRAVAH supports these 13 RV32I instructions:

**Arithmetic / Logical (executes):** (Compulsory ones)

- `ADD`, `SUB`, `ADDI`
- `AND`, `OR`, `XOR`
- `SLL`, `SRL`
- `SLT`

**Memory :**

- `LW`, `SW` these are for placeholders, please include yours

**Control flow :**

- `BEQ`, `BNE`, `JAL` these are for placeholders, please include yours

**It is upto you if you want to decode the optional ones and not put it in the integration part**

---

## Memory model(optional)

| Parameter          | Value                                                         |
| ------------------ | ------------------------------------------------------------- |
| Instruction memory | 1 KB (256 32-bit words), `$readmemh`-initialized in testbench |
| Data memory        | 1 KB, single-port (when LSU is added)                         |
| Cache hierarchy    | None — memories are flat                                      |
| Memory latency     | 1 cycle combinational read                                    |

---

## What we are NOT building

Explicitly out of scope, even as stretch goals:

- **No cache hierarchy** — memories are directly addressable
- **No load/store queue** — loads block when LSU is added
- **No store-to-load forwarding**
- **No gshare or tournament predictor** — only the 2-bit BHT if we add one
- **No floating-point** — RV32I integer only, no F or D extension
- **No interrupts or exceptions** — programs are assumed well-formed
- **No 4-wide issue** — 2-wide is fixed
- **No precise speculation recovery** — branch misprediction is not handled
- **No power management** — clock-gating, DVFS, etc. are out of scope

---

## Known limitations (documented, not bugs)

Include the limitation you want to put before design

---

## History of bug fixes (post-design-lock)

Keep updating this section till week-4 for your future reference

---

## Locked. Sign-off:

- **Mentor:** Krishna Kukreja, Naman Nayak
- **Date locked:** Week 4 (Milestone 2)
- **Project:** PRAVAH — IIT Bombay Seasons of Code 2026

---
