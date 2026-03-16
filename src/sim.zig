const std = @import("std");
const world = @import("world.zig");

pub const ticks_per_second: u64 = 10;
pub const step_interval_ms = 1000 / ticks_per_second;

const old_connection_update_interval_seconds: f32 = 10.0;
const new_connection_update_interval_seconds: f32 = 1.0 / @as(f32, ticks_per_second);
const connection_rate_scale: f32 = new_connection_update_interval_seconds / old_connection_update_interval_seconds;
const cave_types = [_]world.CaveType{ .top, .front, .back };

const ConnectionProposal = struct {
    stick_person_id: usize,
    cave_person_id: usize,
    cave_type: world.CaveType,
};

pub fn stepSimulation(world_state: *world.World, tick: *u64, random: std.Random, allocator: std.mem.Allocator) !void {
    tick.* += 1;
    if (tick.* % ticks_per_second == 0) {
        try world.spawnRandomPerson(world_state, random, allocator);
    }

    try updateConnectionActivity(world_state, random, allocator);
}

fn chancePerCheck(old_chance: f64) f64 {
    if (old_chance <= 0) return 0;
    if (old_chance >= 1) return 1;
    return 1.0 - std.math.pow(f64, 1.0 - old_chance, @as(f64, connection_rate_scale));
}

fn appendAvailableCaveProposals(
    proposals: *std.ArrayList(ConnectionProposal),
    stick_person: world.Person,
    cave_person: world.Person,
    connections: []const world.Connection,
    allocator: std.mem.Allocator,
) !void {
    if (!world.canStickConnectToCave(stick_person, cave_person, connections)) return;

    for (cave_types) |cave_type| {
        if (!world.caveHasCapacity(cave_person, cave_type, connections)) continue;

        try proposals.append(allocator, .{
            .stick_person_id = stick_person.id,
            .cave_person_id = cave_person.id,
            .cave_type = cave_type,
        });
    }
}

fn chooseConnectionProposal(
    person: world.Person,
    other: world.Person,
    connections: []const world.Connection,
    random: std.Random,
    allocator: std.mem.Allocator,
) !?ConnectionProposal {
    var proposals = std.ArrayList(ConnectionProposal){};
    defer proposals.deinit(allocator);

    try appendAvailableCaveProposals(&proposals, person, other, connections, allocator);
    try appendAvailableCaveProposals(&proposals, other, person, connections, allocator);

    if (proposals.items.len == 0) return null;

    var total_weight: f64 = 0;
    const weights = try allocator.alloc(f64, proposals.items.len);
    defer allocator.free(weights);

    for (proposals.items, 0..) |proposal, i| {
        const stick_person = if (proposal.stick_person_id == person.id) person else other;
        const cave_person = if (proposal.cave_person_id == person.id) person else other;

        const weight = if (world.ownerOwnedPair(person, other))
            blk: {
                const owner = if (other.owned_by_id == person.id) person else other;
                break :blk @as(f64, world.caveKinkLevel(&owner.kinks, proposal.cave_type)) / 100.0;
            }
        else blk: {
            const stick_weight = (@as(f64, world.caveKinkLevel(&stick_person.kinks, proposal.cave_type)) / 100.0) * 0.5;
            const cave_weight = (@as(f64, world.caveKinkLevel(&cave_person.kinks, proposal.cave_type)) / 100.0) * 0.25;
            break :blk stick_weight * cave_weight;
        };

        weights[i] = weight;
        total_weight += weight;
    }

    if (total_weight <= 0) return proposals.items[0];

    var roll = random.float(f64) * total_weight;
    for (proposals.items, 0..) |proposal, i| {
        roll -= weights[i];
        if (roll <= 0) return proposal;
    }

    return proposals.items[proposals.items.len - 1];
}

fn clearAllConnectionsForPerson(world_state: *world.World, person_id: usize) void {
    var i: usize = 0;
    while (i < world_state.connections.items.len) {
        const connection = world_state.connections.items[i];
        if (connection.stick_person_id != person_id and connection.cave_person_id != person_id) {
            i += 1;
            continue;
        }

        const stick = world.findPersonById(world_state.people.items, connection.stick_person_id);
        const cave = world.findPersonById(world_state.people.items, connection.cave_person_id);
        if (stick) |stick_person| {
            if (world.findPersonIndexById(world_state.people.items, stick_person.id)) |index| {
                world_state.people.items[index].moods.warm = 0;
            }
        }
        if (cave) |cave_person| {
            if (world.findPersonIndexById(world_state.people.items, cave_person.id)) |index| {
                world_state.people.items[index].moods.warm = 0;
            }
        }

        _ = world_state.connections.swapRemove(i);
    }
}

