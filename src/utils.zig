const std = @import("std");
const gl = @import("gl");

const gl_log = std.log.scoped(.gl);

pub fn createShaderProgram(vertex_src: [:0]const u8, fragment_src: [:0]const u8) !c_uint {
    const vertex_shader = try compileShader(vertex_src, gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertex_shader);

    const fragment_shader = try compileShader(fragment_src, gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragment_shader);
    const p = gl.CreateProgram();
    if (p == 0) {
        gl_log.err("Failed to create shader program", .{});
        return error.GlCreateProgramFailed;
    }

    gl.AttachShader(p, vertex_shader);
    gl.AttachShader(p, fragment_shader);
    gl.LinkProgram(p);

    var success: c_int = undefined;
    gl.GetProgramiv(p, gl.LINK_STATUS, &success);
    if (success == gl.FALSE) {
        var info_log_buf: [512:0]u8 = undefined;
        gl.GetProgramInfoLog(p, info_log_buf.len, null, &info_log_buf);
        gl_log.err("Shader linking failed:\n{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        gl.DeleteProgram(p);
        return error.LinkProgramFailed;
    }

    return p;
}

pub fn compileShader(source: [:0]const u8, shader_type: c_uint) !c_uint {
    const shader = gl.CreateShader(shader_type);
    if (shader == 0) {
        gl_log.err("Failed to create shader", .{});
        return error.GlCreateShaderFailed;
    }

    gl.ShaderSource(shader, 1, &.{source.ptr}, null);
    gl.CompileShader(shader);

    var success: c_int = undefined;
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success);
    if (success == gl.FALSE) {
        var info_log_buf: [512:0]u8 = undefined;
        gl.GetShaderInfoLog(shader, info_log_buf.len, null, &info_log_buf);
        gl_log.err("Shader compilation failed:\n{s}", .{std.mem.sliceTo(&info_log_buf, 0)});
        gl.DeleteShader(shader);
        return error.GlCompileShaderFailed;
    }

    return shader;
}

/// Converts the return value of an SDL function to an error union.
pub inline fn errify(value: anytype) error{SdlError}!switch (@typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
