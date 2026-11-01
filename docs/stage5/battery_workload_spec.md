# Stage 5A — Battery Monitoring Workload Specification

**Version:** 0.1
**Status:** Initial engineering specification

## 1. Objective

Define a deterministic battery-monitoring application workload for the
existing dual-core RISC-V safety-oriented SoC.

The workload demonstrates measurement-data processing, integer
arithmetic, threshold-based diagnostics and result reporting.

This is a representative embedded application, not a complete BMS.

## 2. Scope

### Included
- Deterministic battery measurement samples.
- Voltage, current and temperature processing.
- Integer/fixed-point arithmetic.
- Six independent diagnostic conditions.
- Per-sample diagnostic result generation.
- Independent execution on both Ibex cores.
- Comparison of application outputs.
- Functional and boundary-condition verification.

### Excluded
- Physical sensors and ADC interfaces.
- Cell balancing and thermal management control.
- State-of-charge and state-of-health estimation.
- Electrochemical battery modelling.
- Contactor, inverter or actuator control.
- Complete BMS implementation.
- ISO 26262 certification or ASIL achievement claims.

## 3. Execution Architecture

Both Ibex cores execute the same firmware image independently.

Each core:
1. Initializes application state.
2. Reads the deterministic measurement dataset.
3. Evaluates samples against configured thresholds.
4. Generates a diagnostic bitmask.
5. Stores results in its independent RAM.
6. Reports completion status.

Both cores use identical input samples and threshold configuration.

## 4. Measurement Model

Each sample contains:
- Battery voltage in millivolts (mV).
- Battery current in milliamperes (mA).
- Battery temperature in centi-degrees Celsius (0.01 °C).
- A monotonically increasing sequence number.

Current convention:
- Positive: battery discharge.
- Negative: battery charge.
- Zero: no net current flow.

Floating-point arithmetic is not required.

## 5. Diagnostic Processing

Six independent conditions are evaluated:
1. Undervoltage.
2. Overvoltage.
3. Discharge overcurrent.
4. Charge overcurrent.
5. Undertemperature.
6. Overtemperature.

The corresponding flags are combined into a six-bit diagnostic mask.
Multiple flags may be set for one sample.

Per-sample flags are recalculated for every sample; they are not
automatically sticky hardware fault-manager events.

## 6. Threshold Configuration

Thresholds are configurable through a dedicated data structure.

The selected reference is a fictional 400-V-class lithium-ion
battery pack with the following illustrative configuration:

| Parameter | Value |
|---|---:|
| Nominal voltage | 400 V |
| Undervoltage threshold | 300 V |
| Overvoltage threshold | 450 V |
| Maximum discharge current | 200 A |
| Maximum charge current | 150 A |
| Minimum temperature | -20 degrees C |
| Maximum temperature | 60 degrees C |
| Nominal operating temperature | 25 degrees C |

All values are illustrative simulation assumptions. They are not
Stellantis specifications, validated battery operating limits or
certified protection thresholds.

Configuration requirements:
- Undervoltage threshold < overvoltage threshold.
- Discharge and charge current limits > 0.
- Minimum temperature < maximum temperature.
- Threshold values and adjacent boundary-test values must be
  representable by their specified C data types.

## 7. Comparison Policy

All six diagnostic comparisons use strict inequalities.

Equality to a configured threshold does not trigger its diagnostic.

All conditions are evaluated independently. The output mask is the
bitwise OR of every condition satisfied by the sample.

## 8. Deterministic Dataset

The initial dataset contains fourteen scenarios:
- One nominal operating sample.
- Six individual abnormal-condition samples.
- One combined abnormal-condition sample.
- Six threshold-boundary samples.

Expected results are defined in `battery_test_scenarios.md`.

## 9. Application Results

Each result contains:
- Original sample sequence number.
- Six-bit diagnostic mask.

Both cores must produce matching result sequences and diagnostic masks.

Application diagnostics remain distinct from hardware fault-manager
status and safe-state indications.

## 10. Platform Integration

Reuse the existing SoC memory map, startup and safety platform.

Preserve the established boot arrangement:
- Ibex boot address: 0x00100000.
- Firmware entry point: 0x00100080.
- VMEM word offset: 0x20.

Respect the existing application RAM, stack and result-area reservations.

The existing heartbeat register is at 0x00200010. Its service sequence
and timing requirements must be checked against the supervisor RTL
before firmware integration.

No new hardware peripheral is required for this initial workload.

## 11. Safety Architecture Separation

Application diagnostic flags are software-level observations.

They must not be represented as hardware fault-manager events unless
a separately specified and verified software-to-hardware fault
interface is implemented.

Existing hardware DCLS and execution-supervisor mechanisms remain
separate.

This workload does not claim certified battery protection capability.

## 12. Acceptance Criteria

1. Measurement representation, units and current sign convention fixed.
2. Six diagnostic conditions formally defined.
3. Threshold comparison semantics fixed.
4. Fourteen expected test scenarios documented.
5. Numerical assumptions clearly distinguished from product limits.
6. Both-core execution and result requirements defined.
7. Application diagnostics separated from hardware safety events.
