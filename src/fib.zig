export fn fib(n: u32) u32 {
    var a: u32 = 0;
    var b: u32 = 1;
    for (0..n) |_| {
        const tmp = b;
        b = a + b;
        a = tmp;
    }

    return a;
}
