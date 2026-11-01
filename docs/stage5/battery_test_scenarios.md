# Stage 5A — Battery Monitoring Test Scenarios

**Version:** 0.1
**Status:** Initial deterministic verification specification

## 1. Purpose

Define deterministic measurement scenarios and expected diagnostic
masks for the battery-monitoring application.

The numerical dataset below uses the approved illustrative
400-V-class reference configuration.

## 2. Symbolic Threshold Notation

| Symbol | Meaning |
|---|---|
| Vmin | Undervoltage threshold |
| Vmax | Overvoltage threshold |
| Idmax | Maximum discharge current magnitude |
| Icmax | Maximum charge current magnitude |
| Tmin | Minimum temperature |
| Tmax | Maximum temperature |

Current convention:
- Positive current means discharge.
- Negative current means charge.

All comparisons use strict inequalities.

## 3. Nominal Operating Scenario

Use the following nominal operating measurements:

- Voltage: 400000 mV (400 V).
- Current: 0 mA.
- Temperature: 2500 centi-degrees C (25 degrees C).
- Sequence: unique monotonically increasing number.

Expected diagnostic mask: 0x00.

## 4. Individual Abnormal-Condition Scenarios

All non-target measurements remain within their normal operating
ranges.

| Sequence | Scenario | Measurement condition | Expected mask |
|---:|---|---|---:|
| 1 | Nominal operation | All measurements within limits | 0x00 |
| 2 | Undervoltage | V = Vmin - 1 mV | 0x01 |
| 3 | Overvoltage | V = Vmax + 1 mV | 0x02 |
| 4 | Discharge overcurrent | I = Idmax + 1 mA | 0x04 |
| 5 | Charge overcurrent | I = -(Icmax + 1) mA | 0x08 |
| 6 | Undertemperature | T = Tmin - 1 centi-degree C | 0x10 |
| 7 | Overtemperature | T = Tmax + 1 centi-degree C | 0x20 |

The selected thresholds must allow all adjacent test values to be
represented by their corresponding C data types.

## 5. Combined Abnormal-Condition Scenario

| Sequence | Scenario | Measurement conditions | Expected mask |
|---:|---|---|---:|
| 8 | Multiple abnormalities | V = Vmin - 1; I = Idmax + 1; T = Tmax + 1 | 0x25 |

Expected mask calculation:

- Undervoltage: 0x01.
- Discharge overcurrent: 0x04.
- Overtemperature: 0x20.

Combined mask: 0x01 OR 0x04 OR 0x20 = 0x25.

All other diagnostic conditions must remain false.

## 6. Threshold-Boundary Scenarios

Each boundary test targets one measurement. Other measurements remain
within normal operating limits.

| Sequence | Scenario | Measurement condition | Expected mask |
|---:|---|---|---:|
| 9 | Undervoltage boundary | V = Vmin | 0x00 |
| 10 | Overvoltage boundary | V = Vmax | 0x00 |
| 11 | Discharge current boundary | I = Idmax | 0x00 |
| 12 | Charge current boundary | I = -Icmax | 0x00 |
| 13 | Minimum temperature boundary | T = Tmin | 0x00 |
| 14 | Maximum temperature boundary | T = Tmax | 0x00 |

These scenarios verify the strict inequality comparison policy.

## 7. Dataset-Level Acceptance Criteria

For the fourteen-sample dataset:

- Exactly fourteen results must be generated.
- Result sequence numbers must match input sequence numbers.
- Every diagnostic mask must match its expected value.
- Bits 6 and 7 must remain zero.
- The nominal sample must produce 0x00.
- Each individual abnormal sample must set only its intended bit.
- The combined abnormal sample must produce 0x25.
- All six equality-boundary samples must produce 0x00.
- Both cores must produce identical result sequences and masks.

## 8. Additional Execution Checks

At application completion:

- Processed sample count must equal the dataset length.
- Both cores must report completion.
- No unexpected hardware fault or safe-state event should occur
  during normal workload execution.
- Supervisor heartbeat servicing must be verified during
  application integration.

## 9. Test Scope and Limitations

These scenarios validate software-level threshold evaluation and
deterministic execution.

They do not validate physical sensor accuracy, battery chemistry,
cell-level protection, hardware cutoff response or certified
functional-safety performance.

## 10. Concrete Numerical Dataset

Approved illustrative thresholds:

- Vmin = 300000 mV.
- Vmax = 450000 mV.
- Idmax = 200000 mA.
- Icmax = 150000 mA.
- Tmin = -2000 centi-degrees C.
- Tmax = 6000 centi-degrees C.

Nominal measurement values:

- Voltage = 400000 mV.
- Current = 0 mA.
- Temperature = 2500 centi-degrees C.

The following dataset instantiates all fourteen scenarios.

| Seq. | Scenario | Voltage (mV) | Current (mA) | Temperature (0.01 C) | Expected mask |
|---:|---|---:|---:|---:|---:|
| 1 | Normal | 400000 | 0 | 2500 | 0x00 |
| 2 | Undervoltage | 299999 | 0 | 2500 | 0x01 |
| 3 | Overvoltage | 450001 | 0 | 2500 | 0x02 |
| 4 | Discharge overcurrent | 400000 | 200001 | 2500 | 0x04 |
| 5 | Charge overcurrent | 400000 | -150001 | 2500 | 0x08 |
| 6 | Undertemperature | 400000 | 0 | -2001 | 0x10 |
| 7 | Overtemperature | 400000 | 0 | 6001 | 0x20 |
| 8 | Combined abnormalities | 299999 | 200001 | 6001 | 0x25 |
| 9 | Undervoltage boundary | 300000 | 0 | 2500 | 0x00 |
| 10 | Overvoltage boundary | 450000 | 0 | 2500 | 0x00 |
| 11 | Discharge current boundary | 400000 | 200000 | 2500 | 0x00 |
| 12 | Charge current boundary | 400000 | -150000 | 2500 | 0x00 |
| 13 | Minimum temperature boundary | 400000 | 0 | -2000 | 0x00 |
| 14 | Maximum temperature boundary | 400000 | 0 | 6000 | 0x00 |

For scenario 8, the expected combined mask is:

0x01 OR 0x04 OR 0x20 = 0x25.

Every non-target measurement in the individual abnormal-condition
tests remains at its nominal value.

All threshold comparisons remain strict. Equality does not trigger
a diagnostic flag.
