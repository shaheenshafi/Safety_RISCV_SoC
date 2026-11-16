#ifndef BATTERY_TYPES_H
#define BATTERY_TYPES_H

#include <stdint.h>

/* Battery measurement representation */
typedef struct {
    uint32_t voltage_mV;
    int32_t current_mA;
    int32_t temperature_centi_C;
    uint32_t sequence;
} battery_sample_t;

/* Configurable diagnostic thresholds */
typedef struct {
    uint32_t undervoltage_mV;
    uint32_t overvoltage_mV;
    int32_t max_discharge_current_mA;
    int32_t max_charge_current_mA;
    int32_t min_temperature_centi_C;
    int32_t max_temperature_centi_C;
} battery_thresholds_t;

/* Per-sample diagnostic result */
typedef struct {
    uint32_t sequence;
    uint32_t diagnostic_flags;
} battery_result_t;

/* Diagnostic flags */
#define BAT_DIAG_UNDERVOLTAGE       (1u << 0)
#define BAT_DIAG_OVERVOLTAGE        (1u << 1)
#define BAT_DIAG_DISCHARGE_OC       (1u << 2)
#define BAT_DIAG_CHARGE_OC          (1u << 3)
#define BAT_DIAG_UNDERTEMPERATURE   (1u << 4)
#define BAT_DIAG_OVERTEMPERATURE    (1u << 5)

#define BAT_DIAG_ALL                0x3Fu

#define BATTERY_SAMPLE_COUNT        14u

#endif
