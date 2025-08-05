const std = @import("std");
const gl = @import("gl");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
});

const errify = @import("./utils.zig").errify;
const createShaderProgram = @import("./utils.zig").createShaderProgram;

pub const std_options: std.Options = .{ .log_level = .debug };

const sdl_log = std.log.scoped(.sdl);
const gl_log = std.log.scoped(.gl);

/// Configuration for initializing the graphics system
pub const GraphicsConfig = struct {
    title: [:0]const u8 = "Graphics Window",
    width: i32 = 800,
    height: i32 = 600,
    resizable: bool = true,
    vsync: bool = true,
    gl_major_version: i32 = 3,
    gl_minor_version: i32 = 3,
};

/// Event types that can be handled by the application
pub const Event = union(enum) {
    quit,
    key_down: struct {
        scancode: c.SDL_Scancode,
        keycode: c.SDL_Keycode,
        modifiers: c.SDL_Keymod,
    },
    key_up: struct {
        scancode: c.SDL_Scancode,
        keycode: c.SDL_Keycode,
        modifiers: c.SDL_Keymod,
    },
    mouse_motion: struct {
        x: f32,
        y: f32,
        xrel: f32,
        yrel: f32,
        state: u32,
    },
    mouse_button_down: struct {
        button: u8,
        x: f32,
        y: f32,
        clicks: u8,
    },
    mouse_button_up: struct {
        button: u8,
        x: f32,
        y: f32,
        clicks: u8,
    },
    window_resized: struct {
        width: i32,
        height: i32,
    },
};

/// Render callback function type
pub const RenderFn = *const fn (graphics: *Graphics, delta_time: f32) anyerror!void;

/// Event handler callback function type
pub const EventHandlerFn = *const fn (graphics: *Graphics, event: Event) anyerror!bool;

