const std = @import("std");

const male_first_names = [_][]const u8{
    "James", "John", "Robert", "Michael", "David",
    "William", "Richard", "Joseph", "Thomas", "Charles",
};

const female_first_names = [_][]const u8{
    "Nicole", "Mia", "Jennifer", "Lena", "Elizabeth",
    "Paige", "Emma", "Alexis", "Sarah", "Lana",
};

const last_names = [_][]const u8{
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
    "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
};

pub const Place = enum(u8) {
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

pub const PersonType = enum(u8) {
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

pub const MoodLevels = struct {
    aroused: f32,
    energy: f32,
    happiness: f32,
    wet: f32,
    covered: f32,
};

pub const Vec2 = struct {
    x: f32,
    y: f32,
};

pub const PlaceRect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub const KinkLevels = struct {
    top: f32,
    front: f32,
    back: f32,
    wet: f32,
    covered: f32,
    deep: f32,
    rough: f32,
    submit: f32,
    control: f32,
};

pub const SkillLevels = struct {
    top: f32,
    front: f32,
    back: f32,
    wet: f32,
    covered: f32,
    deep: f32,
    rough: f32,
    submit: f32,
    control: f32,
};

pub const CaveType = enum {
    top,
    front,
    back,
};

pub const Connection = struct {
    stick_person_id: usize,
    cave_person_id: usize,
    cave_type: CaveType,
    stick_has_control: bool,
    slot_index: u8,
};

pub const Person = struct {
    id: usize,
    first_name: []const u8,
    last_name: []const u8,
    age: u8,
    kind: PersonType,
    place: Place,
    location: Vec2,
    moods: MoodLevels,
    kinks: KinkLevels,
    skills: SkillLevels,
    owned_by_id: ?usize,
};

pub const place_size: f32 = 100.0;
pub const person_radius: f32 = 1.0;
pub const connection_distance: f32 = 10.0;
pub const settled_connection_distance: f32 = 3.0;
pub const max_move_units_per_second: f32 = 3.0;
pub const min_person_separation: f32 = person_radius * 2.0;

pub const World = struct {
    pub const place_capacity: usize = 40;

    people: std.ArrayList(Person),
    connections: std.ArrayList(Connection),
    place_population: [10]usize,
    male_count: usize,
    female_count: usize,
    futa_count: usize,

    pub fn init() World {
        return .{
            .people = .{},
            .connections = .{},
            .place_population = [_]usize{0} ** 10,
            .male_count = 0,
            .female_count = 0,
            .futa_count = 0,
        };
    }

    pub fn deinit(self: *World, allocator: std.mem.Allocator) void {
        self.people.deinit(allocator);
        self.connections.deinit(allocator);
    }

    pub fn addPerson(self: *World, person: Person, allocator: std.mem.Allocator) !bool {
        const place_index = @intFromEnum(person.place);
        if (self.place_population[place_index] >= place_capacity) {
            return false;
        }

        try self.people.append(allocator, person);

        switch (person.kind) {
            .male => self.male_count += 1,
            .female => self.female_count += 1,
            .futa => self.futa_count += 1,
        }

        self.place_population[place_index] += 1;
        return true;
    }

    pub fn totalPeople(self: *const World) usize {
        return self.people.items.len;
    }
};

pub fn reset(world_state: *World) void {
    world_state.people.clearRetainingCapacity();
    world_state.connections.clearRetainingCapacity();
    world_state.place_population = [_]usize{0} ** 10;
    world_state.male_count = 0;
    world_state.female_count = 0;
    world_state.futa_count = 0;
}

pub fn prefillPlaces(world_state: *World, random: std.Random, allocator: std.mem.Allocator) !void {
    const target_population = (World.place_capacity * 3) / 4;

    for (std.enums.values(Place)) |place| {
        while (world_state.place_population[@intFromEnum(place)] < target_population) {
            try spawnPersonInPlace(world_state, place, random, allocator);
        }
    }
}

pub fn spawnRandomPerson(world_state: *World, random: std.Random, allocator: std.mem.Allocator) !void {
    try spawnPersonInPlace(world_state, randomPlace(random), random, allocator);
}

pub inline fn clampStat(value: f32) f32 {
    return @max(0.0, @min(value, 100.0));
}

pub fn placeRect(place: Place) PlaceRect {
    const index = @intFromEnum(place);
    const col: f32 = @floatFromInt(index % 2);
    const row: f32 = @floatFromInt(index / 2);
    return .{
        .x = col * (place_size + 20.0),
        .y = row * (place_size + 20.0),
        .w = place_size,
        .h = place_size,
    };
}

pub fn distanceSquared(a: Vec2, b: Vec2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    return (dx * dx) + (dy * dy);
}

pub fn distance(a: Vec2, b: Vec2) f32 {
    return @sqrt(distanceSquared(a, b));
}

pub fn normalize(delta: Vec2) Vec2 {
    const length_sq = (delta.x * delta.x) + (delta.y * delta.y);
    if (length_sq <= 0.0001) return .{ .x = 0.0, .y = 0.0 };

    const inv_len = 1.0 / @sqrt(length_sq);
    return .{
        .x = delta.x * inv_len,
        .y = delta.y * inv_len,
    };
}

pub fn clampLocationToPlace(location: Vec2) Vec2 {
    return .{
        .x = @max(person_radius, @min(location.x, place_size - person_radius)),
        .y = @max(person_radius, @min(location.y, place_size - person_radius)),
    };
}

pub fn locationsCollide(a: Vec2, b: Vec2) bool {
    return distanceSquared(a, b) < (min_person_separation * min_person_separation);
}

pub fn locationOccupied(location: Vec2, place: Place, people: []const Person, ignore_person_id: ?usize) bool {
    for (people) |person| {
        if (person.place != place) continue;
        if (ignore_person_id != null and person.id == ignore_person_id.?) continue;
        if (locationsCollide(location, person.location)) return true;
    }
    return false;
}

pub fn connectionSlotOffset(slot_index: u8) Vec2 {
    return switch (slot_index) {
        1 => .{ .x = 0.0, .y = -settled_connection_distance },
        2 => .{ .x = settled_connection_distance, .y = -settled_connection_distance },
        3 => .{ .x = settled_connection_distance, .y = 0.0 },
        4 => .{ .x = settled_connection_distance, .y = settled_connection_distance },
        5 => .{ .x = 0.0, .y = settled_connection_distance },
        6 => .{ .x = -settled_connection_distance, .y = settled_connection_distance },
        7 => .{ .x = -settled_connection_distance, .y = 0.0 },
        8 => .{ .x = -settled_connection_distance, .y = -settled_connection_distance },
        else => .{ .x = settled_connection_distance, .y = 0.0 },
    };
}

pub fn connectionSlotLocation(cave_location: Vec2, slot_index: u8) Vec2 {
    const offset = connectionSlotOffset(slot_index);
    return clampLocationToPlace(.{
        .x = cave_location.x + offset.x,
        .y = cave_location.y + offset.y,
    });
}

pub fn lowestAvailableConnectionSlot(connections: []const Connection, cave_person_id: usize) ?u8 {
    var used = [_]bool{false} ** 8;
    for (connections) |connection| {
        if (connection.cave_person_id != cave_person_id) continue;
        if (connection.slot_index >= 1 and connection.slot_index <= 8) {
            used[connection.slot_index - 1] = true;
        }
    }

    for (used, 0..) |taken, i| {
        if (!taken) return @as(u8, @intCast(i + 1));
    }
    return null;
}

pub inline fn hasStick(kind: PersonType) bool {
    return kind == .male or kind == .futa;
}

pub inline fn hasCaves(kind: PersonType) bool {
    return kind == .female or kind == .futa;
}

pub fn compatibleConnectionPair(person: Person, other: Person) bool {
    return switch (person.kind) {
        .male => other.kind == .female or other.kind == .futa,
        .female => other.kind == .male or other.kind == .futa,
        .futa => true,
    };
}

pub fn caveCapacity(skill: f32, cave_type: CaveType) u8 {
    return switch (cave_type) {
        .top => if (skill >= 50) 2 else 1,
        .front, .back => if (skill >= 67) 3 else if (skill >= 34) 2 else 1,
    };
}

pub inline fn ownerOwnedPair(person: Person, other: Person) bool {
    return person.owned_by_id == other.id or other.owned_by_id == person.id;
}

pub inline fn caveSkillLevel(levels: *const SkillLevels, cave_type: CaveType) f32 {
    return switch (cave_type) {
        .top => levels.top,
        .front => levels.front,
        .back => levels.back,
    };
}

pub inline fn caveSkillLevelPtr(levels: *SkillLevels, cave_type: CaveType) *f32 {
    return switch (cave_type) {
        .top => &levels.top,
        .front => &levels.front,
        .back => &levels.back,
    };
}

pub inline fn caveKinkLevel(levels: *const KinkLevels, cave_type: CaveType) f32 {
    return switch (cave_type) {
        .top => levels.top,
        .front => levels.front,
        .back => levels.back,
    };
}

pub inline fn caveKinkLevelPtr(levels: *KinkLevels, cave_type: CaveType) *f32 {
    return switch (cave_type) {
        .top => &levels.top,
        .front => &levels.front,
        .back => &levels.back,
    };
}

pub fn controlChance(stick_person: Person, cave_person: Person) f64 {
    return (@as(f64, stick_person.kinks.control) * @as(f64, cave_person.kinks.submit)) / 10000.0;
}

pub fn personHasStickConnection(person_id: usize, connections: []const Connection) bool {
    for (connections) |connection| {
        if (connection.stick_person_id == person_id) return true;
    }
    return false;
}

pub fn caveOccupancy(person_id: usize, cave_type: CaveType, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (connections) |connection| {
        if (connection.cave_person_id == person_id and connection.cave_type == cave_type) {
            count += 1;
        }
    }
    return count;
}

pub fn totalCaveCapacity(person: Person) u8 {
    if (!hasCaves(person.kind)) return 0;
    return caveCapacity(person.skills.top, .top) +
        caveCapacity(person.skills.front, .front) +
        caveCapacity(person.skills.back, .back);
}

pub fn totalCaveOccupancy(person_id: usize, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (connections) |connection| {
        if (connection.cave_person_id == person_id) count += 1;
    }
    return count;
}

pub fn openCaveSlots(person: Person, connections: []const Connection) u8 {
    return totalCaveCapacity(person) -| totalCaveOccupancy(person.id, connections);
}

pub fn caveHasCapacity(person: Person, cave_type: CaveType, connections: []const Connection) bool {
    if (!hasCaves(person.kind)) return false;
    return caveOccupancy(person.id, cave_type, connections) < caveCapacity(caveSkillLevel(&person.skills, cave_type), cave_type);
}

pub fn personConnectionCount(person_id: usize, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (connections) |connection| {
        if (connection.stick_person_id == person_id or connection.cave_person_id == person_id) {
            count += 1;
        }
    }
    return count;
}

pub fn canStickConnectToCaveIgnoringDistance(stick_person: Person, cave_person: Person, connections: []const Connection) bool {
    if (stick_person.id == cave_person.id or stick_person.place != cave_person.place) return false;
    if (!hasStick(stick_person.kind) or !hasCaves(cave_person.kind)) return false;
    if (personHasStickConnection(stick_person.id, connections)) return false;
    return openCaveSlots(cave_person, connections) > 0;
}

pub fn canStickConnectToCave(stick_person: Person, cave_person: Person, connections: []const Connection) bool {
    if (!canStickConnectToCaveIgnoringDistance(stick_person, cave_person, connections)) return false;
    return distance(stick_person.location, cave_person.location) <= connection_distance;
}

pub fn personCanAttemptConnection(person: Person, other: Person, connections: []const Connection) bool {
    if (!canStickConnectToCave(person, other, connections) and !canStickConnectToCave(other, person, connections)) {
        return false;
    }
    if (ownerOwnedPair(person, other)) return true;
    return person.moods.energy >= 50 and other.moods.energy >= 50;
}

pub fn personCanPursueConnection(person: Person, other: Person, connections: []const Connection) bool {
    if (!compatibleConnectionPair(person, other)) return false;
    if (!canStickConnectToCaveIgnoringDistance(person, other, connections) and !canStickConnectToCaveIgnoringDistance(other, person, connections)) {
        return false;
    }
    if (ownerOwnedPair(person, other)) return true;
    return person.moods.energy >= 50 and other.moods.energy >= 50;
}

pub fn connectablePeopleCount(person: Person, people: []const Person, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (people) |other| {
        if (personCanAttemptConnection(person, other, connections)) count += 1;
    }
    return count;
}

pub fn ownerCanOwn(owner_kind: PersonType, owned_kind: PersonType) bool {
    return switch (owned_kind) {
        .male => false,
        .female => owner_kind == .male or owner_kind == .futa,
        .futa => owner_kind == .male,
    };
}

pub fn randomOwnedById(owned_kind: PersonType, owned_place: Place, people: []const Person, random: std.Random) ?usize {
    if (owned_kind == .male) return null;
    if (random.uintLessThan(u8, 4) != 0) return null;

    var candidate_count: usize = 0;
    var selected_owner_id: ?usize = null;

    for (people) |person| {
        if (!ownerCanOwn(person.kind, owned_kind)) continue;
        if (person.place != owned_place) continue;

        candidate_count += 1;
        if (random.uintLessThan(usize, candidate_count) == 0) {
            selected_owner_id = person.id;
        }
    }

    return selected_owner_id;
}

pub fn findPersonById(people: []const Person, person_id: usize) ?Person {
    for (people) |person| {
        if (person.id == person_id) return person;
    }
    return null;
}

pub fn findPersonIndexById(people: []const Person, person_id: usize) ?usize {
    for (people, 0..) |person, index| {
        if (person.id == person_id) return index;
    }
    return null;
}

pub fn findStickConnection(connections: []const Connection, person_id: usize) ?Connection {
    for (connections) |connection| {
        if (connection.stick_person_id == person_id) return connection;
    }
    return null;
}

pub fn increaseConnectionHappiness(world_state: *World, primary_index: usize, other_index: usize, rate_scale: f32) void {
    const boosted = clampStat(world_state.people.items[primary_index].moods.happiness + (10.0 * rate_scale));
    world_state.people.items[primary_index].moods.happiness = boosted;

    if (boosted < 100.0) return;

    world_state.people.items[primary_index].moods.happiness = 10.0 * rate_scale;
    world_state.people.items[other_index].moods.happiness = clampStat(world_state.people.items[other_index].moods.happiness + (10.0 * rate_scale));
}

pub inline fn energyLossMultiplier(moods: *const MoodLevels) f32 {
    const protection = (moods.wet + moods.covered) * 0.0025;
    return @max(0.0, 1.0 - protection);
}

pub fn personEndsConnectionsFromEnergy(person_id: usize, connections: []const Connection) bool {
    for (connections) |connection| {
        if (connection.stick_person_id == person_id) return true;
        if (connection.cave_person_id == person_id and !connection.stick_has_control) return true;
    }
    return false;
}

pub fn personHasControlledCaveConnection(person_id: usize, connections: []const Connection) bool {
    for (connections) |connection| {
        if (connection.cave_person_id == person_id and connection.stick_has_control) return true;
    }
    return false;
}

pub fn caveTypeLabel(cave_type: CaveType) []const u8 {
    return switch (cave_type) {
        .top => "top",
        .front => "front",
        .back => "back",
    };
}

fn spawnPersonInPlace(world_state: *World, place: Place, random: std.Random, allocator: std.mem.Allocator) !void {
    const kind = randomPersonType(random);
    const new_person = Person{
        .id = world_state.totalPeople() + 1,
        .first_name = randomFirstName(kind, random),
        .last_name = randomLastName(random),
        .age = randomAge(random),
        .kind = kind,
        .place = place,
        .location = findSpawnLocation(place, world_state.people.items, random),
        .moods = randomMoodLevels(random),
        .kinks = randomKinkLevels(random),
        .skills = randomSkillLevels(random),
        .owned_by_id = randomOwnedById(kind, place, world_state.people.items, random),
    };

    _ = try world_state.addPerson(new_person, allocator);
}

fn findSpawnLocation(place: Place, people: []const Person, random: std.Random) Vec2 {
    var attempts: u8 = 0;
    while (attempts < 48) : (attempts += 1) {
        const candidate = clampLocationToPlace(.{
            .x = person_radius + (random.float(f32) * (place_size - (person_radius * 2.0))),
            .y = person_radius + (random.float(f32) * (place_size - (person_radius * 2.0))),
        });
        if (!locationOccupied(candidate, place, people, null)) return candidate;
    }

    var y = person_radius;
    while (y <= place_size - person_radius) : (y += min_person_separation) {
        var x = person_radius;
        while (x <= place_size - person_radius) : (x += min_person_separation) {
            const candidate = Vec2{ .x = x, .y = y };
            if (!locationOccupied(candidate, place, people, null)) return candidate;
        }
    }

    return .{ .x = person_radius, .y = person_radius };
}

inline fn randomPersonType(random: std.Random) PersonType {
    const person_type: u8 = random.uintLessThan(u8, 100);
    if (person_type < 90) return .male;
    if (person_type < 98) return .female;
    return .futa;
}

inline fn randomFirstName(kind: PersonType, random: std.Random) []const u8 {
    const names = switch (kind) {
        .male => male_first_names[0..],
        .female, .futa => female_first_names[0..],
    };
    return names[random.uintLessThan(usize, names.len)];
}

inline fn randomLastName(random: std.Random) []const u8 {
    return last_names[random.uintLessThan(usize, last_names.len)];
}

inline fn randomAge(random: std.Random) u8 {
    return 18 + random.uintLessThan(u8, 33);
}

inline fn randomPlace(random: std.Random) Place {
    return @enumFromInt(random.uintLessThan(u8, 10));
}

inline fn randomLevel(random: std.Random) f32 {
    return @as(f32, @floatFromInt(random.uintLessThan(u8, 101)));
}

fn randomMoodLevels(random: std.Random) MoodLevels {
    return .{
        .aroused = randomLevel(random),
        .energy = randomLevel(random),
        .happiness = randomLevel(random),
        .wet = 0.0,
        .covered = 0.0,
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
