/*
 * Native Ibex double-fault stimulus using the documented reset vector.
 *
 * Ibex starts at boot_addr + 0x80 and initializes mtvec to boot_addr.
 * The first ECALL is at the reset PC (0x00100080). The trap vector at
 * boot_addr (0x00100000) contains the second ECALL. That second synchronous
 * exception occurs before MRET and must assert double_fault_seen_o.
 *
 * This image is simulation-only and intentionally does not recover.
 */
    .section .text.init, "ax", @progbits
    .option push
    .option norvc
    .option norelax

    .globl native_double_fault_handler
    .type native_double_fault_handler, @function
native_double_fault_handler:
    ecall
.Lhandler_hold:
    jal     zero, .Lhandler_hold

    .org    0x80
    .globl _start
    .type _start, @function
_start:
    ecall
.Lmain_hold:
    jal     zero, .Lmain_hold

    .option pop
