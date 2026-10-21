# Stage 4G — Pre-FPGA Memory and Side-Effect Hardening

## Purpose
Harden the shared Ibex wrapper against RAM address aliasing and suppress RAM
requests when Stage 4F detects a DCLS mismatch or enters safe state.

## Implementation
- Added configurable `RamDepth` and passed it to `ram_2p`.
- Compatibility default: 262144 32-bit words (1 MiB).
- Stage 4F setting: 4096 words (16 KiB) per core.
- Stage 4F RAM range: `0x00100000` inclusive to `0x00104000` exclusive.
- Last valid word address: `0x00103FFC`.
- Full CPU address checks run before low RAM index bits are used.
- Invalid guarded non-MMIO data requests and instruction fetches are blocked
  from RAM and receive registered bus-error responses.
- Stage 4F routes instruction address faults to sticky fault code `0x01` and
  data address faults to sticky fault code `0x02`.
- Stage 4F inhibits RAM requests using `safe_state_req | dcls_mismatch_o`.
- Stage 4E keeps the guard disabled and ties the new inhibit input low.

## Reproduction commands

Build and run the default Stage 4F regression from the repository root:

```bash
cd /mnt/e/Dissertation/Safety_RISCV_SoC
source /home/shaheen/.venvs/safety-riscv/bin/activate
/home/shaheen/.venvs/safety-riscv/bin/fusesoc run --target=sim local:safety_riscv:safety_riscv_soc_stage4f:0.1
```

Run all focused Stage 4F tests from the generated simulation directory:

```bash
cd /home/shaheen/fusesoc-build/local_safety_riscv_safety_riscv_soc_stage4f_0.1/sim-verilator
set -e
./Vsafety_riscv_soc_stage4f_tb +address_guard_test
./Vsafety_riscv_soc_stage4f_tb +instruction_guard_test
./Vsafety_riscv_soc_stage4f_tb +dcls_store_inhibit_test
./Vsafety_riscv_soc_stage4f_tb +supervisor_timeout_test
```

Run the Stage 4E compatibility regression:

```bash
cd /mnt/e/Dissertation/Safety_RISCV_SoC
source /home/shaheen/.venvs/safety-riscv/bin/activate
/home/shaheen/.venvs/safety-riscv/bin/fusesoc run --target=sim local:safety_riscv:safety_riscv_soc_stage4e:0.1
```

## Verified simulations
- Stage 4F normal integration: six heartbeat updates, both core success
  markers, no unexpected DCLS/interlock/supervisor faults.
- Stage 4E integration: nine MMIO transactions, both success markers,
  Diagnostic profile and injection authorization enabled, no DCLS/interlock
  faults.
- `+address_guard_test`: valid upper boundary, below-base and above-limit
  checks, blocked invalid write, registered data error and fault `0x02`.
- `+instruction_guard_test`: invalid fetch blocked from RAM, registered
  instruction error and fault `0x01`.
- `+dcls_store_inhibit_test`: both RAM paths inhibited before the clock edge
  on divergent store data; sticky data fault and safe state confirmed.
- `+supervisor_timeout_test`: supervisor fault `0x03`, timeout detected,
  sticky fault and safe state confirmed.

## Limitations
The focused Stage 4G tests use testbench-forced internal bus signals. They
validate address decode, response timing, fault routing and request inhibition;
they do not establish a complete firmware exception flow for deliberately
invalid accesses. The DCLS mechanism is transaction-level, not internal CPU
state lockstep. The supervisor heartbeat is application-level progress, not
per-instruction retirement monitoring.

Vivado synthesis, BRAM inference, FPGA resource/timing results, bitstream
generation and a physical Arty A7-100T demonstration have not been verified.
These simulations establish neither ISO 26262 certification nor ASIL compliance.

## Next steps
1. Review, commit and push this source/test/documentation milestone.
2. Synthesize in Vivado; record RAM inference, resources and timing.
3. Implement the representative battery monitoring workload.
4. Expand fault injection, assertion/coverage evidence and quantitative tests.
5. Validate the design on the target FPGA before claiming hardware prototyping.
