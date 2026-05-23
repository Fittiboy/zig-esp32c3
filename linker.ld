ENTRY(_start)

MEMORY
{
  IRAM (rx)  : ORIGIN = 0x40380000, LENGTH = 0x10000
  DRAM (rw)  : ORIGIN = 0x3FC90000, LENGTH = 0x10000
}

SECTIONS
{
  .init : {
    KEEP(*(.init))
  } > IRAM

  .text : {
    *(.text*)
    *(.rodata*)
  } > IRAM

  .data : {
    *(.data*)
  } > DRAM

  .bss : {
    . = ALIGN(16);
    *(.bss*)
    *(COMMON)
    . = ALIGN(16);
  } > DRAM

  .stack (NOLOAD) : {
    . = ALIGN(16);
    _heap_start = .;
    . = ORIGIN(DRAM) + LENGTH(DRAM) - 4096;
    _heap_end = .;

    . = ALIGN(16);
    _stack_bottom = .;
    . = . + 4096;
    _stack_top = .;
  } > DRAM
}
