    .section .text.init, "ax", @progbits
    .globl _start
    .type _start, @function
    .option norvc

_start:
    # MMIO base: 0x00200000
    lui     t0, 0x200

    # Reset profile should be Basic: valid=1, DCLS=0, injection=0.
    lw      t1, 8(t0)
    addi    t2, zero, 4
    bne     t1, t2, fail_basic

    # Select Safety: expected status = 0xD.
    addi    t1, zero, 1
    sw      t1, 0(t0)
    lw      t1, 8(t0)
    addi    t2, zero, 13
    bne     t1, t2, fail_safety

    # Select Diagnostic without authorization: expected status = 0xE.
    addi    t1, zero, 2
    sw      t1, 0(t0)
    lw      t1, 8(t0)
    addi    t2, zero, 14
    bne     t1, t2, fail_diag_unauthorized

    # Authorize injection: Diagnostic status should now be 0x1E.
    addi    t1, zero, 1
    sw      t1, 4(t0)
    lw      t1, 8(t0)
    addi    t2, zero, 30
    bne     t1, t2, fail_diag_authorized

    # Check authorization register readback.
    lw      t1, 4(t0)
    addi    t2, zero, 1
    bne     t1, t2, fail_authorization_readback

    # No injected fault should have occurred.
    lw      t1, 12(t0)
    bne     t1, zero, fail_fault_status

    # Success marker: 0x0000600D.
    lui     t3, 0x6
    addi    t3, t3, 13
    jal     zero, report_result

fail_basic:
    addi    t3, zero, 1
    jal     zero, report_result

fail_safety:
    addi    t3, zero, 2
    jal     zero, report_result

fail_diag_unauthorized:
    addi    t3, zero, 3
    jal     zero, report_result

fail_diag_authorized:
    addi    t3, zero, 4
    jal     zero, report_result

fail_authorization_readback:
    addi    t3, zero, 5
    jal     zero, report_result

fail_fault_status:
    addi    t3, zero, 6

report_result:
    # Write result at physical CPU address 0x00101000.
    lui     t4, 0x101
    sw      t3, 0(t4)

done:
    jal     zero, done
