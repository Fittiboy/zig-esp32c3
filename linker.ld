OUTPUT_ARCH(riscv)
ENTRY(_start)

IRAM_ORIGIN = 0x40380000;
DRAM_ORIGIN = 0x3FC80000;

DRAM_END = 0x3FCE0000;

IRAM_TEXT_SIZE = 128K;
STACK_SIZE = 8K;

MEMORY
{
    iram  (rx) : ORIGIN = IRAM_ORIGIN,
                 LENGTH = IRAM_TEXT_SIZE

    dram  (rw) : ORIGIN = DRAM_ORIGIN + IRAM_TEXT_SIZE,
                 LENGTH = DRAM_END - (DRAM_ORIGIN + IRAM_TEXT_SIZE) - STACK_SIZE

    stack (rw) : ORIGIN = DRAM_END - STACK_SIZE,
                 LENGTH = STACK_SIZE

    rtc  (rwx) : ORIGIN = 0x50000000,
                 LENGTH = 8K
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        KEEP(*(.text.start .text.start.*))
        *(.text .text.*)
        *(.init)
        *(.fini)
        . = ALIGN(4);
        _text_end = .;
    } > iram

    .rodata :
    {
        . = ALIGN(4);
        *(.srodata .srodata.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _rodata_end = .;
    } > dram

    .data :
    {
        . = ALIGN(4);
        _data_start = .;
        *(.sdata .sdata.*)
        *(.data .data.*)
        . = ALIGN(4);
        _data_end = .;
    } > dram

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } > dram

    . = ALIGN(16);
    _heap_start = .;

    _stack_bottom = ORIGIN(stack);
    _stack_top    = ORIGIN(stack) + LENGTH(stack);

    _heap_end     = _stack_bottom;

    ASSERT(_heap_start <= _heap_end, "RAM overflow: no heap space left")
    ASSERT(SIZEOF(.text) <= IRAM_TEXT_SIZE, "IRAM text region overflowed")

    /DISCARD/ :
    {
        *(.comment)
        *(.eh_frame .eh_frame.*)
        *(.note .note.*)
    }

}
