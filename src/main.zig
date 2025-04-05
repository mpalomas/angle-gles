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
var gl_procs: gl.ProcTable = undefined;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (builtin.os.tag == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var printExtensions: bool = false;

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    while (args.next()) |arg| {
        // std.debug.print("this is the argument {s}", .{arg});
        if (std.mem.eql(u8, arg, "--printExtensions")) {
            printExtensions = true;
        }
    }

    _ = glfw.glfwSetErrorCallback(errorCallback);

    if (glfw.glfwInit() == 0) {
        return error.InitFailed;
    }

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_OPENGL_ES_API);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 0);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_CREATION_API, glfw.GLFW_EGL_CONTEXT_API);

    const window = glfw.glfwCreateWindow(640, 480, "OpenGL ES 3.0 Triangle (EGL)", null, null);
    if (window == null) {
        return error.WindowFailed;
    }

    glfw.glfwMakeContextCurrent(window);

    // Initialize the procedure table.
    if (!gl_procs.init(glfw.glfwGetProcAddress)) return error.GlProcInitFailed;

    // Make the procedure table current on the calling thread.
    gl.makeProcTableCurrent(&gl_procs);
    defer gl.makeProcTableCurrent(null);

    printGLInfo(printExtensions);

    // will crash: https://github.com/glfw/glfw/issues/2380
    // defer glfw.glfwTerminate();
}

fn printGLInfo(print_extensions: bool) void {
    const renderer = gl.GetString(gl.RENDERER);
    const version = gl.GetString(gl.VERSION);
    const glsl_version = gl.GetString(gl.SHADING_LANGUAGE_VERSION);

    std.log.info("OpenGL renderer: {s}", .{renderer.?});
    std.log.info("{s}", .{version.?});
    std.log.info("{s}", .{glsl_version.?});

    // Get the number of extensions available
    var numExtensions: c_int = 0;
    gl.GetIntegerv(gl.NUM_EXTENSIONS, @ptrCast(&numExtensions));

    std.log.info("OpenGL extension count: {d}", .{numExtensions});

    if (print_extensions) {
        // Loop through all available extensions and print them
        for (0..@intCast(numExtensions)) |ext_idx| {
            const ext_name = gl.GetStringi(gl.EXTENSIONS, @intCast(ext_idx));
            if (ext_name) |name| {
                std.log.info("{s}", .{name});
            }
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