fn updateConnectionActivity(world_state: *world.World, random: std.Random, allocator: std.mem.Allocator) !void {
    for (world_state.connections.items) |connection| {
        const stick_index = world.findPersonIndexById(world_state.people.items, connection.stick_person_id) orelse continue;
        const cave_index = world.findPersonIndexById(world_state.people.items, connection.cave_person_id) orelse continue;

        world_state.people.items[stick_index].moods.energy = world.clampStat(world_state.people.items[stick_index].moods.energy - (3.0 * connection_rate_scale));
        world_state.people.items[cave_index].moods.energy = world.clampStat(world_state.people.items[cave_index].moods.energy - (3.0 * connection_rate_scale));

        world.increaseConnectionHappiness(world_state, stick_index, cave_index, connection_rate_scale);
        world.increaseConnectionHappiness(world_state, cave_index, stick_index, connection_rate_scale);
    }

    for (world_state.people.items, 0..) |person, i| {
        const connection_count = world.personConnectionCount(person.id, world_state.connections.items);
        if (connection_count == 0) {
            world_state.people.items[i].moods.energy = world.clampStat(person.moods.energy + (2.0 * connection_rate_scale));
            const increase = world.connectablePeopleCount(person, world_state.people.items, world_state.connections.items);
            world_state.people.items[i].moods.warm = world.clampStat(person.moods.warm + (@as(f32, @floatFromInt(increase)) * (3.0 * connection_rate_scale)));
            continue;
        }

        if (world.personEndsConnectionsFromEnergy(person.id, world_state.connections.items) and world_state.people.items[i].moods.energy <= 0.0) {
            clearAllConnectionsForPerson(world_state, person.id);
            continue;
        }

        if (world.personHasStickConnection(person.id, world_state.connections.items)) {
            if (world.findStickConnection(world_state.connections.items, person.id)) |connection| {
                const skill = world.caveSkillLevelPtr(&world_state.people.items[i].skills, connection.cave_type);
                skill.* = world.clampStat(skill.* + (2.0 * connection_rate_scale));

                if (connection.stick_has_control) {
                    world_state.people.items[i].skills.control = world.clampStat(world_state.people.items[i].skills.control + (1.0 * connection_rate_scale));
                }

                const kink = world.caveKinkLevelPtr(&world_state.people.items[i].kinks, connection.cave_type);
                kink.* = world.clampStat(kink.* + (0.5 * connection_rate_scale));
            }
        }

        if (world.hasCaves(person.kind)) {
            for (cave_types) |cave_type| {
                const occupancy = world.caveOccupancy(person.id, cave_type, world_state.connections.items);
                if (occupancy == 0) continue;

                const skill = world.caveSkillLevelPtr(&world_state.people.items[i].skills, cave_type);
                skill.* = world.clampStat(skill.* + (@as(f32, @floatFromInt(occupancy)) * (2.0 * connection_rate_scale)));

                var controlled_occupancy: u8 = 0;
                for (world_state.connections.items) |connection| {
                    if (connection.cave_person_id == person.id and connection.cave_type == cave_type and connection.stick_has_control) {
                        controlled_occupancy += 1;
                    }
                }
                if (controlled_occupancy > 0) {
                    world_state.people.items[i].skills.submit = world.clampStat(world_state.people.items[i].skills.submit + (@as(f32, @floatFromInt(controlled_occupancy)) * connection_rate_scale));
                }

                const kink = world.caveKinkLevelPtr(&world_state.people.items[i].kinks, cave_type);
                kink.* = world.clampStat(kink.* + (@as(f32, @floatFromInt(occupancy)) * (0.5 * connection_rate_scale)));
            }
        }
    }

    for (world_state.people.items) |person| {
        if (!world.personHasStickConnection(person.id, world_state.connections.items) and world.openCaveSlots(person, world_state.connections.items) == 0) {
            continue;
        }

        for (world_state.people.items) |other| {
            if (person.id == other.id) continue;
            if (!world.personCanAttemptConnection(person, other, world_state.connections.items)) continue;

            const should_connect = if (world.ownerOwnedPair(person, other))
                true
            else blk: {
                const odds = (@as(f64, person.moods.warm) / 100.0) * (@as(f64, other.moods.warm) / 100.0);
                break :blk random.float(f64) < chancePerCheck(odds);
            };
            if (!should_connect) continue;

            const proposal = (try chooseConnectionProposal(person, other, world_state.connections.items, random, allocator)) orelse continue;
            const stick = world.findPersonById(world_state.people.items, proposal.stick_person_id) orelse continue;
            const cave = world.findPersonById(world_state.people.items, proposal.cave_person_id) orelse continue;
            const stick_has_control = world.ownerOwnedPair(person, other) or random.float(f64) < world.controlChance(stick, cave);
            try world_state.connections.append(allocator, .{
                .stick_person_id = proposal.stick_person_id,
                .cave_person_id = proposal.cave_person_id,
                .cave_type = proposal.cave_type,
                .stick_has_control = stick_has_control,
            });
            break;
        }
    }
}
