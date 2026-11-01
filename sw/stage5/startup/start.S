.section .text.init, "ax", @progbits
.align 2
.globl _start
.type _start, @function

_start:
    .option push
    .option norelax
    la sp, __stack_top
    .option pop

    # Initialize .bss to zero
    la t0, __bss_start
    la t1, __bss_end

.Lzero_bss:
    bgeu t0, t1, .Lbss_done
    sw zero, 0(t0)
    addi t0, t0, 4
    j .Lzero_bss

.Lbss_done:
    call main

.Lhang:
    j .Lhang

.size _start, .-_start
