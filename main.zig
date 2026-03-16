const std = @import("std");

const Place = enum(u8) {
    town_square,
    market,
    harbor,
    tavern,
    library,
    forge,
    temple,
    farm,
    forest,
    castle,

    pub fn asString(self: Place) []const u8 {
        return switch (self) {
            .town_square => "Town Square",
            .market => "Market",
            .harbor => "Harbor",
            .tavern => "Tavern",
            .library => "Library",
            .forge => "Forge",
            .temple => "Temple",
            .farm => "Farm",
            .forest => "Forest",
            .castle => "Castle",
        };
    }
};

const PersonType = enum(u8) {
    male,
    female,
    futa,

    pub fn asString(self: PersonType) []const u8 {
        return switch (self) {
            .male => "male",
            .female => "female",
            .futa => "futa",
        };
    }
};

const MoodLevels = struct {
    warm: u8,
    energy: u8,
    happiness: u8,
};

const KinkLevels = struct {
    top: u8,
    front: u8,
    back: u8,
    wet: u8,
    covered: u8,
    deep: u8,
    rough: u8,
    submit: u8,
    control: u8,
};

const SkillLevels = struct {
    top: u8,
    front: u8,
    back: u8,
    wet: u8,
    covered: u8,
    deep: u8,
    rough: u8,
    submit: u8,
    control: u8,
};

const ConnectionType = enum {
    top,
    front,
    back,
    wet,
    covered,
    deep,
    rough,
    submit,
    control,
};

const Person = struct {
    id: usize,
    kind: PersonType,
    place: Place,
    moods: MoodLevels,
    kinks: KinkLevels,
    skills: SkillLevels,
    owned_by_id: ?usize,
    connecting_to_id: ?usize,
    connection_type: ?ConnectionType,
};

const World = struct {
    people: std.ArrayList(Person),
    place_population: [10]usize,
    male_count: usize,
    female_count: usize,
    futa_count: usize,

    pub fn init(allocator: std.mem.Allocator) World {
        return .{
            .people = std.ArrayList(Person).init(allocator),
            .place_population = [_]usize{0} ** 10,
            .male_count = 0,
            .female_count = 0,
            .futa_count = 0,
        };
    }

    pub fn deinit(self: *World) void {
        self.people.deinit();
    }

    pub fn addPerson(self: *World, person: Person) !void {
        try self.people.append(person);

        switch (person.kind) {
            .male => self.male_count += 1,
            .female => self.female_count += 1,
            .futa => self.futa_count += 1,
        }

        self.place_population[@intFromEnum(person.place)] += 1;
    }

    pub fn totalPeople(self: *const World) usize {
        return self.people.items.len;
    }
};

fn randomPersonType(random: std.Random) PersonType {
    return switch (random.uintLessThan(u8, 3)) {
        0 => .male,
        1 => .female,
        else => .futa,
    };
}

fn randomPlace(random: std.Random) Place {
    return @enumFromInt(random.uintLessThan(u8, 10));
}

fn randomLevel(random: std.Random) u8 {
    return random.uintLessThan(u8, 101);
}

fn randomMoodLevels(random: std.Random) MoodLevels {
    return .{
        .warm = randomLevel(random),
        .energy = randomLevel(random),
        .happiness = randomLevel(random),
    };
}

fn randomKinkLevels(random: std.Random) KinkLevels {
    return .{
        .top = randomLevel(random),
        .front = randomLevel(random),
        .back = randomLevel(random),
        .wet = randomLevel(random),
        .covered = randomLevel(random),
        .deep = randomLevel(random),
        .rough = randomLevel(random),
        .submit = randomLevel(random),
        .control = randomLevel(random),
    };
}

fn randomSkillLevels(random: std.Random) SkillLevels {
    return .{
        .top = randomLevel(random),
        .front = randomLevel(random),
        .back = randomLevel(random),
        .wet = randomLevel(random),
        .covered = randomLevel(random),
        .deep = randomLevel(random),
        .rough = randomLevel(random),
        .submit = randomLevel(random),
        .control = randomLevel(random),
    };
}

fn clampStat(value: u16) u8 {
    return @as(u8, @intCast(@min(value, 100)));
}

fn canConnectKinds(person_kind: PersonType, other_kind: PersonType) bool {
    return switch (person_kind) {
        .male => other_kind == .female or other_kind == .futa,
        .futa => true,
        .female => true,
    };
}

fn ownerOwnedPair(person: Person, other: Person) bool {
    return person.owned_by_id == other.id or other.owned_by_id == person.id;
}

