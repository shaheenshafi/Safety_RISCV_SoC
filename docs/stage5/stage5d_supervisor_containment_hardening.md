# Stage5D — Supervisor Fault Containment Hardening

**Project:** Configurable Safety-Oriented RISC-V SoC for HV Battery Systems
**Repository branch:** `stage5/battery-monitoring`
**Baseline commit:** `c7f2eeb` — `feat(stage5): integrate dual-core battery monitoring application`
**Status:** Implemented; directed simulation regression passed on the current working tree
**Verification environment:** FuseSoC + Verilator 5.032; Edalize 0.6.8
**Date recorded:** 2026-11-02

## 1. Purpose

This change closes a fault-containment gap between the registered execution-supervisor timeout indication and the later sticky fault-manager safe-state indication. The intended behaviour is to inhibit new processor memory side effects and MMIO transactions as soon as the supervisor fault is visible, rather than waiting for the fault manager to latch the fault.

The fault-manager sticky-fault mechanism and safe-state sequencing were not replaced by this change.

## 2. Issue and reproduction

The execution supervisor produces registered timeout flags. The SoC derives `supervisor_fault_o` from those flags. The fault manager samples this signal and asserts its sticky fault/safe-state request on a subsequent clock edge.

Before the correction, the RAM and MMIO side-effect inhibits depended on `safe_state_req` and/or `dcls_mismatch_o`, but not directly on `supervisor_fault_o`. This left an interval in which the supervisor fault was already visible while the sticky safe-state request had not yet asserted.

A directed MMIO containment test reproduced the exposure: with `supervisor_fault_o` asserted and `fault_latched_o` still low, a matched write to the injection-authorization register was presented and `injection_authorize_o` became asserted. The test therefore demonstrated an actual MMIO side effect in the supervisor-to-fault-manager capture interval.

## 3. RTL correction

File changed: `rtl/bringup/safety_riscv_soc_stage4f.v`

The MMIO request is now gated by all three conditions:

```verilog
assign mmio_req =
    mmio_requests_match &&
    !safe_state_req &&
    !supervisor_fault_o &&
    !dcls_mismatch_o;
```

The MMIO configuration peripheral receives the combined safe-state condition:

```verilog
.safe_state_i (safe_state_req | supervisor_fault_o)
```

Both processor instances receive the immediate supervisor-fault indication in their memory side-effect inhibit:

```verilog
.memory_side_effect_inhibit_i
    (safe_state_req | supervisor_fault_o | dcls_mismatch_o)
```

The fault manager itself was left unchanged. Its sticky fault capture, fault-code handling and safe-state behaviour remain the downstream fault-management mechanism.

## 4. Directed testbench additions

File changed: `tb/safety_riscv_soc_stage4f_tb.sv`

Two directed test modes are available:

- `+supervisor_mmio_containment_test`
- `+supervisor_ram_containment_test`

The existing `+supervisor_timeout_test` continues to exercise heartbeat-loss timeout detection and sticky safe-state response.

### 4.1 Supervisor-to-MMIO containment

The test waits for the supervisor fault to become visible while the sticky fault-manager safe-state request is still low. It then presents a matched write to the injection-authorization register and checks that:

- the two requests match and the target address is valid;
- `dut.mmio_req` and `dut.mmio_gnt` remain low;
- the MMIO peripheral's `safe_state_i` is asserted;
- injection authorisation remains blocked after the sampling edge;
- the fault manager subsequently records fault code `0x03` and asserts sticky safe state.

### 4.2 Supervisor-to-RAM containment

The test similarly waits for the supervisor-fault/sticky-safe-state interval and presents matched writes from both cores to CPU address `0x00102000`, with data `0xA55A3CC3` and full byte enables. It checks the expected RAM word index (`2048`), both RAM request/write-enable paths and grants, and the contents of both generic RAM memory arrays before and after the sampling edge.

The test passes only when both writes are blocked and neither memory word changes. It also confirms supervisor fault code `0x03` and the subsequent sticky safe state.

## 5. Verification record

The following six commands were executed sequentially on the current Stage5 working tree. The user-provided terminal output reported `COMPLETE REGRESSION SUITE: PASS`.

