#include <stdint.h>

volatile uint32_t bss_probe;
volatile uint32_t data_probe = 0x13579BDFu;

int main(void)
{
    volatile uint32_t a = 7u;
    volatile uint32_t b = 5u;

    volatile uint32_t *result =
        (volatile uint32_t *)0x00103FC0u;

    if ((bss_probe == 0u) &&
        (data_probe == 0x13579BDFu)) {
        *result = a + b;
    } else {
        *result = 0xBAD00001u;
    }

    bss_probe = 1u;

    while (1) {
        __asm__ volatile ("nop");
    }

    return 0;
}
