const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    exe.linkLibC();

    b.installArtifact(exe);

    addUnitTestsStep(b);
}

const filesWithTests = [_][]const u8{
    "src/net/ip.zig",
    "src/net/tcp.zig",
    "src/net/utils.zig",
};

fn addUnitTestsStep(b: *std.Build) void {
    const test_step = b.step("test", "Run unit tests");

    for (filesWithTests) |file| {
        const unit_tests = b.addTest(.{
            .root_source_file = b.path(file),
            .target = b.host,
        });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }
}