| Test | Command target / run option | Observed result |
|---|---|---|
| Stage4F supervisor timeout | `stage4f`, `sim`, `+supervisor_timeout_test` | PASS; heartbeat-loss detection, fault code `0x03`, sticky fault and safe state confirmed |
| Stage4F supervisor MMIO containment | `stage4f`, `sim`, `+supervisor_mmio_containment_test` | PASS; MMIO request/grant and injection authorisation blocked; fault code `0x03` |
| Stage4F supervisor RAM containment | `stage4f`, `sim`, `+supervisor_ram_containment_test` | PASS; both RAM writes blocked; memory contents unchanged; fault code `0x03` |
| Stage5 basic simulation | `stage5`, `sim` | PASS; Core A/B result `0x0000000C`; Basic profile; 56 cycles; no fault or illegal events |
| Stage5 HAL simulation | `stage5`, `hal_sim` | PASS; Safety profile; six accepted heartbeat updates; final sequence `0x00000006`; DCLS enabled; no safety fault; 1200 cycles |
| Stage5 battery application | `stage5`, `battery_sim` | PASS; 14/14 records per core; 28 result words per core; diagnostic mask `0x0000003F`; checksums match; 33 heartbeat updates; final sequence `0x00000021`; DCLS enabled; no safety fault; 6000 cycles |

### Reproduction commands

Run from the repository root after activating the project's Python environment and ensuring the RISC-V toolchain is on `PATH`:

```bash
CORE4="local:safety_riscv:safety_riscv_soc_stage4f:0.1"
CORE5="local:safety_riscv:safety_riscv_soc_stage5:0.1"
CORES_ROOT="$PWD/rtl/bringup"

fusesoc --cores-root="$CORES_ROOT" run --target=sim "$CORE4" \
  --run_options="+supervisor_timeout_test"

fusesoc --cores-root="$CORES_ROOT" run --target=sim "$CORE4" \
  --run_options="+supervisor_mmio_containment_test"

fusesoc --cores-root="$CORES_ROOT" run --target=sim "$CORE4" \
  --run_options="+supervisor_ram_containment_test"

fusesoc --cores-root="$CORES_ROOT" run --target=sim "$CORE5"
fusesoc --cores-root="$CORES_ROOT" run --target=hal_sim "$CORE5"
fusesoc --cores-root="$CORES_ROOT" run --target=battery_sim "$CORE5"
```

## 6. Interpretation and limits

The evidence supports the following bounded conclusion:

> In the directed Verilator scenarios exercised, a visible execution-supervisor fault immediately inhibits newly presented matched MMIO transactions and processor RAM writes during the interval before the fault manager asserts its sticky safe-state request. The downstream sticky fault and safe-state response is subsequently confirmed.

This is directed simulation evidence. It is not formal proof of all possible interleavings, a complete MMIO fault matrix, FPGA validation, or evidence of ISO 26262 certification or an ASIL capability.

The supervisor's watchdog and progress-monitor inputs currently observe the same application-generated heartbeat event. Accordingly, describe this as **application-level heartbeat supervision**; do not claim that the supervisor independently observes instruction retirement or internal pipeline progress.

The DCLS mechanism remains an external transaction-level comparator. It does not compare every internal Ibex architectural state element or all processor handshake/error signals.

## 7. Remaining verification work

1. Add separate MMIO interlock tests for one-core-only requests, address mismatch, write-data mismatch, byte-enable mismatch, read/write-direction mismatch and invalid register accesses.
2. Add fault-injection scenarios while the battery monitoring application is executing, and record detection/response behaviour.
3. Strengthen assertion-based verification (SVA) and functional coverage for fault classes, profiles, sticky fault behaviour, safe-state containment and fault-code stability.
4. Complete the Arty A7-100T FPGA implementation and board validation. The current evidence is simulation-only.
5. Reconcile the test and build documentation with the final RTL revision before creating the Stage5D commit.

## 8. Build-system observations

FuseSoC reported duplicate local-core replacement warnings, deprecated core-file paths outside their core directories, and a deprecated Edalize tool backend. These warnings did not prevent the six simulations from completing. Track them as build-system maintenance work; do not confuse them with test failures.