fn canConnectPair(person: Person, other: Person) bool {
    if (person.id == other.id or person.place != other.place) {
        return false;
    }

    return canConnectKinds(person.kind, other.kind);
}

fn personCanAttemptConnection(person: Person, other: Person) bool {
    if (!canConnectPair(person, other)) {
        return false;
    }

    if (ownerOwnedPair(person, other)) {
        return true;
    }

    return person.moods.energy >= 50 and other.moods.energy >= 50;
}

fn connectablePeopleCount(person: Person, people: []const Person) u8 {
    var count: u8 = 0;
    for (people) |other| {
        if (canConnectPair(person, other)) {
            count += 1;
        }
    }

    return count;
}

fn kinkLevel(levels: *const KinkLevels, connection_type: ConnectionType) u8 {
    return switch (connection_type) {
        .top => levels.top,
        .front => levels.front,
        .back => levels.back,
        .wet => levels.wet,
        .covered => levels.covered,
        .deep => levels.deep,
        .rough => levels.rough,
        .submit => levels.submit,
        .control => levels.control,
    };
}

fn chooseConnectionType(person: Person, other: Person, random: std.Random) ConnectionType {
    const all_types = [_]ConnectionType{ .top, .front, .back, .wet, .covered, .deep, .rough, .submit, .control };
    var weights: [all_types.len]f64 = [_]f64{0} ** all_types.len;
    var total_weight: f64 = 0;

    if (ownerOwnedPair(person, other)) {
        const owner = if (other.owned_by_id == person.id) person else other;
        for (all_types, 0..) |connection_type, i| {
            const weight = @as(f64, @floatFromInt(kinkLevel(&owner.kinks, connection_type))) / 100.0;
            weights[i] = weight;
            total_weight += weight;
        }
    } else {
        for (all_types, 0..) |connection_type, i| {
            const person_weight = (@as(f64, @floatFromInt(kinkLevel(&person.kinks, connection_type))) / 100.0) * 0.5;
            const other_weight = (@as(f64, @floatFromInt(kinkLevel(&other.kinks, connection_type))) / 100.0) * 0.25;
            const weight = person_weight * other_weight;
            weights[i] = weight;
            total_weight += weight;
        }
    }

    if (total_weight <= 0) {
        return all_types[0];
    }

    var roll = random.float(f64) * total_weight;
    for (all_types, 0..) |connection_type, i| {
        roll -= weights[i];
        if (roll <= 0) {
            return connection_type;
        }
    }

    return all_types[all_types.len - 1];
}

fn skillLevelPtr(levels: *SkillLevels, connection_type: ConnectionType) *u8 {
    return switch (connection_type) {
        .top => &levels.top,
        .front => &levels.front,
        .back => &levels.back,
        .wet => &levels.wet,
        .covered => &levels.covered,
        .deep => &levels.deep,
        .rough => &levels.rough,
        .submit => &levels.submit,
        .control => &levels.control,
    };
}

fn kinkLevelPtr(levels: *KinkLevels, connection_type: ConnectionType) *u8 {
    return switch (connection_type) {
        .top => &levels.top,
        .front => &levels.front,
        .back => &levels.back,
        .wet => &levels.wet,
        .covered => &levels.covered,
        .deep => &levels.deep,
        .rough => &levels.rough,
        .submit => &levels.submit,
        .control => &levels.control,
    };
}

fn clearConnection(people: []Person, person_index: usize) void {
    const partner_id = people[person_index].connecting_to_id orelse {
        people[person_index].connection_type = null;
        return;
    };
    people[person_index].connecting_to_id = null;
    people[person_index].connection_type = null;

    for (people, 0..) |*other, other_index| {
        if (other_index != person_index and other.id == partner_id) {
            other.connecting_to_id = null;
            other.connection_type = null;
            break;
        }
    }
}

