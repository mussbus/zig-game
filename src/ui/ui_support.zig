const std = @import("std");
const world = @import("../world.zig");

pub const person_type_options = [_]world.PersonType{ .male, .female, .futa };
pub const race_options = [_]world.Race{ .african, .east_asian, .european, .latino, .middle_eastern, .south_asian, .native_american, .pacific_islander, .mixed };

pub fn genderBit(kind: world.PersonType) u8 {
    return @as(u8, @intCast(@as(u16, 1) << @as(u3, @intCast(@intFromEnum(kind)))));
}

pub fn raceBit(race: world.Race) u16 {
    return @as(u16, @intCast(@as(u32, 1) << @as(u4, @intCast(@intFromEnum(race)))));
}

pub fn allGenderMask() u8 {
    var mask: u8 = 0;
    for (person_type_options) |kind| {
        mask |= genderBit(kind);
    }
    return mask;
}

pub fn allRaceMask() u16 {
    var mask: u16 = 0;
    for (race_options) |race| {
        mask |= raceBit(race);
    }
    return mask;
}

pub fn genderSelected(mask: u8, kind: world.PersonType) bool {
    return (mask & genderBit(kind)) != 0;
}

pub fn raceSelected(mask: u16, race: world.Race) bool {
    return (mask & raceBit(race)) != 0;
}

pub fn toggleGenderSelection(mask: *u8, kind: world.PersonType) void {
    mask.* ^= genderBit(kind);
}

pub fn toggleRaceSelection(mask: *u16, race: world.Race) void {
    mask.* ^= raceBit(race);
}

pub fn selectedGenderCount(mask: u8) usize {
    var count: usize = 0;
    for (person_type_options) |kind| {
        if (genderSelected(mask, kind)) count += 1;
    }
    return count;
}

pub fn selectedRaceCount(mask: u16) usize {
    var count: usize = 0;
    for (race_options) |race| {
        if (raceSelected(mask, race)) count += 1;
    }
    return count;
}

pub fn personMatchesFilters(person: world.Person, gender_mask: u8, race_mask: u16) bool {
    return genderSelected(gender_mask, person.kind) and raceSelected(race_mask, person.race);
}

pub fn peopleCountInPlaceFiltered(world_state: *const world.World, selected_place: world.Place, gender_mask: u8, race_mask: u16) usize {
    var count: usize = 0;
    for (world_state.people.items) |person| {
        if (person.place == selected_place and personMatchesFilters(person, gender_mask, race_mask)) count += 1;
    }
    return count;
}

pub fn connectionGroupCountInPlace(world_state: *const world.World, selected_place: world.Place) usize {
    var count: usize = 0;
    for (world_state.connections.items, 0..) |connection, connection_index| {
        if (!world.isConnectionGroupFirstOccurrence(world_state.connections.items, connection_index)) continue;

        const stick = world.findPersonById(world_state.people.items, connection.stick_person_id) orelse continue;
        const cave = world.findPersonById(world_state.people.items, connection.cave_person_id) orelse continue;
        if (stick.place != selected_place or cave.place != selected_place) continue;
        if (cave.kind == .male) continue;
        count += 1;
    }
    return count;
}

pub fn genderSelectionSummary(buf: []u8, mask: u8) ![]const u8 {
    const count = selectedGenderCount(mask);
    if (count == 0) return std.fmt.bufPrint(buf, "no genders", .{});
    if (mask == allGenderMask()) return std.fmt.bufPrint(buf, "all genders", .{});
    if (count == 1) {
        for (person_type_options) |kind| {
            if (genderSelected(mask, kind)) return std.fmt.bufPrint(buf, "{s}", .{kind.asString()});
        }
    }
    return std.fmt.bufPrint(buf, "{d} genders", .{count});
}

pub fn raceSelectionSummary(buf: []u8, mask: u16) ![]const u8 {
    const count = selectedRaceCount(mask);
    if (count == 0) return std.fmt.bufPrint(buf, "no races", .{});
    if (mask == allRaceMask()) return std.fmt.bufPrint(buf, "all races", .{});
    if (count == 1) {
        for (race_options) |race| {
            if (raceSelected(mask, race)) return std.fmt.bufPrint(buf, "{s}", .{race.asString()});
        }
    }
    return std.fmt.bufPrint(buf, "{d} races", .{count});
}
