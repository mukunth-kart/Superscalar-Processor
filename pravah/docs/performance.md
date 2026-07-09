## 1. IPC Measurement Table

| Benchmark       | End-to-End IPC | Steady-State IPC |
| :-------------- | :------------- | :--------------- |
| **Independent** | 1.60           | 2.00             |
| **Chain**       | 1.167          | 1.312            |
| **Mixed**       | 1.50           | 1.875            |

## 2. Gap Analysis

### Pipeline Fill/Drain Penalty

Across all 3 benchmarks, there is a visible gap between the end-to-end IPC and the steady state IPC. This represents the pipeline fill and drain overhead. The initial cycles spent fetching and decoding the 1st instruction and the final cycles spent draining the last commit mean the fill & drain of a pipeline. Due to the short 16-instruction benchmarks, the gap is ~0.3-0.4.

### Independent benchmark

This achieved a steady state IPC of exactly 2.0, indicating that both issue slots are fully utilized with no wasted cycles. The drop to 1.6 in the end-to-end IPC indicates the pipeline fill/drain.

### Chain benchmark

This achieved a steady state IPC of 1.312 and an end to end IPC of 1.167, both well below the 2.0 ceiling. The fundamental reason is data dependency! Theoretically it should be 1.0, but the reason for it be above that might be that first few instructions being independent => before the chain locks in, the steady state window might include some of those very fast clock cycles.

### Mixed benchmark

This achieved a steady state IPC of 1.875, indicating good Instruction-Level Parallelism(ILP) exploitation. [ILP is a property of the program, not the hardware. It measures how many instructions **could** execute simultaneously if you had unlimited]. Everytime there's a dependency there happens to be a simultaneously dispatchable independent instruction, and everytime there's a long dependency chain, there's an independent ADDI alongside it in the bundle. This structure maximizes ILP. It also achieved an end to end IPC of 1.50.
