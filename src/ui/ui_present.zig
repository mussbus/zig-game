const std = @import("std");
const world = @import("../world.zig");
const ui_types = @import("ui_types.zig");

pub const MappedPoint = struct {
    x: i32,
    y: i32,
    radius: i32,
};

pub fn moodBarColor(value: f32, rgbFn: fn (u8, u8, u8) u32) u32 {
    const normalized = world.clampStat(value) / 100.0;
    const red = @as(u8, @intFromFloat(255.0 * (1.0 - normalized)));
    const green = @as(u8, @intFromFloat(255.0 * normalized));
    return rgbFn(red, green, 48);
}

pub fn mapWorldToRect(map_rect: ui_types.Rect, location: world.Vec2) MappedPoint {
    const scale_x = @as(f32, @floatFromInt(map_rect.w)) / world.place_size;
    const scale_y = @as(f32, @floatFromInt(map_rect.h)) / world.place_size;
    const scale = @min(scale_x, scale_y);
    const radius = @max(2, @as(i32, @intFromFloat(world.person_radius * scale)));

    return .{
        .x = map_rect.x + @as(i32, @intFromFloat(location.x * scale)),
        .y = map_rect.y + @as(i32, @intFromFloat(location.y * scale)),
        .radius = radius,
    };
}

pub fn formatSpecialMoods(buf: []u8, moods: world.MoodLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "Special moods: wet {d:.1}  covered {d:.1}", .{
        moods.wet,
        moods.covered,
    });
}

pub fn formatKinkLevelsPrimary(buf: []u8, kinks: world.KinkLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "KinkLevels: top {d:.1}  front {d:.1}  back {d:.1}  wet {d:.1}  covered {d:.1}", .{
        kinks.top,
        kinks.front,
        kinks.back,
        kinks.wet,
        kinks.covered,
    });
}

pub fn formatKinkLevelsSecondary(buf: []u8, kinks: world.KinkLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "            deep {d:.1}  rough {d:.1}  submit {d:.1}  control {d:.1}", .{
        kinks.deep,
        kinks.rough,
        kinks.submit,
        kinks.control,
    });
}

pub fn formatSkillLevelsPrimary(buf: []u8, skills: world.SkillLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "SkillLevels: top {d:.1}  front {d:.1}  back {d:.1}  wet {d:.1}  covered {d:.1}", .{
        skills.top,
        skills.front,
        skills.back,
        skills.wet,
        skills.covered,
    });
}

pub fn formatSkillLevelsSecondary(buf: []u8, skills: world.SkillLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "             deep {d:.1}  rough {d:.1}  submit {d:.1}  control {d:.1}", .{
        skills.deep,
        skills.rough,
        skills.submit,
        skills.control,
    });
}

pub fn formatOwnedPeople(buf: []u8, owner_id: usize, people: []const world.Person) ![]const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer();
    var found_any = false;

    for (people) |other| {
        if (other.owned_by_id != owner_id) continue;

        if (found_any) try writer.writeAll(", ");
        try writer.print("{s} {s}", .{ other.first_name, other.last_name });
        found_any = true;
    }

    if (!found_any) try writer.writeAll("no one");
    return stream.getWritten();
}

pub fn formatAnatomy(buf: []u8, person: world.Person, connections: []const world.Connection) ![]const u8 {
    const stick_state = if (world.hasStick(person.kind))
        if (world.personHasStickConnection(person.id, connections)) "busy" else "free"
    else
        "none";

    return std.fmt.bufPrint(buf, "Stick: {s}  Cave slots open: {d}/{d}", .{
        stick_state,
        world.openCaveSlots(person, connections),
        world.totalCaveCapacity(person),
    });
}

pub fn connectionGroupMatches(group: ui_types.ConnectionGroup, connection: world.Connection) bool {
    return connection.cave_person_id == group.cave_person_id;
}

pub fn skillLevelForConnection(person: world.Person, cave_type: world.CaveType, is_cave_person: bool, stick_has_control: bool) f32 {
    if (is_cave_person and stick_has_control) return person.skills.submit;
    return world.caveSkillLevel(&person.skills, cave_type);
}

pub fn kinkLevelForConnection(person: world.Person, cave_type: world.CaveType, is_cave_person: bool, stick_has_control: bool) f32 {
    if (is_cave_person and stick_has_control) return person.kinks.submit;
    if (!is_cave_person and stick_has_control) return person.kinks.control;
    return world.caveKinkLevel(&person.kinks, cave_type);
}
