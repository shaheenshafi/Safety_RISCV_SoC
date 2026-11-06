OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
    . = 0x00100080;
    .text :
    {
        KEEP(*(.text.init))
        *(.text .text.*)
    }

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}

ASSERT(ADDR(.text) == 0x00100080,
       "ERROR: native double-fault test must start at 0x00100080")
