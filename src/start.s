.section .text.start, "ax", @progbits
.globl _start
.type _start, @function

_start:
    la sp, _stack_top
    # Personal heap pointer convention
    la s11, _heap_start

    la t0, _bss_start
    la t1, _bss_end

    # Disable flash-boot watchdog, to prevent resets
    li t0, 0x6001f000   # Timer Group 0 Base Address
    li t1, 0x50d83aa1   # Magic value for disabling write protection
    sw t1, 0x64(t0)     # Disable write protection
    # Bit 22 requests a configuration update.
    # All other bits are clear:
    #   WDT_EN               = 0
    #   WDT_FLASHBOOT_MOD_EN = 0
    li t1, 0x00400000
    sw t1, 0x48(t0)     # Disable watchdog
    sw zero, 0x64(t0)   # Re-enable write protection

    # Disable RTC Watchdog, so it also
    # doesn't reset the board.
    li t0, 0x60008000   # Low-Power Management Base Address
    li t1, 0x50d83aa1   # Magic value for disabling write protection
    sw t1, 0xa8(t0)     # Disable write protection
    sw zero, 0x90(t0)   # Clear the two active WDTCONFIGO bits
    sw zero, 0xa8(t0)   # Re-enable write protection

    # Another watchdog to disable, the analog-domain
    # Super Watchdog (SWD)
    # (Base address shared with RTC Watchdog)
    # ... Where are all these dogs coming from?
    li t1, 0x8f1d312a   # Same base address, different key!
    sw t1, 0xb0(t0)     # Disable write protection
    li t1, 0x40000000   # Bit 30 disables this dog
    sw t1, 0xac(t0)     # Disable SWD
    sw zero, 0xb0(t0)   # Re-enable write protection

1:
    # Zero out bss
    bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b

2:
    call main

3:
    wfi
    j   3b
