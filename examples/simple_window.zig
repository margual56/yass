const std = @import("std");
const yass = @import("yass");
const gl = @import("gl");

// Custom application state
const AppState = struct {
    color_r: f32 = 0.0,
    color_g: f32 = 0.0,
    color_b: f32 = 0.0,
    time: f32 = 0.0,
};

// Custom render function
fn render(gfx: *yass.Graphics, delta_time: f32) !void {
    // Get our app state (stored in userdata for this example)
    const state = @as(*AppState, @ptrCast(@alignCast(gfx.userdata.?)));

    // Update time
    state.time += delta_time;

    // Animate colors
    state.color_r = 0.5 + 0.5 * @sin(state.time);
    state.color_g = 0.5 + 0.5 * @sin(state.time + 2.0);
    state.color_b = 0.5 + 0.5 * @sin(state.time + 4.0);

    // Clear the screen with animated color
    gfx.clear(state.color_r * 0.2, state.color_g * 0.2, state.color_b * 0.2, 1.0);

    // You can add custom OpenGL rendering here
    // For this example, we'll just clear the screen
}

// Custom event handler
fn handleEvent(gfx: *yass.Graphics, event: yass.Event) !bool {
    switch (event) {
        .quit => {
            std.debug.print("Quit requested\n", .{});
            return false; // Let default handler process it
        },
        .key_down => |key| {
            std.debug.print("Key pressed: scancode={}, keycode={}\n", .{ key.scancode, key.keycode });

            // ESC to quit
            if (key.scancode == yass.SCANCODE_ESCAPE) {
                gfx.quit();
                return true; // We handled it
            }

            // Space to reset colors
            if (key.scancode == yass.SCANCODE_SPACE) {
                const state = @as(*AppState, @ptrCast(@alignCast(gfx.userdata.?)));
                state.time = 0.0;
                return true;
            }
        },
        .key_up => |key| {
            std.debug.print("Key released: scancode={}\n", .{key.scancode});
        },
        .mouse_motion => |motion| {
            // Uncomment to see mouse motion events
            // std.debug.print("Mouse moved to ({}, {})\n", .{ motion.x, motion.y });
            _ = motion;
        },
        .mouse_button_down => |button| {
            std.debug.print("Mouse button {} pressed at ({}, {})\n", .{ button.button, button.x, button.y });
        },
        .mouse_button_up => |button| {
            std.debug.print("Mouse button {} released at ({}, {})\n", .{ button.button, button.x, button.y });
        },
        .window_resized => |size| {
            std.debug.print("Window resized to {}x{}\n", .{ size.width, size.height });
        },
    }

    return false; // Let default handler process unhandled events
}

pub fn main() !void {
    // Initialize with custom configuration
    const config = yass.GraphicsConfig{
        .title = "Simple Graphics Example",
        .width = 1024,
        .height = 768,
        .resizable = true,
        .vsync = true,
    };

    var gfx = try yass.Graphics.init(config);
    defer gfx.deinit();

    // Create app state
    var app_state = AppState{};

    // Store app state pointer in graphics
    gfx.userdata = &app_state;

    // Set our custom render function
    gfx.setRenderFn(render);

    // Set our custom event handler
    gfx.setEventHandler(handleEvent);

    std.debug.print("Window created! Press ESC to quit, SPACE to reset colors.\n", .{});

    // Run the main loop
    try gfx.run();

    std.debug.print("Goodbye!\n", .{});
}
