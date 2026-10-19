    .section .text.init, "ax", @progbits
    .globl _start
    .type _start, @function
    .option norvc

_start:
    # MMIO base: 0x00200000
    lui     t0, 0x200

    # Select Safety profile.
    addi    t1, zero, 1
    sw      t1, 0(t0)

    # Verify Safety status: valid=1, DCLS=1, injection=0, profile=01.
    lw      t2, 8(t0)
    addi    t3, zero, 13
    bne     t2, t3, fail

    # Initial heartbeat sequence. A changed full-word write is progress.
    addi    t1, zero, 1
    sw      t1, 16(t0)

    # Report successful profile initialization at RAM offset 0x1000.
    lui     t4, 0x101
    lui     t6, 0x6
    addi    t6, t6, 13
    sw      t6, 0(t4)

heartbeat_loop:
    # 24 iterations x (decrement + branch): service interval stays well
    # inside the 256-cycle supervisor window.
    addi    t5, zero, 24

heartbeat_delay:
    addi    t5, t5, -1
    bne     t5, zero, heartbeat_delay

    # Write a new sequence value each time.
    addi    t1, t1, 1
    sw      t1, 16(t0)
    jal     zero, heartbeat_loop

fail:
    # Failure marker: Safety profile readback was unexpected.
    addi    t6, zero, 1
    lui     t4, 0x101
    sw      t6, 0(t4)

fail_stop:
    jal     zero, fail_stop
