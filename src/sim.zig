const std = @import("std");
const world = @import("world.zig");

pub const ticks_per_second: u64 = 10;
pub const step_interval_ms = 1000 / ticks_per_second;

const old_connection_update_interval_seconds: f32 = 10.0;
const new_connection_update_interval_seconds: f32 = 1.0 / @as(f32, ticks_per_second);
const connection_rate_scale: f32 = new_connection_update_interval_seconds / old_connection_update_interval_seconds;
const mood_decay_per_tick: f32 = 1.0 / 30.0;
const move_units_per_tick: f32 = world.max_move_units_per_second / @as(f32, ticks_per_second);
const cave_types = [_]world.CaveType{ .top, .front, .back };

const SimEvent = union(enum) {
    cave_covered: struct {
        stick_person_id: usize,
        cave_person_id: usize,
        cave_type: world.CaveType,
    },
    cave_wet: struct {
        stick_person_id: usize,
        cave_person_id: usize,
        cave_type: world.CaveType,
    },
};

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

    decaySpecialMoods(world_state);
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
                world_state.people.items[index].moods.aroused = 0;
            }
        }
        if (cave) |cave_person| {
            if (world.findPersonIndexById(world_state.people.items, cave_person.id)) |index| {
                world_state.people.items[index].moods.aroused = 0;
            }
        }

        _ = world_state.connections.swapRemove(i);
    }
}

fn decaySpecialMoods(world_state: *world.World) void {
    for (world_state.people.items) |*person| {
        person.moods.wet = world.clampStat(person.moods.wet - mood_decay_per_tick);
        person.moods.covered = world.clampStat(person.moods.covered - mood_decay_per_tick);
    }
}

fn emitEvent(world_state: *world.World, event: SimEvent) void {
    switch (event) {
        .cave_covered => |payload| {
            const cave_index = world.findPersonIndexById(world_state.people.items, payload.cave_person_id) orelse return;
            world_state.people.items[cave_index].moods.covered = world.clampStat(world_state.people.items[cave_index].moods.covered + 20.0);
        },
        .cave_wet => |payload| {
            const cave_index = world.findPersonIndexById(world_state.people.items, payload.cave_person_id) orelse return;
            world_state.people.items[cave_index].moods.wet = world.clampStat(world_state.people.items[cave_index].moods.wet + 30.0);
        },
    }
}

fn applyConnectionEnergyLoss(world_state: *world.World, person_index: usize, base_loss: f32) void {
    const multiplier = world.energyLossMultiplier(&world_state.people.items[person_index].moods);
    world_state.people.items[person_index].moods.energy = world.clampStat(
        world_state.people.items[person_index].moods.energy - (base_loss * multiplier),
    );
}

fn increaseStickConnectionHappiness(
    world_state: *world.World,
    stick_index: usize,
    cave_index: usize,
    connection: world.Connection,
    rate_scale: f32,
) void {
    const boosted = world.clampStat(world_state.people.items[stick_index].moods.happiness + (10.0 * rate_scale));
    world_state.people.items[stick_index].moods.happiness = boosted;

    if (boosted < 100.0) return;

    emitEvent(world_state, .{ .cave_covered = .{
        .stick_person_id = connection.stick_person_id,
        .cave_person_id = connection.cave_person_id,
        .cave_type = connection.cave_type,
    } });

    world_state.people.items[stick_index].moods.happiness = 10.0 * rate_scale;
    world_state.people.items[cave_index].moods.happiness = world.clampStat(world_state.people.items[cave_index].moods.happiness + (10.0 * rate_scale));
}

fn emitWetEventForStick(world_state: *world.World, person_id: usize) void {
    const connection = world.findStickConnection(world_state.connections.items, person_id) orelse return;
    emitEvent(world_state, .{ .cave_wet = .{
        .stick_person_id = connection.stick_person_id,
        .cave_person_id = connection.cave_person_id,
        .cave_type = connection.cave_type,
    } });
}

fn movePersonToward(world_state: *world.World, person_index: usize, target: world.Vec2) void {
    const current = world_state.people.items[person_index].location;
    const delta = world.Vec2{
        .x = target.x - current.x,
        .y = target.y - current.y,
    };
    const distance = world.distance(current, target);
    if (distance <= 0.001) return;

    const step = @min(distance, move_units_per_tick);
    const direction = world.normalize(delta);
    world_state.people.items[person_index].location = world.clampLocationToPlace(.{
        .x = current.x + (direction.x * step),
        .y = current.y + (direction.y * step),
    });
}

fn connectionGroupPosition(center: world.Vec2, slot_index: u8) world.Vec2 {
    if (slot_index == 0) return center;
    return world.connectionSlotLocation(center, slot_index);
}

fn connectionGroupCenterInBounds(center: world.Vec2) bool {
    const margin = world.person_radius + world.settled_connection_distance;
    return center.x >= margin and center.x <= world.place_size - margin and
        center.y >= margin and center.y <= world.place_size - margin;
}

