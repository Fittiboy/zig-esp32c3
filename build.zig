const std = @import("std");

pub fn build(b: *std.Build) void {
    const riscv = std.Target.riscv;

    var install_step = b.getInstallStep();

    // Output files will be `[base_name].bin` etc.
    const base_name = b.option(
        []const u8,
        "name",
        "The base name of the output files (default: \"lab\")",
    ) orelse "lab";

    const boot_name = b.fmt("{s}.bin", .{base_name});
    const list_name = b.fmt("{s}.lst", .{base_name});

    // Required only for the flash and run steps.
    const port = b.option(
        []const u8,
        "port",
        "Serial port for connecting to the board (default: /dev/ttyACM0)",
    ) orelse "/dev/ttyACM0";

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,

        .cpu_model = .{ .explicit = &riscv.cpu.generic_rv32 },
        // By personal convention, the x27 register, or s11,
        // is used as a heap pointer, growing up toward the stack.
        .cpu_features_add = riscv.featureSet(&.{.reserve_x27}),
    });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = b.standardOptimizeOption(.{}),
        .single_threaded = true,
        // Inclusion of Assembly files would otherwise cause
        // the build to fail, trying to use ubsan.
        .sanitize_c = .off,
    });

    mod.addAssemblyFile(b.path("src/main.s"));
    mod.addAssemblyFile(b.path("src/start.s"));

    const elf = b.addExecutable(.{
        .name = base_name,
        .root_module = mod,
    });

    elf.setLinkerScript(b.path("linker.ld"));
    // This symbol is found in `src/start.s`.
    elf.entry = .{ .symbol_name = "_start" };
    elf.bundle_compiler_rt = false;

    b.installArtifact(elf);

    const elf_path = elf.getEmittedBin();

    // The bootable binary is the final executable
    // output, and the only file required for flashing.
    // It is created from the `elf` artifact above.
    const boot = b.addSystemCommand(&.{
        // zig fmt: off
        "esptool",
        "--chip",       "esp32c3",
        "elf2image",
        "--flash-mode", "dio",
        "--flash-freq", "40m",
        "--output",
        // zig fmt: on
    });
    const boot_bin = boot.addOutputFileArg(boot_name);
    boot.addFileArg(elf_path);

    // Disassembly of the final non-bootable binary
    const lst = b.addSystemCommand(&.{
        "riscv64-elf-objdump", "-d",         "-S",
        "-M",                  "no-aliases",
    });
    lst.addFileArg(elf_path);
    const listing = lst.captureStdOut(.{});

    // -------------------
    // Installed Artifacts
    // -------------------

    var install_bin = b.addInstallFile(boot_bin, boot_name);
    var install_listing = b.addInstallFile(listing, list_name);
    install_step.dependOn(&install_bin.step);
    install_step.dependOn(&install_listing.step);

    // -----------
    // Build Steps
    // -----------

    const flash = b.step("flash", "Flash ESP32-C3 image");
    const flash_cmd = b.addSystemCommand(&.{
        // zig fmt: off
        "esptool",
        "--chip",       "esp32c3",
        "--port",       port,
        "write-flash",
        "--flash-mode", "dio",
        "--flash-freq", "40m",
        "--flash-size", "detect",
        "0x0",
        // zig fmt: on
    });
    flash_cmd.addFileArg(boot_bin);
    flash.dependOn(&flash_cmd.step);

    const openocd = b.step("openocd", "Launch OpenOCD server on target");
    const openocd_cmd = b.addSystemCommand(&.{
        "openocd", "-f", "board/esp32c3-builtin.cfg",
    });
    openocd.dependOn(&openocd_cmd.step);

    const gdb = b.step("gdb", "Run GDB with the emitted ELF");
    const gdb_cmd = b.addSystemCommand(&.{"riscv64-elf-gdb"});
    gdb_cmd.addFileArg(elf_path);
    gdb.dependOn(&gdb_cmd.step);
}
