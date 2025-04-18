const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const allocator = std.heap.page_allocator;

    // Google Angle

    const angle_lib_dir_path = switch (target.result.os.tag) {
        .linux => "libs/angle/linux-x86_64/",
        .macos => "libs/angle/macos-aarch64/",
        .windows => "libs/angle/windows-x86_64/",
        else => unreachable,
    };

    const egl_lib_name = switch (target.result.os.tag) {
        .linux => "libEGL.so",
        .macos => "libEGL.dylib",
        .windows => "libEGL.dll",
        else => unreachable,
    };

    const gles_lib_name = switch (target.result.os.tag) {
        .linux => "libGLESv2.so",
        .macos => "libGLESv2.dylib",
        .windows => "libGLESv2.dll",
        else => unreachable,
    };

    const gles3_lib_name = "GLESv3.dll";

    const egl_lib_link_name = "libEGL.so.1";
    const gles_lib_link_name = "libGLESv2.so.2";

    const angle_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        // .link_libc = true,
        // .link_libcpp = true,
    });
    const angle_lib = b.addLibrary(.{
        .name = "angle",
        .linkage = .static,
        .root_module = angle_mod,
        .use_lld = if (target.result.os.tag == .windows) true else false,
        .use_llvm = if (target.result.os.tag == .windows) true else false,
    });
    angle_mod.addCSourceFile(.{ .file = b.addWriteFiles().add("empty.c", "") });
    angle_lib.installHeadersDirectory(b.path("libs/angle/include"), "", .{});
    if (target.result.os.tag == .macos or target.result.os.tag == .windows or target.result.os.tag == .linux) {
        const egl_parts = [_][]const u8{ angle_lib_dir_path, egl_lib_name };
        const egl_lib_full_path = std.mem.concat(allocator, u8, &egl_parts) catch unreachable;
        // defer allocator.destroy(egl_parts);

        const gles_parts = [_][]const u8{ angle_lib_dir_path, gles_lib_name };
        const gles_lib_full_path = std.mem.concat(allocator, u8, &gles_parts) catch unreachable;
        // defer allocator.destroy(gles_parts);

        b.installBinFile(egl_lib_full_path, egl_lib_name);
        b.installBinFile(gles_lib_full_path, gles_lib_name);

        if (target.result.os.tag == .windows) {
            const gles3_parts = [_][]const u8{ angle_lib_dir_path, gles3_lib_name };
            const gles3_lib_full_path = std.mem.concat(allocator, u8, &gles3_parts) catch unreachable;
            b.installBinFile(gles3_lib_full_path, gles3_lib_name);
        }
        // GLFW on Linux is looking for versioned .so...
        if (target.result.os.tag == .linux) {
            const egl_link_parts = [_][]const u8{ angle_lib_dir_path, egl_lib_link_name };
            const egl_link_full_path = std.mem.concat(allocator, u8, &egl_link_parts) catch unreachable;
            b.installBinFile(egl_link_full_path, egl_lib_link_name);
            const gles_link_parts = [_][]const u8{ angle_lib_dir_path, gles_lib_link_name };
            const gles_link_full_path = std.mem.concat(allocator, u8, &gles_link_parts) catch unreachable;
            b.installBinFile(gles_link_full_path, gles_lib_link_name);
        }
    }

    b.installArtifact(angle_lib);

    // GLFW
    const glfw = b.dependency("glfw", .{
        .target = target,
        .optimize = optimize,
        // Additional options here
        .native = true, // we use our own GL(ES) headers from Angle
        .gles = true,
        // .metal = true,
    });

    const glfw_lib = glfw.artifact("glfw");

    // the GLFW zig package does not link with QuartzCore, why?
    if (target.result.os.tag == .macos) {
        glfw_lib.linkFramework("QuartzCore");
    }
    // on Windows, GLFW is looking for libGLESv3.dll...
    // ok so first we need to copy v2 in v3
    // then we need to add the path
    if (target.result.os.tag == .windows) {
        glfw_lib.addLibraryPath(b.path(angle_lib_dir_path));
    }

    // dcimgui
    const dcimgui_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });
    const dcimgui_lib = b.addLibrary(.{
        .name = "dcimgui",
        .linkage = .static,
        .root_module = dcimgui_mod,
        .use_lld = if (target.result.os.tag == .windows) true else false,
        .use_llvm = if (target.result.os.tag == .windows) true else false,
    });
    dcimgui_mod.addCMacro("IMGUI_USER_CONFIG", "\"imgui_user_config.h\"");
    // dcimgui_mod.addCMacro("IMGUI_IMPL_OPENGL_DEBUG", "1");
    dcimgui_mod.addIncludePath(b.path("libs/dcimgui"));
    dcimgui_mod.addCSourceFiles(.{
        .files = &.{
            "libs/dcimgui/dcimgui.cpp",
            // "libs/dcimgui/dcimgui_impl_sdl3.cpp",
            "libs/dcimgui/dcimgui_impl_glfw.cpp",
            "libs/dcimgui/dcimgui_impl_opengl3.cpp",
            "libs/dcimgui/imgui_demo.cpp",
            "libs/dcimgui/imgui_draw.cpp",
            "libs/dcimgui/imgui_tables.cpp",
            "libs/dcimgui/imgui_widgets.cpp",
            "libs/dcimgui/imgui.cpp",
            // "libs/dcimgui/imgui_impl_sdl3.cpp",
            "libs/dcimgui/imgui_impl_glfw.cpp",
            "libs/dcimgui/imgui_impl_opengl3.cpp",
        },
    });
    dcimgui_lib.addLibraryPath(b.path(angle_lib_dir_path));
    // we need to link with Angle to get the GL(ES) headers
    dcimgui_lib.linkLibrary(angle_lib);
    dcimgui_lib.linkLibrary(glfw_lib);
    dcimgui_lib.linkLibCpp();
    dcimgui_lib.installHeadersDirectory(b.path("libs/dcimgui"), "dcimgui", .{});
    b.installArtifact(dcimgui_lib);

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // on Windows library path does not seem transitive? Probably private?
    // => add it also to our exe module
    if (target.result.os.tag == .windows) {
        exe_mod.addLibraryPath(b.path(angle_lib_dir_path));
    }
    // I don't understand why I need to link on macOS and Linux
    // it's supposed to use dlopen? and it works on Windows?!
    else {
        // exe_mod.addLibraryPath(b.path(angle_lib_dir_path));
        // exe_mod.linkSystemLibrary("GLESv2", .{});
    }
    exe_mod.linkLibrary(angle_lib);
    exe_mod.linkLibrary(glfw_lib);
    exe_mod.linkLibrary(dcimgui_lib);

    // Modules can depend on one another using the `std.Build.Module.addImport` function.
    // This is what allows Zig source code to use `@import("foo")` where 'foo' is not a
    // file path. In this case, we set up `exe_mod` to import `lib_mod`.
    exe_mod.addImport("angle_gles_lib", lib_mod);

    // https://github.com/ziglang/zig/issues/15849
    // rpath magic for GLFW dlopen
    if (target.result.os.tag == .macos) {
        exe_mod.addRPathSpecial("@executable_path/.");
        // would I need the following on macOS??
        // https://stackoverflow.com/questions/78381702/dynamic-linker-in-mac-is-not-reading-rpath
        // exe_mod.addRPathSpecial("@rpath/.");
    } else if (target.result.os.tag == .linux) {
        // objdump -x path/to/executable | grep RPATH
        // readelf -d ./angle_gles
        // chrpath -l angle_gles
        // patchelf --force-rpath --set-rpath '$ORIGIN'/. libEGL.so
        // https://github.com/ghostty-org/ghostty/pull/6706
        exe_mod.addRPathSpecial("$ORIGIN/.");
    }

    // Now, we will create a static library based on the module we created above.
    // This creates a `std.Build.Step.Compile`, which is the build step responsible
    // for actually invoking the compiler.
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "angle_gles",
        .root_module = lib_mod,
        .use_lld = if (target.result.os.tag == .windows) true else false,
        .use_llvm = if (target.result.os.tag == .windows) true else false,
    });

    // This declares intent for the library to be installed into the standard
    // location when the user invokes the "install" step (the default step when
    // running `zig build`).
    b.installArtifact(lib);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "angle_gles",
        .root_module = exe_mod,
        .use_lld = if (target.result.os.tag == .windows) true else false,
        .use_llvm = if (target.result.os.tag == .windows) true else false,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const clean_step = b.step("clean", "Clean up");

    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    if (@import("builtin").os.tag != .windows) {
        clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
    }

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
