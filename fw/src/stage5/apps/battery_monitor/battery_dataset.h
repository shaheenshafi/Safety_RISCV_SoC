#ifndef BATTERY_DATASET_H
#define BATTERY_DATASET_H

#include "battery_types.h"

typedef struct {
    battery_sample_t sample;
    uint32_t expected_flags;
} battery_test_vector_t;

extern const battery_thresholds_t battery_reference_thresholds;

extern const battery_test_vector_t
    battery_test_dataset[BATTERY_SAMPLE_COUNT];

#endif
