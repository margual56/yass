const std = @import("std");
const yass = @import("yass");
const gl = @import("gl");

const GRID_WIDTH = 80;
const GRID_HEIGHT = 60;
const CELL_SIZE = 10;

const GameState = struct {
    grid: [GRID_HEIGHT][GRID_WIDTH]bool,
    next_grid: [GRID_HEIGHT][GRID_WIDTH]bool,
    paused: bool = true,
    update_timer: f32 = 0.0,
    update_interval: f32 = 0.1, // 10 updates per second

    // Shader program for rendering cells
    cell_program: c_uint = 0,
    cell_vao: c_uint = 0,
    cell_vbo: c_uint = 0,
    cell_color_uniform: c_int = 0,
    cell_transform_uniform: c_int = 0,

    fn init() !GameState {
        var state = GameState{
            .grid = std.mem.zeroes([GRID_HEIGHT][GRID_WIDTH]bool),
            .next_grid = std.mem.zeroes([GRID_HEIGHT][GRID_WIDTH]bool),
        };

        // Initialize with a glider pattern
        state.grid[10][10] = true;
        state.grid[11][11] = true;
        state.grid[11][12] = true;
        state.grid[10][12] = true;
        state.grid[9][12] = true;

        // Create shader program for cells
        const vertex_shader =
            \\#version 330 core
            \\layout (location = 0) in vec2 a_Position;
            \\uniform mat4 u_Transform;
            \\void main() {
            \\    gl_Position = u_Transform * vec4(a_Position, 0.0, 1.0);
            \\}
        ;

        const fragment_shader =
            \\#version 330 core
            \\uniform vec3 u_Color;
            \\out vec4 f_Color;
            \\void main() {
            \\    f_Color = vec4(u_Color, 1.0);
            \\}
        ;

        state.cell_program = try yass.createShaderProgram(vertex_shader, fragment_shader);

        // Create a unit square for cells
        gl.GenVertexArrays(1, @as([*]c_uint, @ptrCast(&state.cell_vao)));
        gl.GenBuffers(1, @as([*]c_uint, @ptrCast(&state.cell_vbo)));

        gl.BindVertexArray(state.cell_vao);
        gl.BindBuffer(gl.ARRAY_BUFFER, state.cell_vbo);

        const vertices = [_]f32{ 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1 };
        gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);
        gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * @sizeOf(f32), 0);
        gl.EnableVertexAttribArray(0);

        gl.BindBuffer(gl.ARRAY_BUFFER, 0);
        gl.BindVertexArray(0);

        // Get uniform locations
        state.cell_color_uniform = gl.GetUniformLocation(state.cell_program, "u_Color");
        state.cell_transform_uniform = gl.GetUniformLocation(state.cell_program, "u_Transform");

        return state;
    }

    fn deinit(self: *GameState) void {
        gl.DeleteBuffers(1, @as([*]c_uint, @ptrCast(&self.cell_vbo)));
        gl.DeleteVertexArrays(1, @as([*]c_uint, @ptrCast(&self.cell_vao)));
        gl.DeleteProgram(self.cell_program);
    }

    fn toggleCell(self: *GameState, x: i32, y: i32) void {
        if (x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT) {
            const ux = @as(usize, @intCast(x));
            const uy = @as(usize, @intCast(y));
            self.grid[uy][ux] = !self.grid[uy][ux];
        }
    }

    fn clearGrid(self: *GameState) void {
        self.grid = std.mem.zeroes([GRID_HEIGHT][GRID_WIDTH]bool);
    }

    fn randomize(self: *GameState) void {
        var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
        const random = prng.random();

        for (&self.grid) |*row| {
            for (row) |*cell| {
                cell.* = random.boolean();
            }
        }
    }

    fn countNeighbors(self: *const GameState, x: usize, y: usize) u8 {
        var count: u8 = 0;

        const dirs = [_][2]i32{
            .{ -1, -1 }, .{ 0, -1 }, .{ 1, -1 },
            .{ -1, 0 },  .{ 1, 0 },  .{ -1, 1 },
            .{ 0, 1 },   .{ 1, 1 },
        };

        for (dirs) |dir| {
            const nx = @as(i32, @intCast(x)) + dir[0];
            const ny = @as(i32, @intCast(y)) + dir[1];

            if (nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT) {
                if (self.grid[@as(usize, @intCast(ny))][@as(usize, @intCast(nx))]) {
                    count += 1;
                }
            }
        }

        return count;
    }

    fn update(self: *GameState) void {
        // Apply Conway's Game of Life rules
        for (0..GRID_HEIGHT) |y| {
            for (0..GRID_WIDTH) |x| {
                const neighbors = self.countNeighbors(x, y);
                const alive = self.grid[y][x];

                // Rules:
                // 1. Any live cell with 2-3 neighbors survives
                // 2. Any dead cell with exactly 3 neighbors becomes alive
                // 3. All other cells die or stay dead
                self.next_grid[y][x] = (alive and (neighbors == 2 or neighbors == 3)) or
                    (!alive and neighbors == 3);
            }
        }

        // Swap grids
        std.mem.swap([GRID_HEIGHT][GRID_WIDTH]bool, &self.grid, &self.next_grid);
    }
};

