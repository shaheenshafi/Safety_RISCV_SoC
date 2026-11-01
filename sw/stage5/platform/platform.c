#include "platform.h"

#define MMIO32(address) \
    (*(volatile uint32_t *)(uintptr_t)(address))

static uint32_t heartbeat_sequence;

uint32_t platform_profile_status_read(void)
{
    return MMIO32(PLATFORM_REG_PROFILE_STATUS);
}

uint32_t platform_fault_status_read(void)
{
    return MMIO32(PLATFORM_REG_FAULT_STATUS);
}

uint32_t platform_heartbeat_value_read(void)
{
    return MMIO32(PLATFORM_REG_HEARTBEAT);
}

int platform_profile_select(platform_profile_t profile)
{
    uint32_t status;

    if ((uint32_t)profile > (uint32_t)PLATFORM_PROFILE_DIAGNOSTIC)
        return -1;

    MMIO32(PLATFORM_REG_PROFILE_CTRL) = (uint32_t)profile;

    status = platform_profile_status_read();

    if ((status & PLATFORM_PROFILE_MASK) != (uint32_t)profile)
        return -2;

    if ((status & PLATFORM_PROFILE_VALID_MASK) == 0u)
        return -3;

    if ((profile == PLATFORM_PROFILE_SAFETY ||
         profile == PLATFORM_PROFILE_DIAGNOSTIC) &&
        (status & PLATFORM_DCLS_ENABLED_MASK) == 0u)
        return -4;

    return 0;
}

void platform_heartbeat_start(void)
{
    heartbeat_sequence = platform_heartbeat_value_read();
    platform_heartbeat_kick();
}

void platform_heartbeat_kick(void)
{
    heartbeat_sequence++;
    MMIO32(PLATFORM_REG_HEARTBEAT) = heartbeat_sequence;
}
