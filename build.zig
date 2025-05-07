const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const gobject = b.dependency("gobject", .{
        .target = target,
        .optimize = optimize,
    });

    exe_module.addImport("gobject", gobject.module("gobject2"));
    exe_module.addImport("glib", gobject.module("glib2"));
    exe_module.addImport("gio", gobject.module("gio2"));
    exe_module.addImport("gtk", gobject.module("gtk4"));
    exe_module.addImport("adw", gobject.module("adw1"));
    exe_module.addImport("gtk4-layer-shell", gtk4LayerShellModule(b, target, optimize));
    exe_module.addImport("pulseaudio", pulseAudioModule(b, target, optimize));

    exe_module.linkSystemLibrary("gtk4", dynamic_link_opts);
    exe_module.linkSystemLibrary("libadwaita-1", dynamic_link_opts);

    // PulseAudio

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "zosd",
        .root_module = exe_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_module,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

const dynamic_link_opts: std.Build.Module.LinkSystemLibraryOptions = .{
    .preferred_link_mode = .dynamic,
    .search_strategy = .mode_first,
};

fn gtk4LayerShellModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const gobject = b.dependency("gobject", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.createModule(.{
        .root_source_file = b.path("pkg/gtk4-layer-shell/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    module.addImport("gtk", gobject.module("gtk4"));
    module.linkSystemLibrary("gtk4-layer-shell-0", dynamic_link_opts);
    module.linkSystemLibrary("gtk4", dynamic_link_opts);

    return module;
}

fn pulseAudioModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const gobject = b.dependency("gobject", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.createModule(.{
        .root_source_file = b.path("pkg/pulseaudio/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    module.addImport("glib", gobject.module("glib2"));
    module.linkSystemLibrary("libpulse", dynamic_link_opts);
    module.linkSystemLibrary("libpulse-mainloop-glib", dynamic_link_opts);

    return module;
}
