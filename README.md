# Stage 6 paired data-capture integration package

## What this package changes

This package integrates `dcls_paired_data_capture_stage` into the Stage 4F
dual-Ibex SoC data path. It does **not** put the paired FIFO or the paired
request-admission module in series with the capture stage. Those remain
separate alternatives and are not deleted or modified.

### Data-path behaviour

- **Basic profile:** the capture stage reports bypass while idle. Both wrapper
  instances retain their existing direct RAM request/grant path.
- **Safety profile, local data/RAM transactions:** each core's request is
  captured as a 69-bit payload `{we, be, CPU address, masked write data}`.
  The capture stage compares the registered signatures and then presents the
  captured payloads to the two local RAM ports. Both grants and both RAM
  requests are paired.
- **Read transactions:** write data is masked to zero in the comparison and
  stored payload because it is not a meaningful read-request field.
- **MMIO transactions:** they do not enter the local-RAM capture stage. The
  existing shared-MMIO interlock and replicated peripheral path remain in
  control. The existing DCLS comparator still compares MMIO request fields,
  including the Core B observation-path fault-injection values, and compares
  all data responses.
- **Address guard:** a paired invalid non-MMIO request is granted only after
  capture/compare; it is not forwarded to RAM and produces the wrapper's
  registered bus-error response. The wrapper reports the data-address fault
  on the accepted request edge.
- **Safety faults:** external faults, response mismatches, MMIO interlock,
  supervisor fault, and replica-integrity fault suppress commit and flush the
  stage. A paired-stage request/payload mismatch suppresses commit and enters
  the stage's fail-closed state.

### Additional protections

The capture stage now has `commit_ready_i`. It does not retire a captured
transaction until the downstream path is actually ready to grant both cores
and commit the paired RAM transaction. It detects changes in either original
processor payload or the live comparison signatures between capture and grant;
the payload mismatch suppresses the commit. This includes changes to the Core B
observation/injection comparison path after capture.

The wrapper's new paired-path ports are guarded by the parameter
`EnablePairedDataPath`, which defaults to `0`. Stage 4F sets it to `1` for both
cores. Other wrapper instantiations that omit the new signals retain the
direct path because the parameter defaults to `0`.

## Files in this package

- `rtl/bringup/safety_riscv_soc_stage1_mmio.v`
- `rtl/bringup/safety_riscv_soc_stage4f.v`
- `rtl/bringup/safety_riscv_soc_stage4f.core`
- `rtl/safety/dcls_paired_data_capture_stage.v`
- `tb/dcls_paired_data_capture_stage_tb.sv`
- `tb/safety_riscv_soc_stage4f_tb.sv`
- `stage6_pairing_integration/update_pairing_manifests.py`

The DCLS comparator RTL and comparator unit testbench are unchanged.

## Apply to the project

Extract the archive into the project root:

`/mnt/e/Dissertation/Safety_RISCV_SoC_Stage5`

The archive places RTL and testbench files at their project-relative paths and
keeps this guide/helper under `stage6_pairing_integration/`. Then, from the
project root, run:

```bash
python3 stage6_pairing_integration/update_pairing_manifests.py

git diff --check
git status --short
```

The manifest helper only inserts the new capture RTL source into existing
Stage4F-derived manifests when it finds the exact existing comparator source
entry. It skips absent manifests and manifests that do not compile that source
directly; inspect any skipped target's FuseSoC dependency chain before using it
for simulation or synthesis.

## Verification sequence

First run the standalone capture-stage test with the installed environment:

```bash
source /home/shaheen/.venvs/safety-riscv/bin/activate

verilator --binary --timing --sv -Wall -Wno-fatal \
  --top-module dcls_paired_data_capture_stage_tb \
  rtl/safety/dcls_paired_data_capture_stage.v \
  tb/dcls_paired_data_capture_stage_tb.sv \
  --Mdir /tmp/dcls_paired_data_capture_stage_obj

/tmp/dcls_paired_data_capture_stage_obj/Vdcls_paired_data_capture_stage_tb
```

Then rebuild Stage 4F simulation:

```bash
/home/shaheen/.venvs/safety-riscv/bin/fusesoc --cores-root=. run \
  --target=sim --tool=verilator \
  local:safety_riscv:safety_riscv_soc_stage4f:0.1
```

Run the real-Ibex capture/backpressure integration test:

```bash
cd /home/shaheen/fusesoc-build/local_safety_riscv_safety_riscv_soc_stage4f_0.1/sim-verilator

./Vsafety_riscv_soc_stage4f_tb +ibex_data_stability_test
```

The updated Stage 4F testbench also adapts the existing address-guard,
DCLS-store-inhibit, and supervisor-to-RAM-containment scenarios to the
capture-stage handshake timing.

## Verification status

These files were prepared from the uploaded source bundle and the current
Stage 4F testbench. They have received structural/manual consistency checks
in this environment, but **have not been compiled or simulated here** because
the local container does not have Verilator or FuseSoC installed. Do not treat
the integration as verified until the standalone and Stage 4F commands above
pass in the WSL project environment.

Do not run Git reset/clean/revert or discard any working-tree files while
applying this package. The existing paired FIFO/admission RTL and all other
uncommitted work are intentionally left untouched.