fn updateConnectionActivity(world: *World, random: std.Random) void {
    for (world.people.items, 0..) |person, i| {
        if (person.connecting_to_id == null) {
            world.people.items[i].moods.energy = clampStat(@as(u16, person.moods.energy) + 2);
            const increase = connectablePeopleCount(person, world.people.items);
            world.people.items[i].moods.warm = clampStat(@as(u16, person.moods.warm) + increase);
        } else {
            world.people.items[i].moods.energy = person.moods.energy -| 5;
            if (world.people.items[i].moods.energy == 0) {
                clearConnection(world.people.items, i);
                continue;
            }

            if (person.connection_type) |connection_type| {
                const skill = skillLevelPtr(&world.people.items[i].skills, connection_type);
                skill.* = clampStat(@as(u16, skill.*) + 2);

                if (random.boolean()) {
                    const kink = kinkLevelPtr(&world.people.items[i].kinks, connection_type);
                    kink.* = clampStat(@as(u16, kink.*) + 1);
                }
            }
        }
    }

    for (world.people.items, 0..) |person, i| {
        if (person.connecting_to_id != null) {
            continue;
        }

        for (world.people.items, 0..) |other, j| {
            if (i == j or other.connecting_to_id != null) {
                continue;
            }

            if (!personCanAttemptConnection(person, other)) {
                continue;
            }

            const should_connect = if (ownerOwnedPair(person, other))
                true
            else blk: {
                const odds = (@as(f64, @floatFromInt(person.moods.warm)) / 100.0) *
                    (@as(f64, @floatFromInt(other.moods.warm)) / 100.0);
                break :blk random.float(f64) < odds;
            };

            if (!should_connect) {
                continue;
            }

            const connection_type = chooseConnectionType(person, other, random);
            world.people.items[i].connecting_to_id = other.id;
            world.people.items[j].connecting_to_id = person.id;
            world.people.items[i].connection_type = connection_type;
            world.people.items[j].connection_type = connection_type;
            break;
        }
    }
}

fn ownerCanOwn(owner_kind: PersonType, owned_kind: PersonType) bool {
    return switch (owned_kind) {
        .male => false,
        .female => owner_kind == .male or owner_kind == .futa,
        .futa => owner_kind == .male,
    };
}

fn randomOwnedById(owned_kind: PersonType, owned_place: Place, people: []const Person, random: std.Random) ?usize {
    if (owned_kind == .male) {
        return null;
    }

    // Only 25% of eligible people should be owned.
    if (random.uintLessThan(u8, 4) != 0) {
        return null;
    }

    var candidate_count: usize = 0;
    var selected_owner_id: ?usize = null;

    for (people) |person| {
        if (!ownerCanOwn(person.kind, owned_kind)) {
            continue;
        }

        if (person.place != owned_place) {
            continue;
        }

        candidate_count += 1;
        if (random.uintLessThan(usize, candidate_count) == 0) {
            selected_owner_id = person.id;
        }
    }

    return selected_owner_id;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("warning: memory leak detected\n", .{});
        }
    }

    const allocator = gpa.allocator();
    var world = World.init(allocator);
    defer world.deinit();

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    std.debug.print("Starting world simulation (1 new person/second). Press Ctrl+C to stop.\n", .{});

    var tick: u64 = 0;
    while (true) {
        tick += 1;
        const kind = randomPersonType(random);
        const place = randomPlace(random);
        const new_person = Person{
            .id = world.totalPeople() + 1,
            .kind = kind,
            .place = place,
            .moods = randomMoodLevels(random),
            .kinks = randomKinkLevels(random),
            .skills = randomSkillLevels(random),
            .owned_by_id = randomOwnedById(kind, place, world.people.items, random),
            .connecting_to_id = null,
            .connection_type = null,
        };

        try world.addPerson(new_person);

        std.debug.print(
            "Tick: created person #{d} ({s}) at {s} [moods: warm={d}, energy={d}, happiness={d}; skills: top={d}, front={d}, back={d}, wet={d}, covered={d}, deep={d}, rough={d}, submit={d}, control={d}; kinks: top={d}, front={d}, back={d}, wet={d}, covered={d}, deep={d}, rough={d}, submit={d}, control={d}; owned_by_id={any}]\nTotal={d} [male={d}, female={d}, futa={d}]\n\n",
            .{
                new_person.id,
                new_person.kind.asString(),
                new_person.place.asString(),
                new_person.moods.warm,
                new_person.moods.energy,
                new_person.moods.happiness,
                new_person.skills.top,
                new_person.skills.front,
                new_person.skills.back,
                new_person.skills.wet,
                new_person.skills.covered,
                new_person.skills.deep,
                new_person.skills.rough,
                new_person.skills.submit,
                new_person.skills.control,
                new_person.kinks.top,
                new_person.kinks.front,
                new_person.kinks.back,
                new_person.kinks.wet,
                new_person.kinks.covered,
                new_person.kinks.deep,
                new_person.kinks.rough,
                new_person.kinks.submit,
                new_person.kinks.control,
                new_person.owned_by_id,
                world.totalPeople(),
                world.male_count,
                world.female_count,
                world.futa_count,
            },
        );

        if (tick % 10 == 0) {
            updateConnectionActivity(&world, random);
        }

        std.time.sleep(std.time.ns_per_s);
    }
}
