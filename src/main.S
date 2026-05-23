    .section .text
    .globl main
    .type main, @function

main:
    li a0, 10
    call fib

    # GPIO Base Address
    lui  s0, 0x60004

    # Pin 8 enable value
    li   t0, (1 << 8)
    # Write value to register
    sw   t0, 0x24(s0)

loop:
    # Load current value
    lw   s1, 0x4(s0)
    # Toggle bit 8
    xori s1, s1, (1 << 8)
    # Write value back
    sw   s1, 0x4(s0)

    # Set up busy loop
    li   t0, 5000000

delay:
    # Decrement loop variable
    addi t0, t0, -1
    # Back to `delay` if not at zero
    bnez t0, delay

    j    loop