fn render(gfx: *yass.Graphics, delta_time: f32) !void {
    const state = @as(*GameState, @ptrCast(@alignCast(gfx.userdata.?)));

    // Update simulation
    if (!state.paused) {
        state.update_timer += delta_time;
        if (state.update_timer >= state.update_interval) {
            state.update_timer = 0.0;
            state.update();
        }
    }

    // Clear screen
    gfx.clear(0.1, 0.1, 0.1, 1.0);

    // Get window size for projection
    const window_size = try gfx.getWindowSize();
    const aspect = @as(f32, @floatFromInt(window_size.width)) / @as(f32, @floatFromInt(window_size.height));

    // Create orthographic projection matrix
    const grid_aspect = @as(f32, GRID_WIDTH) / @as(f32, GRID_HEIGHT);
    var scale_x: f32 = 2.0 / @as(f32, GRID_WIDTH);
    var scale_y: f32 = 2.0 / @as(f32, GRID_HEIGHT);
    // Invert scale_y to flip the y-axis (screen coordinates have y increasing downward)
    scale_y = -scale_y;

    if (aspect > grid_aspect) {
        scale_x *= grid_aspect / aspect;
    } else {
        scale_y *= aspect / grid_aspect;
    }

    // Use the cell shader
    gl.UseProgram(state.cell_program);
    gl.BindVertexArray(state.cell_vao);

    // Draw cells
    for (0..GRID_HEIGHT) |y| {
        for (0..GRID_WIDTH) |x| {
            if (state.grid[y][x]) {
                // Calculate transform matrix for this cell
                const tx = (@as(f32, @floatFromInt(x)) - @as(f32, GRID_WIDTH) / 2.0) * scale_x;
                const ty = (@as(f32, @floatFromInt(y)) - @as(f32, GRID_HEIGHT) / 2.0) * scale_y;

                const transform = [_]f32{
                    scale_x, 0,       0, 0,
                    0,       scale_y, 0, 0,
                    0,       0,       1, 0,
                    tx,      ty,      0, 1,
                };

                gl.UniformMatrix4fv(state.cell_transform_uniform, 1, gl.FALSE, &transform);

                // Set color (white for alive cells)
                gl.Uniform3f(state.cell_color_uniform, 1.0, 1.0, 1.0);

                // Draw the cell
                gl.DrawArrays(gl.TRIANGLES, 0, 6);
            }
        }
    }

    gl.BindVertexArray(0);
    gl.UseProgram(0);
}

fn handleEvent(gfx: *yass.Graphics, event: yass.Event) !bool {
    const state = @as(*GameState, @ptrCast(@alignCast(gfx.userdata.?)));

    switch (event) {
        .key_down => |key| {
            switch (key.scancode) {
                yass.SCANCODE_ESCAPE => {
                    gfx.quit();
                    return true;
                },
                yass.SCANCODE_SPACE => {
                    state.paused = !state.paused;
                    std.debug.print("Simulation {s}\n", .{if (state.paused) "paused" else "resumed"});
                    return true;
                },
                yass.SCANCODE_RETURN => {
                    if (state.paused) {
                        state.update();
                        std.debug.print("Step\n", .{});
                    }
                    return true;
                },
                yass.SCANCODE_C => {
                    state.clearGrid();
                    std.debug.print("Grid cleared\n", .{});
                    return true;
                },
                yass.SCANCODE_R => {
                    state.randomize();
                    std.debug.print("Grid randomized\n", .{});
                    return true;
                },
                else => {},
            }
        },
        .mouse_button_down => |button| {
            if (button.button == yass.BUTTON_LEFT) {
                // Convert mouse coordinates to grid coordinates
                //                const window_size = try gfx.getWindowSize();

                std.debug.print("Mouse position: ({}, {})\n", .{ button.x, button.y });

                const grid_x: i32 = @intFromFloat(@divFloor(button.x, CELL_SIZE));
                const grid_y: i32 = @intFromFloat(@divFloor(button.y, CELL_SIZE));

                std.debug.print("Grid position: ({}, {})\n", .{ grid_x, grid_y });

                state.toggleCell(grid_x, grid_y);
                return true;
            }
        },
        else => {},
    }

    return false;
}

pub fn main() !void {
    std.debug.print("Conway's Game of Life\n", .{});
    std.debug.print("Controls:\n", .{});
    std.debug.print("  SPACE - Pause/Resume\n", .{});
    std.debug.print("  ENTER - Step (when paused)\n", .{});
    std.debug.print("  C     - Clear grid\n", .{});
    std.debug.print("  R     - Randomize grid\n", .{});
    std.debug.print("  Click - Toggle cell\n", .{});
    std.debug.print("  ESC   - Quit\n\n", .{});

    // Initialize graphics
    const config = yass.GraphicsConfig{
        .title = "Conway's Game of Life",
        .width = GRID_WIDTH * CELL_SIZE,
        .height = GRID_HEIGHT * CELL_SIZE,
        .resizable = true,
        .vsync = true,
    };

    var gfx = try yass.Graphics.init(config);
    defer gfx.deinit();

    // Initialize game state
    var game_state = try GameState.init();
    defer game_state.deinit();

    // Set up callbacks
    gfx.userdata = &game_state;
    gfx.setRenderFn(render);
    gfx.setEventHandler(handleEvent);

    // Run the game
    try gfx.run();
}