/// Main graphics interface that abstracts SDL and OpenGL
pub const Graphics = struct {
    window: *c.SDL_Window,
    gl_context: c.SDL_GLContext,
    gl_procs: gl.ProcTable,
    config: GraphicsConfig,

    // Timing
    start_time: std.time.Timer,
    last_frame_time: u64,

    // Default shader program
    default_program: c_uint,
    default_vao: c_uint,
    default_vbo: c_uint,
    time_uniform: c_int,
    resolution_uniform: c_int,

    // User callbacks
    render_fn: ?RenderFn = null,
    event_handler: ?EventHandlerFn = null,

    // User data
    userdata: ?*anyopaque = null,

    // State
    should_quit: bool = false,

    const Self = @This();

    /// Initialize the graphics system with the given configuration
    pub fn init(config: GraphicsConfig) !Self {
        // Initialize SDL video subsystem
        try errify(c.SDL_Init(c.SDL_INIT_VIDEO));
        errdefer c.SDL_Quit();

        // Set OpenGL context attributes
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, config.gl_major_version));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, config.gl_minor_version));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE));
        try errify(c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, c.SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG));

        // Create window flags
        var window_flags: u64 = c.SDL_WINDOW_OPENGL;
        if (config.resizable) {
            window_flags |= c.SDL_WINDOW_RESIZABLE;
        }

        // Create the window
        const window = try errify(c.SDL_CreateWindow(config.title.ptr, @intCast(config.width), @intCast(config.height), window_flags));
        errdefer c.SDL_DestroyWindow(window);

        // Create OpenGL context
        const gl_context = try errify(c.SDL_GL_CreateContext(window));
        errdefer errify(c.SDL_GL_DestroyContext(gl_context)) catch {};

        // Make context current before loading GL functions
        try errify(c.SDL_GL_MakeCurrent(window, gl_context));

        // Set vsync
        if (config.vsync) {
            _ = c.SDL_GL_SetSwapInterval(1);
        }

        // Load OpenGL function pointers
        // Create timer first
        var timer = try std.time.Timer.start();

        var self = Self{
            .window = window,
            .gl_context = gl_context,
            .gl_procs = undefined,
            .config = config,
            .start_time = timer,
            .last_frame_time = timer.read(),
            .default_program = 0,
            .default_vao = 0,
            .default_vbo = 0,
            .time_uniform = 0,
            .resolution_uniform = 0,
        };

        // Initialize OpenGL function pointers
        const gl_loader = struct {
            fn load(name: [*:0]const u8) ?*anyopaque {
                return @as(?*anyopaque, @ptrCast(@constCast(c.SDL_GL_GetProcAddress(name))));
            }
        }.load;

        if (!self.gl_procs.init(gl_loader)) {
            return error.GlInitFailed;
        }
        gl.makeProcTableCurrent(&self.gl_procs);

        // Verify OpenGL is working
        const version = gl.GetString(gl.VERSION);
        if (version == null) {
            return error.GlInitFailed;
        }
        gl_log.info("OpenGL version: {?s}", .{version});

        // Create default shader program for basic rendering
        const default_program = try createDefaultShaderProgram();
        errdefer gl.DeleteProgram(default_program);

        // Create default vertex data (fullscreen quad)
        var default_vao: c_uint = undefined;
        var default_vbo: c_uint = undefined;
        gl.GenVertexArrays(1, @as([*]c_uint, @ptrCast(&default_vao)));
        errdefer gl.DeleteVertexArrays(1, @as([*]c_uint, @ptrCast(&default_vao)));
        gl.GenBuffers(1, @as([*]c_uint, @ptrCast(&default_vbo)));
        errdefer gl.DeleteBuffers(1, @as([*]c_uint, @ptrCast(&default_vbo)));

        gl.BindVertexArray(default_vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, default_vbo);

        const vertices = [_]f32{ -1, -1, 1, -1, -1, 1, 1, 1, 1, -1, -1, 1 };
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);
        gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(0);

        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        gl.BindVertexArray(0);

        // Update struct fields
        self.default_program = default_program;
        self.default_vao = default_vao;
        self.default_vbo = default_vbo;
        self.time_uniform = gl.GetUniformLocation(default_program, "u_Time");
        self.resolution_uniform = gl.GetUniformLocation(default_program, "u_Resolution");

        return self;
    }

    /// Set the render callback function
    pub fn setRenderFn(self: *Self, render_fn: RenderFn) void {
        self.render_fn = render_fn;
    }

    /// Set the event handler callback function
    pub fn setEventHandler(self: *Self, handler: EventHandlerFn) void {
        self.event_handler = handler;
    }

    /// Run the main loop
    pub fn run(self: *Self) !void {
        while (!self.should_quit) {
            // Process events
            try self.processEvents();

            // Calculate delta time
            const current_time = self.start_time.read();
            const delta_time = @as(f32, @floatFromInt(current_time - self.last_frame_time)) / std.time.ns_per_s;
            self.last_frame_time = current_time;

            // Render
            try self.render(delta_time);
        }
    }

    /// Process SDL events
    pub fn processEvents(self: *Self) !void {
        var sdl_event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&sdl_event)) {
            const event = try self.translateEvent(&sdl_event);

            if (event) |e| {
                var handled = false;

                // Let user handler process the event first
                if (self.event_handler) |handler| {
                    handled = try handler(self, e);
                }

                // Default handling for quit event
                if (!handled and e == .quit) {
                    self.should_quit = true;
                }
            }
        }
    }

    /// Translate SDL event to our Event type
    fn translateEvent(self: *Self, sdl_event: *c.SDL_Event) !?Event {
        _ = self;

        switch (sdl_event.type) {
            c.SDL_EVENT_QUIT => return Event.quit,

            c.SDL_EVENT_KEY_DOWN => return Event{ .key_down = .{
                .scancode = sdl_event.key.scancode,
                .keycode = sdl_event.key.key,
                .modifiers = sdl_event.key.mod,
            } },

            c.SDL_EVENT_KEY_UP => return Event{ .key_up = .{
                .scancode = sdl_event.key.scancode,
                .keycode = sdl_event.key.key,
                .modifiers = sdl_event.key.mod,
            } },

            c.SDL_EVENT_MOUSE_MOTION => return Event{ .mouse_motion = .{
                .x = sdl_event.motion.x,
                .y = sdl_event.motion.y,
                .xrel = sdl_event.motion.xrel,
                .yrel = sdl_event.motion.yrel,
                .state = sdl_event.motion.state,
            } },

            c.SDL_EVENT_MOUSE_BUTTON_DOWN => return Event{ .mouse_button_down = .{
                .button = sdl_event.button.button,
                .x = sdl_event.button.x,
                .y = sdl_event.button.y,
                .clicks = sdl_event.button.clicks,
            } },

            c.SDL_EVENT_MOUSE_BUTTON_UP => return Event{ .mouse_button_up = .{
                .button = sdl_event.button.button,
                .x = sdl_event.button.x,
                .y = sdl_event.button.y,
                .clicks = sdl_event.button.clicks,
            } },

            c.SDL_EVENT_WINDOW_RESIZED => return Event{ .window_resized = .{
                .width = sdl_event.window.data1,
                .height = sdl_event.window.data2,
            } },

            else => return null,
        }
    }

    /// Render a frame
    fn render(self: *Self, delta_time: f32) !void {
        // Always ensure GL proc table is current before rendering
        gl.makeProcTableCurrent(&self.gl_procs);

        if (self.render_fn) |render_fn| {
            // Use custom render function
            try render_fn(self, delta_time);
        } else {
            // Use default rendering
            try self.defaultRender(delta_time);
        }

        // Swap buffers
        try errify(c.SDL_GL_SwapWindow(self.window));
    }

    /// Swap the front and back buffers
    pub fn swapBuffers(self: *Self) !void {
        try errify(c.SDL_GL_SwapWindow(self.window));
    }

    /// Default render function (animated color)
    fn defaultRender(self: *Self, delta_time: f32) !void {
        _ = delta_time;

        // Ensure OpenGL context is current
        const current_context = c.SDL_GL_GetCurrentContext();
        if (current_context != self.gl_context) {
            gl_log.warn("OpenGL context not current, making it current...", .{});
            try errify(c.SDL_GL_MakeCurrent(self.window, self.gl_context));
        }

        // Ensure GL proc table is current
        gl.makeProcTableCurrent(&self.gl_procs);

        // Clear the screen
        gl.ClearColor(0.0, 0.0, 0.0, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        // Use default shader program
        gl.UseProgram(self.default_program);

        // Update uniforms
        const size = try self.getWindowSize();
        gl.Viewport(0, 0, size.width, size.height);

        if (self.resolution_uniform >= 0) {
            gl.Uniform2f(self.resolution_uniform, @floatFromInt(size.width), @floatFromInt(size.height));
        }

        const elapsed_seconds = @as(f32, @floatFromInt(self.start_time.read())) / std.time.ns_per_s;
        if (self.time_uniform >= 0) {
            gl.Uniform1f(self.time_uniform, elapsed_seconds);
        }

        // Draw fullscreen quad
        gl.BindVertexArray(self.default_vao);
        gl.DrawArrays(gl.TRIANGLES, 0, 6);
        gl.BindVertexArray(0);
        gl.UseProgram(0);
    }

    /// Get the current window size in pixels
    pub fn getWindowSize(self: *Self) !struct { width: i32, height: i32 } {
        var width: c_int = undefined;
        var height: c_int = undefined;
        try errify(c.SDL_GetWindowSizeInPixels(self.window, &width, &height));
        return .{ .width = width, .height = height };
    }

    /// Clear the screen with the specified color
    pub fn clear(self: *Self, r: f32, g: f32, b: f32, a: f32) void {
        _ = self;
        gl.ClearColor(r, g, b, a);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    }

    /// Set the viewport
    pub fn setViewport(self: *Self, x: i32, y: i32, width: i32, height: i32) void {
        _ = self;
        gl.Viewport(x, y, width, height);
    }

    /// Get elapsed time since initialization in seconds
    pub fn getElapsedTime(self: *Self) f32 {
        return @as(f32, @floatFromInt(self.start_time.read())) / std.time.ns_per_s;
    }

    /// Request to quit the application
    pub fn quit(self: *Self) void {
        self.should_quit = true;
    }

    /// Enable or disable depth testing
    pub fn setDepthTest(self: *Self, enabled: bool) void {
        _ = self;
        if (enabled) {
            gl.Enable(gl.DEPTH_TEST);
        } else {
            gl.Disable(gl.DEPTH_TEST);
        }
    }

    /// Set the depth function
    pub fn setDepthFunc(self: *Self, func: c_uint) void {
        _ = self;
        gl.DepthFunc(func);
    }

    /// Enable or disable blending
    pub fn setBlending(self: *Self, enabled: bool) void {
        _ = self;
        if (enabled) {
            gl.Enable(gl.BLEND);
        } else {
            gl.Disable(gl.BLEND);
        }
    }

    /// Set the blend function
    pub fn setBlendFunc(self: *Self, src: c_uint, dst: c_uint) void {
        _ = self;
        gl.BlendFunc(src, dst);
    }

    /// Enable or disable wireframe mode
    pub fn setWireframe(self: *Self, enabled: bool) void {
        _ = self;
        gl.PolygonMode(gl.FRONT_AND_BACK, if (enabled) gl.LINE else gl.FILL);
    }

    /// Set the line width
    pub fn setLineWidth(self: *Self, width: f32) void {
        _ = self;
        gl.LineWidth(width);
    }

    /// Set the point size
    pub fn setPointSize(self: *Self, size: f32) void {
        _ = self;
        gl.PointSize(size);
    }

    /// Use a shader program
    pub fn useProgram(self: *Self, program: c_uint) void {
        _ = self;
        gl.UseProgram(program);
    }

    /// Get a uniform location from a shader program
    pub fn getUniformLocation(self: *Self, program: c_uint, name: [*c]const u8) c_int {
        _ = self;
        return gl.GetUniformLocation(program, name);
    }

    /// Set a float uniform
    pub fn setUniform1f(self: *Self, location: c_int, value: f32) void {
        _ = self;
        gl.Uniform1f(location, value);
    }

    /// Set a vec2 uniform
    pub fn setUniform2f(self: *Self, location: c_int, x: f32, y: f32) void {
        _ = self;
        gl.Uniform2f(location, x, y);
    }

    /// Set a vec3 uniform
    pub fn setUniform3f(self: *Self, location: c_int, x: f32, y: f32, z: f32) void {
        _ = self;
        gl.Uniform3f(location, x, y, z);
    }

    /// Set a vec4 uniform
    pub fn setUniform4f(self: *Self, location: c_int, x: f32, y: f32, z: f32, w: f32) void {
        _ = self;
        gl.Uniform4f(location, x, y, z, w);
    }

    /// Set a matrix4 uniform
    pub fn setUniformMatrix4fv(self: *Self, location: c_int, transpose: bool, matrix: *const [16]f32) void {
        _ = self;
        gl.UniformMatrix4fv(location, 1, if (transpose) gl.TRUE else gl.FALSE, matrix);
    }

    /// Create a vertex array object
    pub fn createVertexArray(self: *Self) !c_uint {
        _ = self;
        var vao: c_uint = undefined;
        gl.GenVertexArrays(1, @as([*]c_uint, @ptrCast(&vao)));
        return vao;
    }

    /// Create a buffer object
    pub fn createBuffer(self: *Self) !c_uint {
        _ = self;
        var buffer: c_uint = undefined;
        gl.GenBuffers(1, @as([*]c_uint, @ptrCast(&buffer)));
        return buffer;
    }

    /// Bind a vertex array object
    pub fn bindVertexArray(self: *Self, vao: c_uint) void {
        _ = self;
        gl.BindVertexArray(vao);
    }

    /// Bind a buffer
    pub fn bindBuffer(self: *Self, target: c_uint, buffer: c_uint) void {
        _ = self;
        gl.BindBuffer(target, buffer);
    }

    /// Upload buffer data
    pub fn bufferData(self: *Self, target: c_uint, size: isize, data: ?*const anyopaque, usage: c_uint) void {
        _ = self;
        gl.BufferData(target, size, data, usage);
    }

    /// Draw arrays
    pub fn drawArrays(self: *Self, mode: c_uint, first: c_int, count: c_int) void {
        _ = self;
        gl.DrawArrays(mode, first, count);
    }

    /// Draw elements
    pub fn drawElements(self: *Self, mode: c_uint, count: c_int, draw_type: c_uint, indices: ?*const anyopaque) void {
        _ = self;
        gl.DrawElements(mode, count, draw_type, indices);
    }

    /// Get the current frames per second
    pub fn getFPS(self: *Self) f32 {
        const current_time = self.start_time.read();
        const delta_ns = current_time - self.last_frame_time;
        if (delta_ns > 0) {
            return std.time.ns_per_s / @as(f32, @floatFromInt(delta_ns));
        }
        return 0.0;
    }

    /// Set the window title
    pub fn setWindowTitle(self: *Self, title: [:0]const u8) !void {
        try errify(c.SDL_SetWindowTitle(self.window, title.ptr));
    }

    /// Set the window size
    pub fn setWindowSize(self: *Self, width: i32, height: i32) !void {
        try errify(c.SDL_SetWindowSize(self.window, width, height));
    }

    /// Get mouse position
    pub fn getMousePosition(self: *Self) struct { x: f32, y: f32 } {
        _ = self;
        var x: f32 = undefined;
        var y: f32 = undefined;
        _ = c.SDL_GetMouseState(&x, &y);
        return .{ .x = x, .y = y };
    }

    /// Check if a key is currently pressed
    pub fn isKeyPressed(self: *Self, scancode: c.SDL_Scancode) bool {
        _ = self;
        const keyboard_state = c.SDL_GetKeyboardState(null);
        return keyboard_state[@intCast(scancode)] != 0;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        gl.DeleteBuffers(1, @as([*]c_uint, @ptrCast(&self.default_vbo)));
        gl.DeleteVertexArrays(1, @as([*]c_uint, @ptrCast(&self.default_vao)));
        gl.DeleteProgram(self.default_program);
        gl.makeProcTableCurrent(null);
        _ = errify(c.SDL_GL_MakeCurrent(self.window, null)) catch {};
        _ = errify(c.SDL_GL_DestroyContext(self.gl_context)) catch {};
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
        self.* = undefined;
    }
};

/// Create the default shader program
fn createDefaultShaderProgram() !c_uint {
    const vertex_shader_source =
        \\#version 330 core
        \\layout (location = 0) in vec2 a_Position;
        \\void main() {
        \\    gl_Position = vec4(a_Position, 0.0, 1.0);
        \\}
    ;
    const fragment_shader_source =
        \\#version 330 core
        \\uniform float u_Time;
        \\uniform vec2 u_Resolution;
        \\out vec4 f_Color;
        \\void main() {
        \\    // Use resolution to prevent uniform from being optimized out
        \\    vec2 uv = gl_FragCoord.xy / u_Resolution;
        \\    float r = 0.5 + 0.5 * cos(u_Time + uv.x);
        \\    float g = 0.5 + 0.5 * cos(u_Time + 2.0 + uv.y);
        \\    float b = 0.5 + 0.5 * cos(u_Time + 4.0);
        \\    f_Color = vec4(r, g, b, 1.0);
        \\}
    ;

    return try createShaderProgram(vertex_shader_source, fragment_shader_source);
}
