const std = @import("std");

pub fn build(b: *std.Build) void {
    const riscv = std.Target.riscv;

    var install_step = b.getInstallStep();
    const target_name = "lab";
    const port = b.option([]const u8, "port", "serial port") orelse "/dev/ttyACM0";

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,

        .cpu_model = .{ .explicit = &riscv.cpu.generic_rv32 },
        .cpu_features_add = riscv.featureSet(&.{.reserve_x27}),
    });

    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .Debug,
    });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .sanitize_c = .off,
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });

    mod.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "main.S",
            "start.S",
        },
        .flags = &.{
            "-march=rv32i",
            "-mno-relax",
            "-ffreestanding",
        },
    });

    const elf = b.addExecutable(.{
        .name = target_name,
        .root_module = mod,
    });

    elf.setLinkerScript(b.path("linker.ld"));
    elf.entry = .{ .symbol_name = "_start" };
    elf.bundle_compiler_rt = false;

    b.installArtifact(elf);

    const elf_path = elf.getEmittedBin();

    const boot = b.addSystemCommand(&.{
        "esptool",   "--chip",   "esp32c3",
        "elf2image", "--output",
    });
    const boot_bin = boot.addOutputFileArg("lab.bin");
    boot.addFileArg(elf_path);

    const raw = b.addSystemCommand(&.{ "zig", "objcopy", "-O", "binary" });
    raw.addFileArg(elf_path);
    const raw_bin = raw.addOutputFileArg("lab.raw.bin");

    const text = b.addSystemCommand(&.{
        "zig", "objcopy",
        "-O",  "binary",
        "-j",  ".init",
        "-j",  ".text",
    });
    text.addFileArg(elf_path);
    const text_bin = text.addOutputFileArg("lab.text.bin");

    const lst = b.addSystemCommand(&.{
        "riscv64-elf-objdump",
        "-d",
        "-S",
        "-M",
        "no-aliases,numeric",
    });
    lst.addFileArg(elf_path);
    const listing = lst.captureStdOut(.{});

    var install_bin = b.addInstallFile(boot_bin, "lab.bin");
    var install_raw = b.addInstallFile(raw_bin, "lab.raw.bin");
    var install_text = b.addInstallFile(text_bin, "lab.text.bin");
    var install_listing = b.addInstallFile(listing, "lab.lst");
    install_step.dependOn(&install_bin.step);
    install_step.dependOn(&install_raw.step);
    install_step.dependOn(&install_text.step);
    install_step.dependOn(&install_listing.step);

    const flash = b.step("flash", "Flash ESP32-C3 image");
    const flash_cmd = b.addSystemCommand(&.{
        "esptool", "--chip", "esp32c3",
        "--port",  port,     "write-flash",
        "0x10000",
    });
    flash_cmd.addFileArg(boot_bin);
    flash.dependOn(&flash_cmd.step);

    const run = b.step("run", "Load image into RAM with esptool");
    const run_cmd = b.addSystemCommand(&.{
        "esptool",  "--chip", "esp32c3",
        "--port",   port,     "--no-stub",
        "load-ram",
    });
    run_cmd.addFileArg(boot_bin);
    run.dependOn(&run_cmd.step);

    const disasm = b.step("disasm", "Disassemble text binary");
    const disasm_cmd = b.addSystemCommand(&.{
        "riscv64-elf-objdump", "-D",
        "-b",                  "binary",
        "-m",                  "riscv:rv32",
        "-M",                  "no-aliases,numeric",
    });
    disasm_cmd.addFileArg(text_bin);
    disasm.dependOn(&disasm_cmd.step);

    const openocd = b.step("openocd", "Launch OpenOCD server on target");
    const openocd_cmd = b.addSystemCommand(&.{
        "openocd", "-f", "board/esp32c3-builtin.cfg",
    });
    openocd.dependOn(&openocd_cmd.step);

    const gdb = b.step("gdb", "Open GDB on ELF");
    const gdb_cmd = b.addSystemCommand(&.{"riscv32-elf-gdb"});
    gdb_cmd.addFileArg(elf_path);
    gdb.dependOn(&gdb_cmd.step);

    const clean = b.step("clean", "Cleans the build directory");
    const clean_cmd = b.addSystemCommand(&.{
        "rm", "-rf", "zig-out",
    });
    clean.dependOn(&clean_cmd.step);
}