fn fullConnectionGroupFitsAt(
    world_state: *const world.World,
    place: world.Place,
    center: world.Vec2,
    cave_person_id: usize,
    incoming_stick_id: usize,
) bool {
    if (!connectionGroupCenterInBounds(center)) return false;

    var candidate_positions: [9]world.Vec2 = undefined;
    for (&candidate_positions, 0..) |*position, i| {
        position.* = connectionGroupPosition(center, @as(u8, @intCast(i)));
    }

    for (world_state.people.items) |person| {
        if (person.place != place) continue;
        if (person.id == cave_person_id or person.id == incoming_stick_id) continue;

        for (candidate_positions) |candidate_position| {
            if (world.locationsCollide(candidate_position, person.location)) return false;
        }
    }

    for (world_state.people.items) |other| {
        if (other.place != place) continue;
        if (other.id == cave_person_id) continue;
        if (!world.hasCaves(other.kind)) continue;
        if (world.totalCaveOccupancy(other.id, world_state.connections.items) == 0) continue;

        var slot_index: u8 = 0;
        while (slot_index <= 8) : (slot_index += 1) {
            const other_position = connectionGroupPosition(other.location, slot_index);
            for (candidate_positions) |candidate_position| {
                if (world.locationsCollide(candidate_position, other_position)) return false;
            }
        }
    }

    return true;
}

fn findSafeConnectionGroupCenter(
    world_state: *const world.World,
    cave_person: world.Person,
    stick_person_id: usize,
) ?world.Vec2 {
    if (fullConnectionGroupFitsAt(world_state, cave_person.place, cave_person.location, cave_person.id, stick_person_id)) {
        return cave_person.location;
    }

    const margin = world.person_radius + world.settled_connection_distance;
    var best_location: ?world.Vec2 = null;
    var best_distance_sq = std.math.inf(f32);

    var y = margin;
    while (y <= world.place_size - margin) : (y += world.min_person_separation) {
        var x = margin;
        while (x <= world.place_size - margin) : (x += world.min_person_separation) {
            const candidate = world.Vec2{ .x = x, .y = y };
            if (!fullConnectionGroupFitsAt(world_state, cave_person.place, candidate, cave_person.id, stick_person_id)) continue;

            const distance_sq = world.distanceSquared(candidate, cave_person.location);
            if (distance_sq < best_distance_sq) {
                best_distance_sq = distance_sq;
                best_location = candidate;
            }
        }
    }

    return best_location;
}

fn personIsConnected(person_id: usize, connections: []const world.Connection) bool {
    return world.personConnectionCount(person_id, connections) > 0;
}

fn displacePerson(world_state: *world.World, person_index: usize, delta: world.Vec2) void {
    const current = world_state.people.items[person_index].location;
    world_state.people.items[person_index].location = world.clampLocationToPlace(.{
        .x = current.x + delta.x,
        .y = current.y + delta.y,
    });
}

fn resolveCollisions(world_state: *world.World) void {
    var pass: u8 = 0;
    while (pass < 4) : (pass += 1) {
        var changed = false;
        for (world_state.people.items, 0..) |left, left_index| {
            for (world_state.people.items[left_index + 1 ..], left_index + 1..) |right, right_index| {
                if (left.place != right.place) continue;

                const distance = world.distance(left.location, right.location);
                if (distance >= world.min_person_separation) continue;

                var direction = world.normalize(.{
                    .x = right.location.x - left.location.x,
                    .y = right.location.y - left.location.y,
                });
                if (direction.x == 0.0 and direction.y == 0.0) {
                    direction = if ((left.id + right.id) % 2 == 0)
                        .{ .x = 1.0, .y = 0.0 }
                    else
                        .{ .x = 0.0, .y = 1.0 };
                }

                const overlap = world.min_person_separation - distance;
                const left_connected = personIsConnected(left.id, world_state.connections.items);
                const right_connected = personIsConnected(right.id, world_state.connections.items);

                if (!left_connected and !right_connected) {
                    const half = overlap * 0.5;
                    displacePerson(world_state, left_index, .{ .x = -direction.x * half, .y = -direction.y * half });
                    displacePerson(world_state, right_index, .{ .x = direction.x * half, .y = direction.y * half });
                } else if (!left_connected) {
                    displacePerson(world_state, left_index, .{ .x = -direction.x * overlap, .y = -direction.y * overlap });
                } else if (!right_connected) {
                    displacePerson(world_state, right_index, .{ .x = direction.x * overlap, .y = direction.y * overlap });
                } else {
                    continue;
                }

                changed = true;
            }
        }
        if (!changed) break;
    }
}

