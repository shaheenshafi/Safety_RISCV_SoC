OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM_APP    (rwx) : ORIGIN = 0x00100000, LENGTH = 0x3000
    RAM_STACK  (rw)  : ORIGIN = 0x00103000, LENGTH = 0x0FC0
    RAM_RESULT (rw)  : ORIGIN = 0x00103FC0, LENGTH = 0x0040
}

__stack_bottom = ORIGIN(RAM_STACK);
__stack_top    = ORIGIN(RAM_STACK) + LENGTH(RAM_STACK);

__result_start = ORIGIN(RAM_RESULT);
__result_end   = ORIGIN(RAM_RESULT) + LENGTH(RAM_RESULT);

SECTIONS
{
    .text ORIGIN(RAM_APP) + 0x80 :
    {
        KEEP(*(.text.init))
        *(.text .text.*)
    } > RAM_APP

    .rodata :
    {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > RAM_APP

    .data :
    {
        . = ALIGN(4);
        __data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > RAM_APP

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM_APP

    .noinit 0x00100968 (NOLOAD) :
    {
        . = ALIGN(4);
        __noinit_start = .;
        *(.noinit .noinit.*)
        . = ALIGN(4);
        __noinit_end = .;
    } > RAM_APP

    . = ALIGN(16);
    __image_end = .;

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}

ASSERT(__image_end <= ORIGIN(RAM_APP) + LENGTH(RAM_APP),
       "ERROR: Firmware exceeds application RAM")

ASSERT((__stack_top & 15) == 0,
       "ERROR: Stack top is not 16-byte aligned")

ASSERT(__bss_end <= __image_end,
       "ERROR: BSS extends beyond application image")

ASSERT(__bss_end <= 0x00100968,
       "ERROR: BSS overlaps battery result buffer")

ASSERT(__noinit_end <= ORIGIN(RAM_APP) + LENGTH(RAM_APP),
       "ERROR: Battery result buffer exceeds application RAM")

ASSERT(ADDR(.noinit) == 0x00100968,
       "ERROR: Battery result buffer address changed")

ASSERT(SIZEOF(.noinit) <= 112,
       "ERROR: .noinit exceeds the permitted result-buffer size")

ASSERT(ADDR(.text) == ORIGIN(RAM_APP) + 0x80,
       "ERROR: Firmware entry must be at boot address + 0x80")
