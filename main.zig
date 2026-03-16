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

const Person = struct {
    id: usize,
    kind: PersonType,
    place: Place,
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
        };

        try world.addPerson(new_person);

        std.debug.print(
            "Tick: created person #{d} ({s}) at {s}\nTotal={d} [male={d}, female={d}, futa={d}]\n\n",
            .{
                new_person.id,
                new_person.kind.asString(),
                new_person.place.asString(),
                world.totalPeople(),
                world.male_count,
                world.female_count,
                world.futa_count,
            },
        );

        std.time.sleep(std.time.ns_per_s);
    }
}
