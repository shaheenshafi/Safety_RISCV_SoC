#ifndef STAGE5_PLATFORM_H
#define STAGE5_PLATFORM_H

#include <stdint.h>

/* Stage 4F-compatible MMIO register map */
#define PLATFORM_REG_PROFILE_CTRL    0x00200000u
#define PLATFORM_REG_INJECTION_AUTH  0x00200004u
#define PLATFORM_REG_PROFILE_STATUS  0x00200008u
#define PLATFORM_REG_FAULT_STATUS    0x0020000Cu
#define PLATFORM_REG_HEARTBEAT       0x00200010u

/* Profile encodings */
typedef enum {
    PLATFORM_PROFILE_BASIC      = 0u,
    PLATFORM_PROFILE_SAFETY     = 1u,
    PLATFORM_PROFILE_DIAGNOSTIC = 2u
} platform_profile_t;

/* Profile status fields */
#define PLATFORM_PROFILE_MASK          0x03u
#define PLATFORM_PROFILE_VALID_MASK    (1u << 2)
#define PLATFORM_DCLS_ENABLED_MASK     (1u << 3)
#define PLATFORM_INJECTION_ENABLED_MASK (1u << 4)

/* Fault status fields */
#define PLATFORM_FAULT_LATCHED_MASK    (1u << 0)
#define PLATFORM_INSTR_FAULT_MASK     (1u << 1)
#define PLATFORM_DATA_FAULT_MASK      (1u << 2)
#define PLATFORM_SUPERVISOR_FAULT_MASK (1u << 3)
#define PLATFORM_FAULT_CODE_MASK      0x0000FF00u
#define PLATFORM_FAULT_CODE_SHIFT     8u

/* Returns 0 on successful profile readback; negative on error. */
int platform_profile_select(platform_profile_t profile);

uint32_t platform_profile_status_read(void);
uint32_t platform_fault_status_read(void);
uint32_t platform_heartbeat_value_read(void);

/* Call once after startup; subsequent calls service the heartbeat. */
void platform_heartbeat_start(void);
void platform_heartbeat_kick(void);

#endif
