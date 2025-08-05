pub const Graphics = @import("./graphics.zig").Graphics;
pub const GraphicsConfig = @import("./graphics.zig").GraphicsConfig;
pub const Event = @import("./graphics.zig").Event;
pub const RenderFn = @import("./graphics.zig").RenderFn;
pub const EventHandlerFn = @import("./graphics.zig").EventHandlerFn;

// Shader utilities
pub const createShaderProgram = @import("./utils.zig").createShaderProgram;
pub const compileShader = @import("./utils.zig").compileShader;
pub const errify = @import("./utils.zig").errify;

// Re-export commonly used types and constants
const std = @import("std");
const gl = @import("gl");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
});

// SDL key codes and scancodes for convenience
pub const Scancode = c.SDL_Scancode;
pub const Keycode = c.SDL_Keycode;
pub const Keymod = c.SDL_Keymod;

// Common SDL constants
pub const SCANCODE_ESCAPE = c.SDL_SCANCODE_ESCAPE;
pub const SCANCODE_SPACE = c.SDL_SCANCODE_SPACE;
pub const SCANCODE_RETURN = c.SDL_SCANCODE_RETURN;
pub const SCANCODE_W = c.SDL_SCANCODE_W;
pub const SCANCODE_A = c.SDL_SCANCODE_A;
pub const SCANCODE_S = c.SDL_SCANCODE_S;
pub const SCANCODE_D = c.SDL_SCANCODE_D;
pub const SCANCODE_UP = c.SDL_SCANCODE_UP;
pub const SCANCODE_DOWN = c.SDL_SCANCODE_DOWN;
pub const SCANCODE_LEFT = c.SDL_SCANCODE_LEFT;
pub const SCANCODE_RIGHT = c.SDL_SCANCODE_RIGHT;
pub const SCANCODE_C = c.SDL_SCANCODE_C;
pub const SCANCODE_R = c.SDL_SCANCODE_R;

// Mouse button constants
pub const BUTTON_LEFT = c.SDL_BUTTON_LEFT;
pub const BUTTON_MIDDLE = c.SDL_BUTTON_MIDDLE;
pub const BUTTON_RIGHT = c.SDL_BUTTON_RIGHT;

// Key modifiers
pub const KMOD_NONE = c.SDL_KMOD_NONE;
pub const KMOD_LSHIFT = c.SDL_KMOD_LSHIFT;
pub const KMOD_RSHIFT = c.SDL_KMOD_RSHIFT;
pub const KMOD_LCTRL = c.SDL_KMOD_LCTRL;
pub const KMOD_RCTRL = c.SDL_KMOD_RCTRL;
pub const KMOD_LALT = c.SDL_KMOD_LALT;
pub const KMOD_RALT = c.SDL_KMOD_RALT;
pub const KMOD_SHIFT = c.SDL_KMOD_SHIFT;
pub const KMOD_CTRL = c.SDL_KMOD_CTRL;
pub const KMOD_ALT = c.SDL_KMOD_ALT;

// Logging scopes for library users
pub const sdl_log = std.log.scoped(.sdl);
pub const gl_log = std.log.scoped(.gl);

// Error handling
pub fn getSdlError() [*c]const u8 {
    return c.SDL_GetError();
}

// Standard options for the library
pub const std_options: std.Options = .{ .log_level = .debug };

// OpenGL constants for convenience
// Drawing modes
pub const GL_POINTS = gl.POINTS;
pub const GL_LINES = gl.LINES;
pub const GL_LINE_LOOP = gl.LINE_LOOP;
pub const GL_LINE_STRIP = gl.LINE_STRIP;
pub const GL_TRIANGLES = gl.TRIANGLES;
pub const GL_TRIANGLE_STRIP = gl.TRIANGLE_STRIP;
pub const GL_TRIANGLE_FAN = gl.TRIANGLE_FAN;

// Buffer targets
pub const GL_ARRAY_BUFFER = gl.ARRAY_BUFFER;
pub const GL_ELEMENT_ARRAY_BUFFER = gl.ELEMENT_ARRAY_BUFFER;

// Usage hints
pub const GL_STATIC_DRAW = gl.STATIC_DRAW;
pub const GL_DYNAMIC_DRAW = gl.DYNAMIC_DRAW;
pub const GL_STREAM_DRAW = gl.STREAM_DRAW;

// Data types
pub const GL_BYTE = gl.BYTE;
pub const GL_UNSIGNED_BYTE = gl.UNSIGNED_BYTE;
pub const GL_SHORT = gl.SHORT;
pub const GL_UNSIGNED_SHORT = gl.UNSIGNED_SHORT;
pub const GL_INT = gl.INT;
pub const GL_UNSIGNED_INT = gl.UNSIGNED_INT;
pub const GL_FLOAT = gl.FLOAT;
pub const GL_DOUBLE = gl.DOUBLE;

// Boolean values
pub const GL_TRUE = gl.TRUE;
pub const GL_FALSE = gl.FALSE;

// Clear bits
pub const GL_COLOR_BUFFER_BIT = gl.COLOR_BUFFER_BIT;
pub const GL_DEPTH_BUFFER_BIT = gl.DEPTH_BUFFER_BIT;
pub const GL_STENCIL_BUFFER_BIT = gl.STENCIL_BUFFER_BIT;

// Blend functions
pub const GL_ZERO = gl.ZERO;
pub const GL_ONE = gl.ONE;
pub const GL_SRC_COLOR = gl.SRC_COLOR;
pub const GL_ONE_MINUS_SRC_COLOR = gl.ONE_MINUS_SRC_COLOR;
pub const GL_SRC_ALPHA = gl.SRC_ALPHA;
pub const GL_ONE_MINUS_SRC_ALPHA = gl.ONE_MINUS_SRC_ALPHA;
pub const GL_DST_ALPHA = gl.DST_ALPHA;
pub const GL_ONE_MINUS_DST_ALPHA = gl.ONE_MINUS_DST_ALPHA;
pub const GL_DST_COLOR = gl.DST_COLOR;
pub const GL_ONE_MINUS_DST_COLOR = gl.ONE_MINUS_DST_COLOR;

// Depth functions
pub const GL_NEVER = gl.NEVER;
pub const GL_LESS = gl.LESS;
pub const GL_EQUAL = gl.EQUAL;
pub const GL_LEQUAL = gl.LEQUAL;
pub const GL_GREATER = gl.GREATER;
pub const GL_NOTEQUAL = gl.NOTEQUAL;
pub const GL_GEQUAL = gl.GEQUAL;
pub const GL_ALWAYS = gl.ALWAYS;

// Polygon modes
pub const GL_FRONT = gl.FRONT;
pub const GL_BACK = gl.BACK;
pub const GL_FRONT_AND_BACK = gl.FRONT_AND_BACK;
pub const GL_FILL = gl.FILL;
pub const GL_LINE = gl.LINE;
pub const GL_POINT = gl.POINT;

// Enable/Disable capabilities
pub const GL_DEPTH_TEST = gl.DEPTH_TEST;
pub const GL_BLEND = gl.BLEND;
pub const GL_CULL_FACE = gl.CULL_FACE;
pub const GL_SCISSOR_TEST = gl.SCISSOR_TEST;

// Shader types
pub const GL_VERTEX_SHADER = gl.VERTEX_SHADER;
pub const GL_FRAGMENT_SHADER = gl.FRAGMENT_SHADER;
pub const GL_GEOMETRY_SHADER = gl.GEOMETRY_SHADER;

// Shader status
pub const GL_COMPILE_STATUS = gl.COMPILE_STATUS;
pub const GL_LINK_STATUS = gl.LINK_STATUS;
