#include <limits.h>
#include "battery_monitor.h"

int battery_thresholds_validate(
    const battery_thresholds_t *thresholds)
{
    if (thresholds == 0)
        return 0;

    /* Voltage limits and representable adjacent test values. */
    if (thresholds->undervoltage_mV == 0u)
        return 0;

    if (thresholds->undervoltage_mV >=
        thresholds->overvoltage_mV)
        return 0;

    if (thresholds->overvoltage_mV == UINT32_MAX)
        return 0;

    /* Current limits must be positive. */
    if (thresholds->max_discharge_current_mA <= 0)
        return 0;

    if (thresholds->max_discharge_current_mA == INT32_MAX)
        return 0;

    if (thresholds->max_charge_current_mA <= 0)
        return 0;

    /*
     * A positive charge threshold is safely negatable.
     * The adjacent negative test value can be represented by int32_t
     * when generated as -threshold - 1.
     */

    /* Temperature limits and representable adjacent test values. */
    if (thresholds->min_temperature_centi_C >=
        thresholds->max_temperature_centi_C)
        return 0;

    if (thresholds->min_temperature_centi_C == INT32_MIN)
        return 0;

    if (thresholds->max_temperature_centi_C == INT32_MAX)
        return 0;

    return 1;
}

uint32_t battery_diagnose_sample(
    const battery_sample_t *sample,
    const battery_thresholds_t *thresholds)
{
    uint32_t flags = 0u;

    if (sample->voltage_mV < thresholds->undervoltage_mV)
        flags |= BAT_DIAG_UNDERVOLTAGE;

    if (sample->voltage_mV > thresholds->overvoltage_mV)
        flags |= BAT_DIAG_OVERVOLTAGE;

    if (sample->current_mA >
        thresholds->max_discharge_current_mA)
        flags |= BAT_DIAG_DISCHARGE_OC;

    if (sample->current_mA <
        -thresholds->max_charge_current_mA)
        flags |= BAT_DIAG_CHARGE_OC;

    if (sample->temperature_centi_C <
        thresholds->min_temperature_centi_C)
        flags |= BAT_DIAG_UNDERTEMPERATURE;

    if (sample->temperature_centi_C >
        thresholds->max_temperature_centi_C)
        flags |= BAT_DIAG_OVERTEMPERATURE;

    return flags;
}
