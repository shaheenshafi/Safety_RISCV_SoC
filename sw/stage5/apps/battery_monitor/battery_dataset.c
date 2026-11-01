#include "battery_dataset.h"

/*
 * Fictional 400-V-class lithium-ion reference pack.
 * Values are illustrative simulation assumptions only.
 */
const battery_thresholds_t battery_reference_thresholds = {
    .undervoltage_mV = 300000u,
    .overvoltage_mV = 450000u,
    .max_discharge_current_mA = 200000,
    .max_charge_current_mA = 150000,
    .min_temperature_centi_C = -2000,
    .max_temperature_centi_C = 6000
};

/*
 * Fourteen deterministic test scenarios.
 * Strict threshold comparisons are defined in battery_monitor.c.
 */
const battery_test_vector_t
battery_test_dataset[BATTERY_SAMPLE_COUNT] = {

    /* Sequence 1: Nominal operation */
    {{400000u,       0,  2500,  1u}, 0x00u},

    /* Sequences 2-7: Individual abnormal conditions */
    {{299999u,       0,  2500,  2u}, 0x01u},
    {{450001u,       0,  2500,  3u}, 0x02u},
    {{400000u,  200001,  2500,  4u}, 0x04u},
    {{400000u, -150001,  2500,  5u}, 0x08u},
    {{400000u,       0, -2001,  6u}, 0x10u},
    {{400000u,       0,  6001,  7u}, 0x20u},

    /* Sequence 8: Combined abnormalities */
    {{299999u,  200001,  6001,  8u}, 0x25u},

    /* Sequences 9-14: Strict-comparison boundaries */
    {{300000u,       0,  2500,  9u}, 0x00u},
    {{450000u,       0,  2500, 10u}, 0x00u},
    {{400000u,  200000,  2500, 11u}, 0x00u},
    {{400000u, -150000,  2500, 12u}, 0x00u},
    {{400000u,       0, -2000, 13u}, 0x00u},
    {{400000u,       0,  6000, 14u}, 0x00u}
};
