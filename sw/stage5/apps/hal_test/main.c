#include <stdint.h>
#include "platform.h"

#define HAL_TEST_RESULT_ADDR  0x00103FC0u
#define HAL_TEST_RUNNING      0x52554E31u
#define HAL_TEST_PASS         0x50415353u
#define HAL_TEST_FAIL_PROFILE 0xBAD50001u

int main(void)
{
    volatile uint32_t *result =
        (volatile uint32_t *)(uintptr_t)HAL_TEST_RESULT_ADDR;

    uint32_t heartbeat_count = 0u;
    int profile_result;

    result[0] = HAL_TEST_RUNNING;

    /* Select Safety profile and verify hardware readback. */
    profile_result = platform_profile_select(PLATFORM_PROFILE_SAFETY);

    if (profile_result != 0) {
        result[0] = HAL_TEST_FAIL_PROFILE;
        result[1] = (uint32_t)profile_result;

        while (1) {
            __asm__ volatile ("nop");
        }
    }

    result[1] = platform_profile_status_read();

    /* Initialize the changing heartbeat sequence. */
    platform_heartbeat_start();

    result[0] = HAL_TEST_PASS;
    result[2] = heartbeat_count;

    while (1) {
        /* Deliberate delay between successive heartbeat services. */
        volatile uint32_t delay = 12u;

        while (delay != 0u) {
            __asm__ volatile ("nop");
            delay--;
        }

        platform_heartbeat_kick();

        heartbeat_count++;
        result[2] = heartbeat_count;
    }

    return 0;
}
