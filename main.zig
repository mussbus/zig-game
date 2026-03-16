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

const Person = struct {
    id: usize,
    kind: PersonType,
    place: Place,
    moods: MoodLevels,
    kinks: KinkLevels,
    owned: bool,
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

    while (true) {
        const new_person = Person{
            .id = world.totalPeople() + 1,
            .kind = randomPersonType(random),
            .place = randomPlace(random),
            .moods = randomMoodLevels(random),
            .kinks = randomKinkLevels(random),
            .owned = random.boolean(),
        };

        try world.addPerson(new_person);

        std.debug.print(
            "Tick: created person #{d} ({s}) at {s} [moods: warm={d}, energy={d}, happiness={d}; kinks: top={d}, front={d}, back={d}, wet={d}, covered={d}, deep={d}, rough={d}, submit={d}, control={d}; owned={s}]\nTotal={d} [male={d}, female={d}, futa={d}]\n\n",
            .{
                new_person.id,
                new_person.kind.asString(),
                new_person.place.asString(),
                new_person.moods.warm,
                new_person.moods.energy,
                new_person.moods.happiness,
                new_person.kinks.top,
                new_person.kinks.front,
                new_person.kinks.back,
                new_person.kinks.wet,
                new_person.kinks.covered,
                new_person.kinks.deep,
                new_person.kinks.rough,
                new_person.kinks.submit,
                new_person.kinks.control,
                if (new_person.owned) "yes" else "no",
                world.totalPeople(),
                world.male_count,
                world.female_count,
                world.futa_count,
            },
        );

        std.time.sleep(std.time.ns_per_s);
    }
}
