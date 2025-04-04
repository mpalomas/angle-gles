# Zig + Google Angle + OpenGL ES 3.0 boilerplate

Why OpenGL ES 3.0? Motivation:
- OpenGL Desktop versions have different level of support: MacOS stops at 4.1... Windows and Linux get 4.6. Embedded systems don't support it.
- OpenGL ES by default has a similar/worse problem: it is not even supported on MacOS (only iOS?). Different versions depending on vendors/drivers.
- Different versions => different feature set + different GLSL language to support => headache

The goal of this sample is to show how to get and use a valid OpenGL ES 3.0 context with Zig and Google Angle.

Google Angle provides a compliant OpenGL ES 3.0 + GLSL 300 es on ALL 3 major desktop OS.

In addition, OpenGL ES 3.0 is supported on tons of embedded systems (phones) + Raspberry PI 3+...

Requires Zig 0.14+

## Output example

```bash
zig build run
```

Windows output:
```
debug: OpenGL renderer: ANGLE (NVIDIA, NVIDIA RTX A2000 Laptop GPU (0x000025B8) Direct3D11 vs_5_0 ps_5_0, D3D11-32.0.15.6103)
debug: OpenGL ES 3.0.0 (ANGLE 2.1.25165 git hash: bbf92d12266d)
debug: OpenGL ES GLSL ES 3.00 (ANGLE 2.1.25165 git hash: bbf92d12266d)
debug: OpenGL extensions count: 129
... the list of extensions ...
```

MacOS output:
```
debug: OpenGL renderer: ANGLE (Apple, Apple M1 Pro, OpenGL 4.1 Metal - 89.3)
debug: OpenGL ES 3.0.0 (ANGLE 2.1.24801 git hash: 914c97c116e0)
debug: OpenGL ES GLSL ES 3.00 (ANGLE 2.1.24801 git hash: 914c97c116e0)
debug: OpenGL extensions count: 103
... the list of extensions ...
```

Linux output
```
```

[How to use Angle + GLFW](https://discourse.glfw.org/t/how-to-use-angle-glfw/2429/7)

[GLFW + Angle Linux](https://discourse.glfw.org/t/glfw-with-angle-egl-on-linux/2402/4)

[MacOS understanding rpath and friends](https://itwenty.me/posts/01-understanding-rpath/)