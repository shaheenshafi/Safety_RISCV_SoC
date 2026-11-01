# Stage 4F — Runtime Profile and Supervisor Policy

## Purpose

Define and verify the runtime configuration policy for Basic, Safety and Diagnostic operating profiles, including execution supervision and controlled fault-injection authorisation.

## Runtime profile policy

| Profile | Encoding | Valid | DCLS | Supervisor | Fault injection |
|---|---|---|---|---|---|
| Basic | 00 | Yes | Disabled | Enabled | Disabled |
| Safety | 01 | Yes | Enabled | Enabled | Disabled |
| Diagnostic | 10 | Yes | Enabled | Enabled | Only when authorised |
| Reserved | 11 | No | No | Disabled | Disabled |

The supervisor enable condition is profile_valid_o && !safe_state_req.

Supervision remains active in all three valid profiles and is disabled when the system enters safe state.

## Configuration protection

- Profile-control register: 0x00200000.
- Injection-authorisation register: 0x00200004.
- Reserved profile writes are rejected, preserving the previously selected valid profile.
- Fault injection is enabled only in Diagnostic mode when explicitly authorised.

## Execution supervision

The Stage 4F supervisor monitors:
- Windowed watchdog servicing.
- Application-level forward progress using heartbeat updates.

A heartbeat update requires an accepted full-word MMIO write with a changed sequence value and no active safe state.

Supervisor configuration:
- Minimum watchdog kick interval: 4 cycles.
- Maximum watchdog kick interval: 256 cycles.
- Application progress timeout: 256 cycles.

A supervisor fault is routed to the fault manager using fault code 0x03. The fault remains sticky until external reset and requests safe state.

The heartbeat represents application-level progress, not per-instruction retirement monitoring.

## Verification results

All six Stage 4F/4G regression scenarios passed in Verilator:

1. Normal dual-core heartbeat integration.
2. Runtime profile-policy integration.
3. RAM address guard.
4. Instruction address guard.
5. DCLS store inhibition.
6. Supervisor timeout.

The profile-policy test additionally verifies Reserved-profile rejection, Diagnostic injection authorisation, Basic-mode heartbeat servicing and Basic-mode timeout handling.

## Limitations

These results establish simulation behaviour only. They do not establish FPGA hardware validation, ISO 26262 certification or ASIL compliance.

## Next steps

1. Freeze and document the Stage 4F/4G safety implementation.
2. Implement representative battery voltage, current and temperature monitoring.
3. Perform FPGA synthesis and implementation.
4. Complete quantitative evaluation and dissertation documentation.
