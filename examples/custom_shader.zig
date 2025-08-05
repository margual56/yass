const std = @import("std");
const yass = @import("yass");
const gl = @import("gl");

const AppState = struct {
    // Animation state
    rotation: f32 = 0.0,
    time: f32 = 0.0,

    // OpenGL objects
    vao: c_uint = 0,
    vbo: c_uint = 0,
    shader_program: c_uint = 0,

    fn init() !AppState {
        var state = AppState{};

        // Create basic shaders
        const vertex_shader_src =
            \\#version 330 core
            \\layout (location = 0) in vec3 aPos;
            \\uniform float rotation;
            \\
            \\void main() {
            \\    float cosVal = cos(rotation);
            \\    float sinVal = sin(rotation);
            \\    mat2 rotMat = mat2(cosVal, -sinVal, sinVal, cosVal);
            \\    vec2 rotPos = rotMat * aPos.xy;
            \\    gl_Position = vec4(rotPos, aPos.z, 1.0);
            \\}
        ;

        const fragment_shader_src =
            \\#version 330 core
            \\out vec4 FragColor;
            \\
            \\void main() {
            \\    FragColor = vec4(1.0, 0.5, 0.2, 1.0); // Orange color
            \\}
        ;

        // Compile vertex shader
        const vertex_shader = gl.CreateShader(gl.VERTEX_SHADER);
        gl.ShaderSource(vertex_shader, 1, &.{vertex_shader_src.ptr}, null);
        gl.CompileShader(vertex_shader);

        // Check for vertex shader compile errors
        var success: c_int = undefined;
        var info_log: [512:0]u8 = undefined;
        gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &success);
        if (success == 0) {
            gl.GetShaderInfoLog(vertex_shader, info_log.len, null, &info_log);
            std.debug.print("Vertex shader compilation failed: {s}\n", .{std.mem.sliceTo(&info_log, 0)});
            return error.ShaderCompilationFailed;
        }

        // Compile fragment shader
        const fragment_shader = gl.CreateShader(gl.FRAGMENT_SHADER);
        gl.ShaderSource(fragment_shader, 1, &.{fragment_shader_src.ptr}, null);
        gl.CompileShader(fragment_shader);

        // Check for fragment shader compile errors
        gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &success);
        if (success == 0) {
            gl.GetShaderInfoLog(fragment_shader, info_log.len, null, &info_log);
            std.debug.print("Fragment shader compilation failed: {s}\n", .{std.mem.sliceTo(&info_log, 0)});
            gl.DeleteShader(vertex_shader);
            return error.ShaderCompilationFailed;
        }

        // Link shaders
        state.shader_program = gl.CreateProgram();
        gl.AttachShader(state.shader_program, vertex_shader);
        gl.AttachShader(state.shader_program, fragment_shader);
        gl.LinkProgram(state.shader_program);

        // Check for linking errors
        gl.GetProgramiv(state.shader_program, gl.LINK_STATUS, &success);
        if (success == 0) {
            gl.GetProgramInfoLog(state.shader_program, info_log.len, null, &info_log);
            std.debug.print("Shader program linking failed: {s}\n", .{std.mem.sliceTo(&info_log, 0)});
            gl.DeleteShader(vertex_shader);
            gl.DeleteShader(fragment_shader);
            return error.ShaderLinkingFailed;
        }

        // Delete shaders (they're now linked into the program)
        gl.DeleteShader(vertex_shader);
        gl.DeleteShader(fragment_shader);

        // Create vertex data for a triangle
        const vertices = [_]f32{
            // x, y, z
            -0.5, -0.5, 0.0, // Bottom-left
            0.5, -0.5, 0.0, // Bottom-right
            0.0, 0.5, 0.0, // Top
        };

        // Set up VAO/VBO for triangle
        gl.GenVertexArrays(1, @as([*]c_uint, @ptrCast(&state.vao)));
        gl.GenBuffers(1, @as([*]c_uint, @ptrCast(&state.vbo)));

        gl.BindVertexArray(state.vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, state.vbo);
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

        // Position attribute
        gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(0);

        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        gl.BindVertexArray(0);

        return state;
    }

    fn deinit(self: *AppState) void {
        std.debug.print("Deinitializing AppState...\n", .{});

        // Clean up OpenGL objects
        if (self.vbo != 0) {
            gl.DeleteBuffers(1, @as([*]c_uint, @ptrCast(&self.vbo)));
        }

        if (self.vao != 0) {
            gl.DeleteVertexArrays(1, @as([*]c_uint, @ptrCast(&self.vao)));
        }

        if (self.shader_program != 0) {
            gl.DeleteProgram(self.shader_program);
        }

        std.debug.print("AppState deinitialized\n", .{});
    }
};

