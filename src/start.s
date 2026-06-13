.section .text.start, "ax", @progbits
.globl _start
.type _start, @function

_start:
    la sp, _stack_top

    la t0, _bss_start
    la t1, _bss_end
1:
    # Zero out bss
    bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b

2:
    # Personal heap pointer convention
    la s11, _heap_start

    # Disable RTC Watchdog, so it doesn't
    # reset the board.
    li t0, 0x60008000 # Low-Power Management Base Address
    li t1, 0x50d83aa1 # Magic value for disabling write protection
    sw t1, 0xa8(t0)   # Disable write protection
    sw zero, 0x90(t0) # Clear the two active WDTCONFIGO bits
    sw zero, 0xa8(t0) # Re-enable write protection

    # Disable flash-boot watchdog, to prevent the even
    # faster resets than the RTC watchdog
    li t0, 0x6001f000   # Timer Group 0 Base Address
    li t1, 0x50d83aa1   # Magic value for disabling write protection
    sw t1, 0x64(t0)     # Disable write protection
    # Bit 22 requests a configuration update.
    # All other bits are clear:
    #   WDT_EN               = 0
    #   WDT_FLASHBOOT_MOD_EN = 0
    li t1, 0x00400000
    sw t1, 0x48(t0)     # TIMG_WDTCONFIG0_REG
    sw zero, 0x64(t0)   # Re-enable write protection

    call main

3:
    wfi
    j   3b
