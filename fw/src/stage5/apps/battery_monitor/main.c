#include <stdint.h>

#include "platform.h"
#include "battery_monitor.h"
#include "battery_dataset.h"

#define BATTERY_SUMMARY_ADDR       0x00103FC0u

#define BATTERY_MARKER_RUNNING     0x42545231u
#define BATTERY_MARKER_PASS        0x42545053u
#define BATTERY_MARKER_FAIL        0xBAD50001u

#define BATTERY_FAIL_PROFILE       1u
#define BATTERY_FAIL_THRESHOLDS    2u
#define BATTERY_FAIL_SAMPLE        3u
#define BATTERY_FAIL_AGGREGATE     4u
#define BATTERY_FAIL_HW_FAULT      5u

/*
 * Individual records reside in each core's application RAM (.noinit).
 * This buffer is intentionally separate from the 64-byte summary region.
 */
volatile battery_result_t battery_results[BATTERY_SAMPLE_COUNT] __attribute__((section(".noinit")));

/* Reserved 64-byte summary region at 0x00103FC0. */
static volatile uint32_t * const battery_summary =
    (volatile uint32_t *)(uintptr_t)BATTERY_SUMMARY_ADDR;

#define BATTERY_MEMORY_FENCE() \
    __asm__ volatile ("fence rw, rw" ::: "memory")

static void battery_application_fail(uint32_t code,
                                     uint32_t detail)
{
    battery_summary[5] = code;
    battery_summary[6] = detail;
    BATTERY_MEMORY_FENCE();
    battery_summary[0] = BATTERY_MARKER_FAIL;

    for (;;) {
        __asm__ volatile ("nop");
    }
}

int main(void)
{
    uint32_t aggregate_flags = 0u;
    uint32_t checksum = 0xA5A5A5A5u;
    uint32_t processed_count = 0u;
    uint32_t heartbeat_count = 0u;
    uint32_t profile_status;
    uint32_t hardware_fault_status;
    unsigned int i;
    int status;

    _Static_assert(sizeof(battery_result_t) == 8u,
                   "Unexpected battery result structure size");

    /*
     * Invalidate any result left by an earlier run before touching profile
     * control, heartbeat MMIO, or other safety infrastructure.  The summary
     * is valid only while word 0 contains PASS; retained detail words and
     * .noinit sample records are ignored until this run republishes PASS.
     */
    battery_summary[0] = BATTERY_MARKER_RUNNING;
    BATTERY_MEMORY_FENCE();

    /* Select and verify the Safety profile. */
    status = platform_profile_select(PLATFORM_PROFILE_SAFETY);

    if (status != 0)
        battery_application_fail(BATTERY_FAIL_PROFILE,
                                 (uint32_t)status);

    profile_status = platform_profile_status_read();

    /* Initialize the application heartbeat sequence. */
    platform_heartbeat_start();
    heartbeat_count = 1u;

    /* Validate the reference diagnostic configuration. */
    if (!battery_thresholds_validate(&battery_reference_thresholds))
        battery_application_fail(BATTERY_FAIL_THRESHOLDS, 0u);

    /* Service the supervisor before beginning the sample workload. */
    platform_heartbeat_kick();
    heartbeat_count++;

    /* Process the same deterministic dataset on both cores. */
    for (i = 0u; i < BATTERY_SAMPLE_COUNT; i++) {
        const battery_test_vector_t *vector =
            &battery_test_dataset[i];

        uint32_t flags = battery_diagnose_sample(
            &vector->sample,
            &battery_reference_thresholds
        );

        /* Retain the individual result in application RAM. */
        battery_results[i].sequence = vector->sample.sequence;
        battery_results[i].diagnostic_flags = flags;

        if (flags != vector->expected_flags)
            battery_application_fail(BATTERY_FAIL_SAMPLE, i + 1u);

        /* Service the supervisor after validating this sample. */
        platform_heartbeat_kick();
        heartbeat_count++;

        aggregate_flags |= flags;

        /* Deterministic rolling checksum over sequence and flags. */
        checksum = (checksum << 5) | (checksum >> 27);
        checksum ^= vector->sample.sequence;

        checksum = (checksum << 5) | (checksum >> 27);
        checksum ^= flags;

        processed_count++;
    }

    /* Bridge the transition from sample processing to final reporting. */
    platform_heartbeat_kick();
    heartbeat_count++;

    if (processed_count != BATTERY_SAMPLE_COUNT)
        battery_application_fail(BATTERY_FAIL_SAMPLE,
                                 processed_count);

    if (aggregate_flags != BAT_DIAG_ALL)
        battery_application_fail(BATTERY_FAIL_AGGREGATE,
                                 aggregate_flags);

    hardware_fault_status = platform_fault_status_read();

    if (hardware_fault_status != 0u)
        battery_application_fail(BATTERY_FAIL_HW_FAULT,
                                 hardware_fault_status);

    /*
     * Publish the summary. Word 0 is written last so PASS indicates
     * that all preceding summary fields have been populated.
     */
    battery_summary[1] = profile_status;
    battery_summary[2] = processed_count;
    battery_summary[3] = aggregate_flags;
    battery_summary[4] = checksum;

    /* Service the supervisor during summary publication. */
    platform_heartbeat_kick();
    heartbeat_count++;

    battery_summary[5] = 0u;
    battery_summary[6] = hardware_fault_status;
    battery_summary[7] = platform_heartbeat_value_read();
    battery_summary[8] = heartbeat_count;
    BATTERY_MEMORY_FENCE();
    battery_summary[0] = BATTERY_MARKER_PASS;

    /* Keep the application heartbeat alive after workload completion. */
    for (;;) {
        volatile uint32_t delay = 12u;

        while (delay != 0u) {
            __asm__ volatile ("nop");
            delay--;
        }

        platform_heartbeat_kick();
    }
}
