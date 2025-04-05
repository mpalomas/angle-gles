//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.
const builtin = @import("builtin");

const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});

const gl = @import("gles30.zig");

// https://gist.github.com/kassane/a81d1ae2fa2e8c656b91afee8b949426
pub const log_level: std.log.Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe => .debug,
    .ReleaseFast, .ReleaseSmall => .info,
};
pub const std_options: std.Options = .{
    .log_level = log_level,
};

fn errorCallback(_: c_int, desc: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW Error: {s}\n", .{desc});
}

// Procedure table that will hold OpenGL functions loaded at runtime.
var procs: gl.ProcTable = undefined;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // Don't forget to flush!

    _ = glfw.glfwSetErrorCallback(errorCallback);

    if (glfw.glfwInit() == 0) {
        return error.InitFailed;
    }

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_OPENGL_ES_API);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 0);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_CREATION_API, glfw.GLFW_EGL_CONTEXT_API);

    // TODO/note
    // on macOS (Linux?) this will look (dlopen) for libEGL...
    // zig build run does NOT work but running from zig-out/bin DOES work
    // find a way to get it work in BOTH cases
    const window = glfw.glfwCreateWindow(640, 480, "OpenGL ES 3.0 Triangle (EGL)", null, null);
    if (window == null) {
        return error.WindowFailed;
    }

    glfw.glfwMakeContextCurrent(window);

    // Initialize the procedure table.
    if (!procs.init(glfw.glfwGetProcAddress)) return error.GlProcInitFailed;

    // Make the procedure table current on the calling thread.
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    printGLInfo();

    // will crash: https://github.com/glfw/glfw/issues/2380
    // defer glfw.glfwTerminate();
}

fn printGLInfo() void {
    const renderer = gl.GetString(gl.RENDERER);
    const version = gl.GetString(gl.VERSION);
    const glsl_version = gl.GetString(gl.SHADING_LANGUAGE_VERSION);

    std.log.debug("OpenGL renderer: {s}", .{renderer.?});
    std.log.debug("{s}", .{version.?});
    std.log.debug("{s}", .{glsl_version.?});

    // Get the number of extensions available
    var numExtensions: c_int = 0;
    gl.GetIntegerv(gl.NUM_EXTENSIONS, @ptrCast(&numExtensions));

    std.log.debug("OpenGL extensions count: {d}", .{numExtensions});

    // Loop through all available extensions and print them
    for (0..@intCast(numExtensions)) |ext_idx| {
        const ext_name = gl.GetStringi(gl.EXTENSIONS, @intCast(ext_idx));
        if (ext_name) |name| {
            // _ = name;
            std.log.debug("{s}", .{name});
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("angle_gles_lib");