fn arrangeConnectionGroup(world_state: *world.World, cave_person_id: usize) void {
    const cave_index = world.findPersonIndexById(world_state.people.items, cave_person_id) orelse return;
    const cave_location = world_state.people.items[cave_index].location;

    for (world_state.connections.items) |connection| {
        if (connection.cave_person_id != cave_person_id) continue;
        const stick_index = world.findPersonIndexById(world_state.people.items, connection.stick_person_id) orelse continue;
        world_state.people.items[stick_index].location = world.connectionSlotLocation(cave_location, connection.slot_index);
    }
}

fn moveUnconnectedPeople(world_state: *world.World) void {
    for (world_state.people.items, 0..) |person, person_index| {
        if (world.personConnectionCount(person.id, world_state.connections.items) != 0) continue;

        var best_target_index: ?usize = null;
        var best_target_arousal: f32 = -1.0;
        for (world_state.people.items, 0..) |other, other_index| {
            if (person.id == other.id) continue;
            if (!world.personCanPursueConnection(person, other, world_state.connections.items)) continue;

            if (other.moods.aroused > best_target_arousal) {
                best_target_arousal = other.moods.aroused;
                best_target_index = other_index;
            }
        }

        const target_index = best_target_index orelse continue;
        movePersonToward(world_state, person_index, world_state.people.items[target_index].location);
    }
}

fn updateConnectionActivity(world_state: *world.World, random: std.Random, allocator: std.mem.Allocator) !void {
    for (world_state.connections.items, 0..) |connection, connection_index| {
        const stick_index = world.findPersonIndexById(world_state.people.items, connection.stick_person_id) orelse continue;
        const cave_index = world.findPersonIndexById(world_state.people.items, connection.cave_person_id) orelse continue;

        applyConnectionEnergyLoss(world_state, stick_index, 3.0 * connection_rate_scale);
        var cave_loss_applied = false;
        for (world_state.connections.items[0..connection_index]) |existing_connection| {
            if (existing_connection.cave_person_id == connection.cave_person_id) {
                cave_loss_applied = true;
                break;
            }
        }
        if (!cave_loss_applied) {
            applyConnectionEnergyLoss(world_state, cave_index, 3.0 * connection_rate_scale);
        }

        increaseStickConnectionHappiness(world_state, stick_index, cave_index, connection, connection_rate_scale);
        world.increaseConnectionHappiness(world_state, cave_index, stick_index, connection_rate_scale);
    }

    for (world_state.people.items, 0..) |person, i| {
        const connection_count = world.personConnectionCount(person.id, world_state.connections.items);
        if (connection_count == 0) {
            world_state.people.items[i].moods.energy = world.clampStat(person.moods.energy + (2.0 * connection_rate_scale));
            const attraction_score = world.attractionOpportunityScore(person, world_state.people.items, world_state.connections.items);
            world_state.people.items[i].moods.aroused = world.clampStat(person.moods.aroused + (attraction_score * (3.0 * connection_rate_scale)));
            continue;
        }

        if (world.personEndsConnectionsFromEnergy(person.id, world_state.connections.items) and world_state.people.items[i].moods.energy <= 0.0) {
            if (world.personHasStickConnection(person.id, world_state.connections.items)) {
                emitWetEventForStick(world_state, person.id);
            }
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

    moveUnconnectedPeople(world_state);
    resolveCollisions(world_state);

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
                const mutual_attraction = @as(f64, world.attractionScore(person, other)) * @as(f64, world.attractionScore(other, person));
                const odds = ((@as(f64, person.moods.aroused) / 100.0) * (@as(f64, other.moods.aroused) / 100.0)) * mutual_attraction;
                break :blk random.float(f64) < chancePerCheck(odds);
            };
            if (!should_connect) continue;

            const proposal = (try chooseConnectionProposal(person, other, world_state.connections.items, random, allocator)) orelse continue;
            const stick = world.findPersonById(world_state.people.items, proposal.stick_person_id) orelse continue;
            const cave = world.findPersonById(world_state.people.items, proposal.cave_person_id) orelse continue;
            const stick_has_control = world.ownerOwnedPair(person, other) or random.float(f64) < world.controlChance(stick, cave);
            const slot_index = world.lowestAvailableConnectionSlot(world_state.connections.items, proposal.cave_person_id) orelse continue;
            if (world.totalCaveOccupancy(proposal.cave_person_id, world_state.connections.items) == 0) {
                const safe_center = findSafeConnectionGroupCenter(world_state, cave, proposal.stick_person_id) orelse continue;
                const cave_index = world.findPersonIndexById(world_state.people.items, proposal.cave_person_id) orelse continue;
                world_state.people.items[cave_index].location = safe_center;
            }
            try world_state.connections.append(allocator, .{
                .stick_person_id = proposal.stick_person_id,
                .cave_person_id = proposal.cave_person_id,
                .cave_type = proposal.cave_type,
                .stick_has_control = stick_has_control,
                .slot_index = slot_index,
            });
            arrangeConnectionGroup(world_state, proposal.cave_person_id);
            resolveCollisions(world_state);
            break;
        }
    }
}
