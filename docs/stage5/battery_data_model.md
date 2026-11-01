# Stage 5A — Battery Measurement and Diagnostic Data Model

**Version:** 0.1
**Status:** Initial engineering specification

## 1. Measurement Data Structure

The C measurement structure contains four 32-bit fields:

- voltage_mV: uint32_t, battery voltage in millivolts.
- current_mA: int32_t, battery current in milliamperes.
- temperature_centi_C: int32_t, temperature in 0.01 degrees Celsius.
- sequence: uint32_t, monotonically increasing sample identifier.

Expected structure size on the RV32 target: 16 bytes.

## 2. Current Sign Convention

- Positive current: battery discharge.
- Negative current: battery charge.
- Zero current: no net current flow.

## 3. Threshold Configuration

The threshold configuration contains:

- undervoltage_mV: uint32_t
- overvoltage_mV: uint32_t
- max_discharge_current_mA: int32_t
- max_charge_current_mA: int32_t
- min_temperature_centi_C: int32_t
- max_temperature_centi_C: int32_t

Current limits represent positive magnitudes and must be greater than zero.

## 4. Diagnostic Bit Definitions

| Bit | Mask | Diagnostic |
|---|---|---|
| 0 | 0x01 | Undervoltage |
| 1 | 0x02 | Overvoltage |
| 2 | 0x04 | Discharge overcurrent |
| 3 | 0x08 | Charge overcurrent |
| 4 | 0x10 | Undertemperature |
| 5 | 0x20 | Overtemperature |

Bits 6 and 7 are reserved and must remain zero.

## 5. C Data Structure Definitions

The application shall use the following measurement structure:

    typedef struct {
        uint32_t voltage_mV;
        int32_t  current_mA;
        int32_t  temperature_centi_C;
        uint32_t sequence;
    } battery_sample_t;

Expected size: 16 bytes.

Threshold configuration:

    typedef struct {
        uint32_t undervoltage_mV;
        uint32_t overvoltage_mV;
        int32_t max_discharge_current_mA;
        int32_t max_charge_current_mA;
        int32_t min_temperature_centi_C;
        int32_t max_temperature_centi_C;
    } battery_thresholds_t;

Result structure:

    typedef struct {
        uint32_t sequence;
        uint32_t diagnostic_flags;
    } battery_result_t;

Expected result size: 8 bytes.

## 6. Diagnostic Flag Definitions

The C implementation shall define:

    #define BAT_DIAG_UNDERVOLTAGE       (1u << 0)
    #define BAT_DIAG_OVERVOLTAGE        (1u << 1)
    #define BAT_DIAG_DISCHARGE_OC       (1u << 2)
    #define BAT_DIAG_CHARGE_OC          (1u << 3)
    #define BAT_DIAG_UNDERTEMPERATURE   (1u << 4)
    #define BAT_DIAG_OVERTEMPERATURE    (1u << 5)

    #define BAT_DIAG_ALL                (0x3Fu)

## 7. Diagnostic Comparison Semantics

Let V represent measured voltage, I represent measured current,
and T represent measured temperature.

Let Vmin, Vmax, Idmax, Icmax, Tmin and Tmax represent their
corresponding configured thresholds.

The diagnostic conditions are:

| Diagnostic | Condition | Flag |
|---|---|---|
| Undervoltage | V < Vmin | 0x01 |
| Overvoltage | V > Vmax | 0x02 |
| Discharge overcurrent | I > Idmax | 0x04 |
| Charge overcurrent | I < -Icmax | 0x08 |
| Undertemperature | T < Tmin | 0x10 |
| Overtemperature | T > Tmax | 0x20 |

All comparisons use strict inequalities.

Equality to a configured threshold does not set its corresponding flag.

All six conditions are evaluated independently. The final diagnostic
mask is the bitwise OR of all applicable flags.

## 8. Arithmetic and Representation Constraints

- Use integer arithmetic only.
- Do not convert measurements to floating point.
- Use signed types for current and temperature.
- Use unsigned types for voltage.
- Do not use abs() on signed current to evaluate charge overcurrent.
- The charge-current threshold must be positive and safely negatable.
- Avoid signed overflow when generating boundary-test samples.
- Keep voltage calculations within uint32_t bounds.

Threshold values and their adjacent test values must be representable
by their corresponding C types.

In particular, the selected current thresholds must allow the
positive and negative overcurrent test samples to be represented.

## 9. Threshold Configuration Validation

A configuration is valid only when:

- undervoltage_mV < overvoltage_mV;
- undervoltage_mV > 0;
- overvoltage_mV allows a representable value above the threshold;
- max_discharge_current_mA > 0;
- max_charge_current_mA > 0;
- min_temperature_centi_C < max_temperature_centi_C;
- both temperature boundaries allow adjacent representable values.

The implementation shall reject an invalid threshold configuration
before processing the dataset.

## 10. Diagnostic State Semantics

Per-sample diagnostic flags are not sticky.

For every input sample, the application starts with a zero diagnostic
mask and independently evaluates all six conditions.

An optional aggregate diagnostic mask may accumulate the bitwise OR
of all per-sample masks across the dataset.

This aggregate represents application reporting information. It
must not be confused with a hardware sticky fault register.

## 11. Approved Illustrative Reference Configuration

Reference pack: fictional 400-V-class lithium-ion battery pack.

| Parameter | Engineering value | Stored value |
|---|---:|---:|
| Nominal voltage | 400 V | 400000 mV |
| Undervoltage threshold | 300 V | 300000 mV |
| Overvoltage threshold | 450 V | 450000 mV |
| Maximum discharge current | 200 A | 200000 mA |
| Maximum charge current | 150 A | 150000 mA |
| Minimum temperature | -20 degrees C | -2000 centi-degrees C |
| Maximum temperature | 60 degrees C | 6000 centi-degrees C |
| Nominal temperature | 25 degrees C | 2500 centi-degrees C |

All values are illustrative simulation assumptions, not actual
battery product specifications or certified safety limits.