fn render(gfx: *yass.Graphics, delta_time: f32) !void {
    // Check if userdata is valid
    if (gfx.userdata == null) {
        std.debug.print("Error: userdata is null\n", .{});
        return;
    }

    // Store a local reference to userdata to prevent it from being moved or changed during the function
    const userdata_ptr = gfx.userdata.?;

    // Add more validation of the userdata pointer before casting
    if (@intFromPtr(userdata_ptr) == 0) {
        std.debug.print("Error: userdata pointer is null\n", .{});
        return;
    }

    // Perform safer casting
    const state = @as(*AppState, @ptrCast(@alignCast(userdata_ptr)));

    // Update animation state
    state.time += delta_time;
    state.rotation += delta_time * 0.5;

    // Clear with a dark background
    gfx.clear(0.1, 0.2, 0.3, 1.0);

    // Use our shader program
    gl.UseProgram(state.shader_program);

    // Set the rotation uniform
    const rotation_loc = gl.GetUniformLocation(state.shader_program, "rotation");
    if (rotation_loc != -1) {
        gl.Uniform1f(rotation_loc, state.rotation);
    }

    // Draw the triangle
    gl.BindVertexArray(state.vao);
    gl.DrawArrays(gl.TRIANGLES, 0, 3);
    gl.BindVertexArray(0);

    // Unbind the shader program
    gl.UseProgram(0);
}

fn handleEvent(gfx: *yass.Graphics, event: yass.Event) !bool {
    // Check if userdata is valid
    if (gfx.userdata == null) {
        std.debug.print("Error in event handler: userdata is null\n", .{});
        return false;
    }

    // Store a local reference to userdata to prevent it from being moved or changed
    const userdata_ptr = gfx.userdata.?;

    // Add more validation of the userdata pointer before casting
    if (@intFromPtr(userdata_ptr) == 0) {
        std.debug.print("Error in event handler: userdata pointer is null\n", .{});
        return false;
    }

    const state = @as(*AppState, @ptrCast(@alignCast(userdata_ptr)));

    switch (event) {
        .key_down => |key| {
            switch (key.scancode) {
                yass.SCANCODE_ESCAPE => {
                    std.debug.print("ESC pressed, quitting\n", .{});
                    gfx.quit();
                    return true;
                },
                yass.SCANCODE_SPACE => {
                    // Reset animation
                    std.debug.print("SPACE pressed, resetting animation\n", .{});
                    state.rotation = 0.0;
                    state.time = 0.0;
                    return true;
                },
                yass.SCANCODE_LEFT => {
                    // Rotate counter-clockwise
                    std.debug.print("LEFT pressed, rotating counter-clockwise\n", .{});
                    state.rotation -= std.math.pi / 4.0;
                    return true;
                },
                yass.SCANCODE_RIGHT => {
                    // Rotate clockwise
                    std.debug.print("RIGHT pressed, rotating clockwise\n", .{});
                    state.rotation += std.math.pi / 4.0;
                    return true;
                },
                else => {},
            }
        },
        else => {},
    }

    return false;
}

pub fn main() !void {
    std.debug.print("Simple Graphics Example\n", .{});
    std.debug.print("Controls:\n", .{});
    std.debug.print("  SPACE      - Reset animation\n", .{});
    std.debug.print("  LEFT/RIGHT - Rotate manually\n", .{});
    std.debug.print("  ESC        - Quit\n\n", .{});

    // Initialize graphics
    const config = yass.GraphicsConfig{
        .title = "Simple Graphics Example",
        .width = 800,
        .height = 600,
        .resizable = true,
        .vsync = true,
    };

    std.debug.print("Initializing graphics...\n", .{});
    var gfx = try yass.Graphics.init(config);
    defer gfx.deinit();

    // Report OpenGL context info
    const gl_vendor = gl.GetString(gl.VENDOR);
    const gl_renderer = gl.GetString(gl.RENDERER);
    const gl_version = gl.GetString(gl.VERSION);
    const gl_shading = gl.GetString(gl.SHADING_LANGUAGE_VERSION);

    std.debug.print("OpenGL vendor: {?s}\n", .{gl_vendor});
    std.debug.print("OpenGL renderer: {?s}\n", .{gl_renderer});
    std.debug.print("OpenGL version: {?s}\n", .{gl_version});
    std.debug.print("GLSL version: {?s}\n", .{gl_shading});
    std.debug.print("Graphics initialized\n", .{});

    // Initialize app state
    std.debug.print("Initializing app state...\n", .{});
    var app_state = try AppState.init();
    defer app_state.deinit();
    std.debug.print("App state initialized\n", .{});

    // Set up callbacks
    std.debug.print("Setting up callbacks...\n", .{});
    const app_state_ptr = &app_state;
    std.debug.print("AppState pointer: {*}\n", .{app_state_ptr});
    gfx.userdata = app_state_ptr;
    gfx.setRenderFn(render);
    gfx.setEventHandler(handleEvent);
    std.debug.print("Callbacks set\n", .{});

    // Run the application using the library's built-in run function
    try gfx.run();
    std.debug.print("Application exited\n", .{});
}
