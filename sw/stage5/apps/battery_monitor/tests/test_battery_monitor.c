#include <limits.h>
#include <stdio.h>

#include "battery_dataset.h"
#include "battery_monitor.h"

#define ARRAY_COUNT(x) (sizeof(x) / sizeof((x)[0]))

static const char *scenario_names[BATTERY_SAMPLE_COUNT] = {
    "Nominal",
    "Undervoltage",
    "Overvoltage",
    "Discharge OC",
    "Charge OC",
    "Undertemperature",
    "Overtemperature",
    "Combined abnormalities",
    "UV boundary",
    "OV boundary",
    "Discharge boundary",
    "Charge boundary",
    "Minimum temperature boundary",
    "Maximum temperature boundary"
};

static int test_invalid_configurations(void)
{
    battery_thresholds_t t;

    t = battery_reference_thresholds;
    t.undervoltage_mV = 0u;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.undervoltage_mV = t.overvoltage_mV;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.overvoltage_mV = UINT32_MAX;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.max_discharge_current_mA = 0;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.max_discharge_current_mA = INT32_MAX;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.max_charge_current_mA = 0;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.min_temperature_centi_C = t.max_temperature_centi_C;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.min_temperature_centi_C = INT32_MIN;
    if (battery_thresholds_validate(&t)) return 1;

    t = battery_reference_thresholds;
    t.max_temperature_centi_C = INT32_MAX;
    if (battery_thresholds_validate(&t)) return 1;

    return 0;
}

static int test_charge_current_extreme(void)
{
    battery_thresholds_t thresholds = battery_reference_thresholds;
    battery_sample_t sample = {
        400000u, INT32_MIN, 2500, 15u
    };

    thresholds.max_charge_current_mA = INT32_MAX;

    if (!battery_thresholds_validate(&thresholds))
        return 1;

    if (battery_diagnose_sample(&sample, &thresholds) !=
        BAT_DIAG_CHARGE_OC)
        return 1;

    return 0;
}

int main(void)
{
    unsigned int i;
    uint32_t aggregate_flags = 0u;

    _Static_assert(sizeof(battery_sample_t) == 16u,
                   "battery_sample_t must be 16 bytes");
    _Static_assert(sizeof(battery_thresholds_t) == 24u,
                   "battery_thresholds_t must be 24 bytes");
    _Static_assert(sizeof(battery_result_t) == 8u,
                   "battery_result_t must be 8 bytes");
    _Static_assert(ARRAY_COUNT(battery_test_dataset) ==
                   BATTERY_SAMPLE_COUNT,
                   "Incorrect dataset length");

    printf("Starting battery diagnostic unit tests\n");

    if (!battery_thresholds_validate(&battery_reference_thresholds)) {
        printf("FAIL: Reference thresholds rejected\n");
        return 1;
    }

    if (battery_thresholds_validate(NULL)) {
        printf("FAIL: NULL threshold configuration accepted\n");
        return 1;
    }

    for (i = 0u; i < BATTERY_SAMPLE_COUNT; i++) {
        const battery_test_vector_t *vector =
            &battery_test_dataset[i];

        uint32_t actual = battery_diagnose_sample(
            &vector->sample,
            &battery_reference_thresholds);

        if (vector->sample.sequence != (i + 1u)) {
            printf("FAIL: Incorrect sequence at scenario %u\n", i + 1u);
            return 1;
        }

        if (actual != vector->expected_flags) {
            printf("FAIL: Scenario %02u (%s): expected 0x%02X, got 0x%02X\n",
                   i + 1u, scenario_names[i],
                   vector->expected_flags, actual);
            return 1;
        }

        if ((actual & ~BAT_DIAG_ALL) != 0u) {
            printf("FAIL: Reserved diagnostic bits set\n");
            return 1;
        }

        aggregate_flags |= actual;

        printf("PASS: Scenario %02u - %-30s flags=0x%02X\n",
               i + 1u, scenario_names[i], actual);
    }

    if (aggregate_flags != BAT_DIAG_ALL) {
        printf("FAIL: Unexpected aggregate mask: 0x%02X\n",
               aggregate_flags);
        return 1;
    }

    if (test_invalid_configurations() != 0) {
        printf("FAIL: Invalid threshold configuration accepted\n");
        return 1;
    }

    if (test_charge_current_extreme() != 0) {
        printf("FAIL: Charge-current signed-limit boundary\\n");
        return 1;
    }

    printf("PASS: INT32_MIN charge-current boundary\n");
    printf("PASS: Reference threshold validation\n");
    printf("PASS: Invalid threshold configurations rejected\n");
    printf("PASS: Aggregate diagnostic mask = 0x%02X\n",
           aggregate_flags);
    printf("PASS: Reserved diagnostic bits remain zero\n");

    printf("\nBATTERY DIAGNOSTIC UNIT TEST: PASS\n");
    printf("Scenarios passed: %u/%u\n",
           BATTERY_SAMPLE_COUNT, BATTERY_SAMPLE_COUNT);

    return 0;
}
