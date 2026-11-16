#ifndef BATTERY_MONITOR_H
#define BATTERY_MONITOR_H

#include <stdint.h>
#include "battery_types.h"

/*
 * Returns 1 when the threshold configuration is valid.
 * Returns 0 for an invalid configuration.
 */
int battery_thresholds_validate(
    const battery_thresholds_t *thresholds
);

/*
 * Evaluates all six diagnostic conditions independently.
 *
 * Preconditions:
 * - sample is a valid non-NULL pointer.
 * - thresholds is a valid non-NULL pointer.
 * - thresholds have passed battery_thresholds_validate().
 *
 * Returns the per-sample diagnostic bitmask.
 * This function has no MMIO or hardware-supervisor side effects.
 */
uint32_t battery_diagnose_sample(
    const battery_sample_t *sample,
    const battery_thresholds_t *thresholds
);

#endif
