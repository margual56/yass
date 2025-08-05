# Graphics Library

A Zig graphics library that abstracts SDL3 and OpenGL, providing a simple and customizable interface for creating graphical applications.

Many many thanks to the [https://github.com/castholm/SDL](https://github.com/castholm/SDL) project, which is the backbone of this library. It provides the bindings for SDL.

## Overview

This library wraps SDL3 and OpenGL functionality into a single `Graphics` struct that handles:
- Window creation and management
- OpenGL context setup
- Event handling
- Render loop management
- Shader utilities

## Basic Usage
Requires Zig 0.14.1 or 0.15.0-dev (master).

`zig fetch --save git+https://github.com/margual56/yass.git`

```zig
const std = @import("std");
const yass = @import("yass");

pub fn main() !void {
    // Initialize graphics with configuration
    const config = yass.GraphicsConfig{
        .title = "My Application",
        .width = 800,
        .height = 600,
        .resizable = true,
        .vsync = true,
    };

    var gfx = try yass.Graphics.init(config);
    defer gfx.deinit();

    // Run with default rendering (animated colors)
    try gfx.run();
}
```

Check the [castholm/SDL](https://github.com/castholm/SDL) project for more information on SDL3.

## Custom Rendering

To implement custom rendering, provide a render callback:

```zig
fn myRender(gfx: *yass.Graphics, delta_time: f32) !void {
    // Clear the screen
    gfx.clear(0.0, 0.0, 0.0, 1.0);

    // Your OpenGL rendering code here
    // You have full access to OpenGL through the library

    // The library automatically swaps buffers after this function
}

// In main:
gfx.setRenderFn(myRender);
```

## Event Handling

Handle events by providing an event handler callback:

```zig
fn myEventHandler(gfx: *yass.Graphics, event: yass.Event) !bool {
    switch (event) {
        .key_down => |key| {
            if (key.scancode == yass.SCANCODE_ESCAPE) {
                gfx.quit();
                return true; // Event handled
            }
        },
        .mouse_button_down => |button| {
            std.debug.print("Mouse clicked at ({}, {})\n", .{ button.x, button.y });
        },
        else => {},
    }
    return false; // Let default handler process
}

// In main:
gfx.setEventHandler(myEventHandler);
```

## Event Types

The library provides a unified `Event` type that abstracts SDL events:

- `quit` - Window close requested
- `key_down` - Keyboard key pressed
- `key_up` - Keyboard key released
- `mouse_motion` - Mouse moved
- `mouse_button_down` - Mouse button pressed
- `mouse_button_up` - Mouse button released
- `window_resized` - Window size changed

## Storing Application State

Use the `userdata` field to store your application state:

```zig
const AppState = struct {
    score: u32 = 0,
    player_pos: [2]f32 = .{ 0, 0 },
};

var state = AppState{};
gfx.userdata = &state;

// Access in callbacks:
fn render(gfx: *graphics.Graphics, delta_time: f32) !void {
    const state = @as(*AppState, @ptrCast(@alignCast(gfx.userdata.?)));
    // Use state...
}
```

## Graphics API

### Window Management
- `getWindowSize()` - Get current window size in pixels
- `setWindowTitle(title)` - Change window title
- `setWindowSize(width, height)` - Resize window

### Rendering
- `clear(r, g, b, a)` - Clear screen with color
- `setViewport(x, y, width, height)` - Set rendering viewport
- `setDepthTest(enabled)` - Enable/disable depth testing
- `setBlending(enabled)` - Enable/disable alpha blending
- `setWireframe(enabled)` - Enable/disable wireframe mode

### Shader Management
- `createShaderProgram(vertex_src, fragment_src)` - Create shader program
- `useProgram(program)` - Activate shader program
- `getUniformLocation(program, name)` - Get uniform location
- `setUniform*()` - Set uniform values

### Buffer Management
- `createVertexArray()` - Create VAO
- `createBuffer()` - Create VBO/EBO
- `bindVertexArray(vao)` - Bind VAO
- `bindBuffer(target, buffer)` - Bind buffer
- `bufferData(target, size, data, usage)` - Upload buffer data

### Drawing
- `drawArrays(mode, first, count)` - Draw vertices
- `drawElements(mode, count, type, indices)` - Draw indexed vertices

### Input
- `getMousePosition()` - Get current mouse position
- `isKeyPressed(scancode)` - Check if key is pressed

### Timing
- `getElapsedTime()` - Time since initialization
- `getFPS()` - Current frames per second

## OpenGL Constants

The library exports commonly used OpenGL constants:

```zig
// Drawing modes
graphics.GL_TRIANGLES
graphics.GL_LINES
graphics.GL_POINTS

// Buffer types
graphics.GL_ARRAY_BUFFER
graphics.GL_ELEMENT_ARRAY_BUFFER

// Usage hints
graphics.GL_STATIC_DRAW
graphics.GL_DYNAMIC_DRAW

// And many more...
```

## SDL Constants

Key scancodes and mouse buttons are also exported:

```zig
graphics.SCANCODE_SPACE
graphics.SCANCODE_ESCAPE
graphics.BUTTON_LEFT
graphics.BUTTON_RIGHT
// etc.
```

## Complete Example

See the `examples/` directory for complete working examples:
- `simple_window.zig` - Basic window with custom rendering
- `game_of_life.zig` - Conway's Game of Life implementation

## Error Handling

All SDL operations return error unions. The library uses the `errify` utility to convert SDL error codes to Zig errors. OpenGL errors should be checked manually when needed.

## Dependencies

This library requires:
- SDL3
- OpenGL 3.3+ Core Profile
- zig-opengl bindings

## Architecture

The library is structured as follows:
- `graphics.zig` - Main Graphics struct and implementation
- `utils.zig` - Utility functions (shader compilation, error handling)
- `lib.zig` - Public API exports
