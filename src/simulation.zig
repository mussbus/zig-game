const std = @import("std");

pub const AnimalKind = enum {
    horse,
    dog,
};

pub const Animal = struct {
    kind: AnimalKind,
    spawned_at_s: u64,
};

pub const Spawner = struct {
    interval_s: u64 = 5,
    next_spawn_at_s: u64 = 5,

    pub fn update(
        self: *Spawner,
        now_s: u64,
        random: std.Random,
        animals: *std.ArrayList(Animal),
    ) !void {
        while (now_s >= self.next_spawn_at_s) {
            const kind: AnimalKind = if (random.boolean()) .horse else .dog;
            try animals.append(.{
                .kind = kind,
                .spawned_at_s = self.next_spawn_at_s,
            });
            self.next_spawn_at_s += self.interval_s;
        }
    }
};

pub const Person = struct {
    /// Non-sexual stat representing how comfortable this person is around animals.
    /// Always clamped to the 0..100 range.
    animal_affinity: u8,

    pub fn init(animal_affinity: u8) Person {
        return .{ .animal_affinity = @min(animal_affinity, 100) };
    }
};

test "spawner creates one animal every 5 seconds" {
    var prng = std.Random.DefaultPrng.init(12345);
    const random = prng.random();

    var animals = std.ArrayList(Animal).init(std.testing.allocator);
    defer animals.deinit();

    var spawner = Spawner{};

    try spawner.update(4, random, &animals);
    try std.testing.expectEqual(@as(usize, 0), animals.items.len);

    try spawner.update(5, random, &animals);
    try std.testing.expectEqual(@as(usize, 1), animals.items.len);

    try spawner.update(12, random, &animals);
    try std.testing.expectEqual(@as(usize, 2), animals.items.len);

    try spawner.update(16, random, &animals);
    try std.testing.expectEqual(@as(usize, 3), animals.items.len);
}

test "person affinity is capped at 100" {
    const person = Person.init(255);
    try std.testing.expectEqual(@as(u8, 100), person.animal_affinity);
}
