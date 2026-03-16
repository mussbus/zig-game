const std = @import("std");
const builtin = @import("builtin");
const windows = std.os.windows;

comptime {
    if (builtin.os.tag != .windows) {
        @compileError("This UI build targets Windows only.");
    }
}

const win = struct {
    const BOOL = windows.BOOL;
    const UINT = windows.UINT;
    const WPARAM = windows.WPARAM;
    const LPARAM = windows.LPARAM;
    const LRESULT = windows.LRESULT;
    const HINSTANCE = windows.HINSTANCE;
    const HWND = windows.HWND;
    const HDC = windows.HDC;
    const HBRUSH = windows.HBRUSH;
    const HCURSOR = windows.HCURSOR;
    const HMENU = windows.HMENU;
    const POINT = windows.POINT;
    const RECT = windows.RECT;
    const COLORREF = u32;
    const ATOM = windows.ATOM;
    const HGDIOBJ = *opaque {};
    const WNDPROC = *const fn (?HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

    const WNDCLASSA = extern struct {
        style: u32,
        lpfnWndProc: ?WNDPROC,
        cbClsExtra: i32,
        cbWndExtra: i32,
        hInstance: ?HINSTANCE,
        hIcon: ?*opaque {},
        hCursor: ?HCURSOR,
        hbrBackground: ?HBRUSH,
        lpszMenuName: ?[*:0]const u8,
        lpszClassName: [*:0]const u8,
    };

    const MSG = extern struct {
        hwnd: ?HWND,
        message: UINT,
        wParam: WPARAM,
        lParam: LPARAM,
        time: u32,
        pt: POINT,
        lPrivate: u32,
    };

    const CS_VREDRAW: u32 = 0x0001;
    const CS_HREDRAW: u32 = 0x0002;
    const WS_VISIBLE: u32 = 0x10000000;
    const WS_OVERLAPPEDWINDOW: u32 = 0x00CF0000;
    const CW_USEDEFAULT: i32 = @as(i32, @bitCast(@as(u32, 0x80000000)));
    const PM_REMOVE: UINT = 0x0001;
    const WM_DESTROY: UINT = 0x0002;
    const WM_QUIT: UINT = 0x0012;
    const WM_LBUTTONDOWN: UINT = 0x0201;
    const BLACK_BRUSH: i32 = 4;
    const TRANSPARENT: i32 = 1;
    const IDC_ARROW: [*:0]const u8 = @ptrFromInt(32512);

    extern "kernel32" fn GetModuleHandleA(lpModuleName: ?[*:0]const u8) callconv(.winapi) ?HINSTANCE;
    extern "user32" fn RegisterClassA(lpWndClass: *const WNDCLASSA) callconv(.winapi) ATOM;
    extern "user32" fn CreateWindowExA(
        dwExStyle: u32,
        lpClassName: [*:0]const u8,
        lpWindowName: [*:0]const u8,
        dwStyle: u32,
        X: i32,
        Y: i32,
        nWidth: i32,
        nHeight: i32,
        hWndParent: ?HWND,
        hMenu: ?HMENU,
        hInstance: ?HINSTANCE,
        lpParam: ?*anyopaque,
    ) callconv(.winapi) ?HWND;
    extern "user32" fn LoadCursorA(hInstance: ?HINSTANCE, lpCursorName: ?[*:0]const u8) callconv(.winapi) ?HCURSOR;
    extern "user32" fn DefWindowProcA(hWnd: ?HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
    extern "user32" fn PostQuitMessage(exit_code: i32) callconv(.winapi) void;
    extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.winapi) BOOL;
    extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
    extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(.winapi) LRESULT;
    extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.winapi) BOOL;
    extern "user32" fn ScreenToClient(hWnd: HWND, lpPoint: *POINT) callconv(.winapi) BOOL;
    extern "user32" fn GetDC(hWnd: HWND) callconv(.winapi) ?HDC;
    extern "user32" fn ReleaseDC(hWnd: HWND, hDC: HDC) callconv(.winapi) i32;
    extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
    extern "user32" fn FillRect(hDC: HDC, lprc: *const RECT, hbr: HBRUSH) callconv(.winapi) i32;
    extern "user32" fn FrameRect(hDC: HDC, lprc: *const RECT, hbr: HBRUSH) callconv(.winapi) i32;
    extern "gdi32" fn CreateSolidBrush(color: COLORREF) callconv(.winapi) ?HBRUSH;
    extern "gdi32" fn DeleteObject(ho: HGDIOBJ) callconv(.winapi) BOOL;
    extern "gdi32" fn GetStockObject(index: i32) callconv(.winapi) ?HGDIOBJ;
    extern "gdi32" fn SetTextColor(hdc: HDC, color: COLORREF) callconv(.winapi) COLORREF;
    extern "gdi32" fn SetBkMode(hdc: HDC, mode: i32) callconv(.winapi) i32;
    extern "gdi32" fn TextOutA(hdc: HDC, x: i32, y: i32, text: [*]const u8, len: i32) callconv(.winapi) BOOL;
};

const male_first_names = [_][]const u8{
    "James", "John", "Robert", "Michael", "David",
    "William", "Richard", "Joseph", "Thomas", "Charles",
};

const female_first_names = [_][]const u8{
    "Mary", "Patricia", "Jennifer", "Linda", "Elizabeth",
    "Barbara", "Susan", "Jessica", "Sarah", "Karen",
};

const last_names = [_][]const u8{
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez",
    "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
};

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

const CaveType = enum {
    top,
    front,
    back,
};

const Connection = struct {
    stick_person_id: usize,
    cave_person_id: usize,
    cave_type: CaveType,
    stick_has_control: bool,
};

const Person = struct {
    id: usize,
    first_name: []const u8,
    last_name: []const u8,
    age: u8,
    kind: PersonType,
    place: Place,
    moods: MoodLevels,
    kinks: KinkLevels,
    skills: SkillLevels,
    owned_by_id: ?usize,
};

const World = struct {
    const place_capacity: usize = 25;

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

fn randomPersonType(random: std.Random) PersonType {
    const person_type: u8 = random.uintLessThan(u8, 100);
    if (person_type < 70) return .male;
    if (person_type < 95) return .female;
    return .futa;
}

fn randomFirstName(kind: PersonType, random: std.Random) []const u8 {
    const names = switch (kind) {
        .male => male_first_names[0..],
        .female, .futa => female_first_names[0..],
    };

    return names[random.uintLessThan(usize, names.len)];
}

fn randomLastName(random: std.Random) []const u8 {
    return last_names[random.uintLessThan(usize, last_names.len)];
}

fn randomAge(random: std.Random) u8 {
    return 14 + random.uintLessThan(u8, 37);
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

fn hasStick(kind: PersonType) bool {
    return kind == .male or kind == .futa;
}

fn hasCaves(kind: PersonType) bool {
    return kind == .female or kind == .futa;
}

fn caveCapacity(skill: u8, cave_type: CaveType) u8 {
    return switch (cave_type) {
        .top => if (skill >= 50) 2 else 1,
        .front, .back => if (skill >= 67) 3 else if (skill >= 34) 2 else 1,
    };
}

fn ownerOwnedPair(person: Person, other: Person) bool {
    return person.owned_by_id == other.id or other.owned_by_id == person.id;
}

fn caveSkillLevel(levels: *const SkillLevels, cave_type: CaveType) u8 {
    return switch (cave_type) {
        .top => levels.top,
        .front => levels.front,
        .back => levels.back,
    };
}

fn caveSkillLevelPtr(levels: *SkillLevels, cave_type: CaveType) *u8 {
    return switch (cave_type) {
        .top => &levels.top,
        .front => &levels.front,
        .back => &levels.back,
    };
}

fn caveKinkLevel(levels: *const KinkLevels, cave_type: CaveType) u8 {
    return switch (cave_type) {
        .top => levels.top,
        .front => levels.front,
        .back => levels.back,
    };
}

fn caveKinkLevelPtr(levels: *KinkLevels, cave_type: CaveType) *u8 {
    return switch (cave_type) {
        .top => &levels.top,
        .front => &levels.front,
        .back => &levels.back,
    };
}

fn controlChance(stick_person: Person, cave_person: Person) f64 {
    const product = @as(f64, @floatFromInt(stick_person.kinks.control)) *
        @as(f64, @floatFromInt(cave_person.kinks.submit));
    return product / 10000.0;
}

fn personHasStickConnection(person_id: usize, connections: []const Connection) bool {
    for (connections) |connection| {
        if (connection.stick_person_id == person_id) {
            return true;
        }
    }

    return false;
}

fn caveOccupancy(person_id: usize, cave_type: CaveType, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (connections) |connection| {
        if (connection.cave_person_id == person_id and connection.cave_type == cave_type) {
            count += 1;
        }
    }

    return count;
}

fn totalCaveCapacity(person: Person) u8 {
    if (!hasCaves(person.kind)) {
        return 0;
    }

    return caveCapacity(person.skills.top, .top) +
        caveCapacity(person.skills.front, .front) +
        caveCapacity(person.skills.back, .back);
}

fn totalCaveOccupancy(person_id: usize, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (connections) |connection| {
        if (connection.cave_person_id == person_id) {
            count += 1;
        }
    }

    return count;
}

fn openCaveSlots(person: Person, connections: []const Connection) u8 {
    const capacity = totalCaveCapacity(person);
    const occupancy = totalCaveOccupancy(person.id, connections);
    return capacity -| occupancy;
}

fn caveHasCapacity(person: Person, cave_type: CaveType, connections: []const Connection) bool {
    if (!hasCaves(person.kind)) {
        return false;
    }

    return caveOccupancy(person.id, cave_type, connections) < caveCapacity(caveSkillLevel(&person.skills, cave_type), cave_type);
}

fn personHasAnyConnection(person_id: usize, connections: []const Connection) bool {
    for (connections) |connection| {
        if (connection.stick_person_id == person_id or connection.cave_person_id == person_id) {
            return true;
        }
    }

    return false;
}

fn personConnectionCount(person_id: usize, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (connections) |connection| {
        if (connection.stick_person_id == person_id or connection.cave_person_id == person_id) {
            count += 1;
        }
    }

    return count;
}

fn canStickConnectToCave(stick_person: Person, cave_person: Person, connections: []const Connection) bool {
    if (stick_person.id == cave_person.id or stick_person.place != cave_person.place) {
        return false;
    }

    if (!hasStick(stick_person.kind) or !hasCaves(cave_person.kind)) {
        return false;
    }

    if (personHasStickConnection(stick_person.id, connections)) {
        return false;
    }

    return openCaveSlots(cave_person, connections) > 0;
}

fn personCanAttemptConnection(person: Person, other: Person, connections: []const Connection) bool {
    if (!canStickConnectToCave(person, other, connections) and !canStickConnectToCave(other, person, connections)) {
        return false;
    }

    if (ownerOwnedPair(person, other)) {
        return true;
    }

    return person.moods.energy >= 50 and other.moods.energy >= 50;
}

fn connectablePeopleCount(person: Person, people: []const Person, connections: []const Connection) u8 {
    var count: u8 = 0;
    for (people) |other| {
        if (personCanAttemptConnection(person, other, connections)) {
            count += 1;
        }
    }

    return count;
}

const ConnectionProposal = struct {
    stick_person_id: usize,
    cave_person_id: usize,
    cave_type: CaveType,
};

const cave_types = [_]CaveType{ .top, .front, .back };

fn appendAvailableCaveProposals(
    proposals: *std.ArrayList(ConnectionProposal),
    stick_person: Person,
    cave_person: Person,
    connections: []const Connection,
    allocator: std.mem.Allocator,
) !void {
    if (!canStickConnectToCave(stick_person, cave_person, connections)) {
        return;
    }

    for (cave_types) |cave_type| {
        if (!caveHasCapacity(cave_person, cave_type, connections)) {
            continue;
        }

        try proposals.append(allocator, .{
            .stick_person_id = stick_person.id,
            .cave_person_id = cave_person.id,
            .cave_type = cave_type,
        });
    }
}

fn chooseConnectionProposal(
    person: Person,
    other: Person,
    connections: []const Connection,
    random: std.Random,
    allocator: std.mem.Allocator,
) !?ConnectionProposal {
    var proposals = std.ArrayList(ConnectionProposal){};
    defer proposals.deinit(allocator);

    try appendAvailableCaveProposals(&proposals, person, other, connections, allocator);
    try appendAvailableCaveProposals(&proposals, other, person, connections, allocator);

    if (proposals.items.len == 0) {
        return null;
    }

    var total_weight: f64 = 0;
    var weights = try allocator.alloc(f64, proposals.items.len);
    defer allocator.free(weights);

    for (proposals.items, 0..) |proposal, i| {
        const stick_person = if (proposal.stick_person_id == person.id) person else other;
        const cave_person = if (proposal.cave_person_id == person.id) person else other;

        const weight = if (ownerOwnedPair(person, other))
            blk: {
                const owner = if (other.owned_by_id == person.id) person else other;
                break :blk @as(f64, @floatFromInt(caveKinkLevel(&owner.kinks, proposal.cave_type))) / 100.0;
            }
        else blk: {
            const stick_weight = (@as(f64, @floatFromInt(caveKinkLevel(&stick_person.kinks, proposal.cave_type))) / 100.0) * 0.5;
            const cave_weight = (@as(f64, @floatFromInt(caveKinkLevel(&cave_person.kinks, proposal.cave_type))) / 100.0) * 0.25;
            break :blk stick_weight * cave_weight;
        };

        weights[i] = weight;
        total_weight += weight;
    }

    if (total_weight <= 0) {
        return proposals.items[0];
    }

    var roll = random.float(f64) * total_weight;
    for (proposals.items, 0..) |proposal, i| {
        roll -= weights[i];
        if (roll <= 0) {
            return proposal;
        }
    }

    return proposals.items[proposals.items.len - 1];
}

fn clearAllConnectionsForPerson(world: *World, person_id: usize) void {
    var i: usize = 0;
    while (i < world.connections.items.len) {
        const connection = world.connections.items[i];
        if (connection.stick_person_id != person_id and connection.cave_person_id != person_id) {
            i += 1;
            continue;
        }

        const stick = findPersonById(world.people.items, connection.stick_person_id);
        const cave = findPersonById(world.people.items, connection.cave_person_id);
        if (stick) |stick_person| {
            if (findPersonIndexById(world.people.items, stick_person.id)) |index| {
                world.people.items[index].moods.warm = 0;
            }
        }
        if (cave) |cave_person| {
            if (findPersonIndexById(world.people.items, cave_person.id)) |index| {
                world.people.items[index].moods.warm = 0;
            }
        }

        if (stick != null and cave != null) {
            std.debug.print("Tick: {s} {s} disconnected from {s} {s} ({s}, control {s}); warm reset to 0\n", .{
                stick.?.first_name,
                stick.?.last_name,
                cave.?.first_name,
                cave.?.last_name,
                @tagName(connection.cave_type),
                if (connection.stick_has_control) "yes" else "no",
            });
        }

        _ = world.connections.swapRemove(i);
    }
}

fn updateConnectionActivity(world: *World, random: std.Random, allocator: std.mem.Allocator) !void {
    for (world.connections.items) |connection| {
        const stick_index = findPersonIndexById(world.people.items, connection.stick_person_id) orelse continue;
        const cave_index = findPersonIndexById(world.people.items, connection.cave_person_id) orelse continue;

        world.people.items[stick_index].moods.energy = world.people.items[stick_index].moods.energy -| 3;
        world.people.items[cave_index].moods.energy = world.people.items[cave_index].moods.energy -| 3;

        increaseConnectionHappiness(world, stick_index, cave_index);
        increaseConnectionHappiness(world, cave_index, stick_index);
    }

    for (world.people.items, 0..) |person, i| {
        const connection_count = personConnectionCount(person.id, world.connections.items);
        if (connection_count == 0) {
            world.people.items[i].moods.energy = clampStat(@as(u16, person.moods.energy) + 2);
            const increase = connectablePeopleCount(person, world.people.items, world.connections.items);
            world.people.items[i].moods.warm = clampStat(@as(u16, person.moods.warm) + increase);
            continue;
        }

        if (personEndsConnectionsFromEnergy(person.id, world.connections.items) and world.people.items[i].moods.energy == 0) {
            clearAllConnectionsForPerson(world, person.id);
            continue;
        }

        if (personHasStickConnection(person.id, world.connections.items)) {
            if (findStickConnection(world.connections.items, person.id)) |connection| {
                const skill = caveSkillLevelPtr(&world.people.items[i].skills, connection.cave_type);
                skill.* = clampStat(@as(u16, skill.*) + 2);

                if (connection.stick_has_control) {
                    world.people.items[i].skills.control = clampStat(@as(u16, world.people.items[i].skills.control) + 1);
                }

                if (random.boolean()) {
                    const kink = caveKinkLevelPtr(&world.people.items[i].kinks, connection.cave_type);
                    kink.* = clampStat(@as(u16, kink.*) + 1);
                }
            }
        }

        if (hasCaves(person.kind)) {
            for (cave_types) |cave_type| {
                const occupancy = caveOccupancy(person.id, cave_type, world.connections.items);
                if (occupancy == 0) {
                    continue;
                }

                const skill = caveSkillLevelPtr(&world.people.items[i].skills, cave_type);
                skill.* = clampStat(@as(u16, skill.*) + (@as(u16, occupancy) * 2));

                var controlled_occupancy: u8 = 0;
                for (world.connections.items) |connection| {
                    if (connection.cave_person_id == person.id and connection.cave_type == cave_type and connection.stick_has_control) {
                        controlled_occupancy += 1;
                    }
                }
                if (controlled_occupancy > 0) {
                    world.people.items[i].skills.submit = clampStat(@as(u16, world.people.items[i].skills.submit) + controlled_occupancy);
                }

                if (random.boolean()) {
                    const kink = caveKinkLevelPtr(&world.people.items[i].kinks, cave_type);
                    kink.* = clampStat(@as(u16, kink.*) + occupancy);
                }
            }
        }
    }

    for (world.people.items) |person| {
        if (!personHasStickConnection(person.id, world.connections.items) and openCaveSlots(person, world.connections.items) == 0) {
            continue;
        }

        for (world.people.items) |other| {
            if (person.id == other.id) {
                continue;
            }

            if (!personCanAttemptConnection(person, other, world.connections.items)) {
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

            const proposal = (try chooseConnectionProposal(person, other, world.connections.items, random, allocator)) orelse continue;
            const stick = findPersonById(world.people.items, proposal.stick_person_id) orelse continue;
            const cave = findPersonById(world.people.items, proposal.cave_person_id) orelse continue;
            const stick_has_control = ownerOwnedPair(person, other) or random.float(f64) < controlChance(stick, cave);
            try world.connections.append(allocator, .{
                .stick_person_id = proposal.stick_person_id,
                .cave_person_id = proposal.cave_person_id,
                .cave_type = proposal.cave_type,
                .stick_has_control = stick_has_control,
            });

            std.debug.print("Tick: {s} {s} connected to {s} {s} ({s}, control {s})\n", .{
                stick.first_name,
                stick.last_name,
                cave.first_name,
                cave.last_name,
                @tagName(proposal.cave_type),
                if (stick_has_control) "yes" else "no",
            });
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

fn findPersonById(people: []const Person, person_id: usize) ?Person {
    for (people) |person| {
        if (person.id == person_id) return person;
    }
    return null;
}

fn findPersonIndexById(people: []const Person, person_id: usize) ?usize {
    for (people, 0..) |person, index| {
        if (person.id == person_id) return index;
    }
    return null;
}

fn findStickConnection(connections: []const Connection, person_id: usize) ?Connection {
    for (connections) |connection| {
        if (connection.stick_person_id == person_id) {
            return connection;
        }
    }

    return null;
}

fn increaseConnectionHappiness(world: *World, primary_index: usize, other_index: usize) void {
    const boosted = clampStat(@as(u16, world.people.items[primary_index].moods.happiness) + 10);
    world.people.items[primary_index].moods.happiness = boosted;

    if (boosted < 100) {
        return;
    }

    world.people.items[primary_index].moods.happiness = 0;
    world.people.items[primary_index].moods.happiness = clampStat(@as(u16, world.people.items[primary_index].moods.happiness) + 10);
    world.people.items[other_index].moods.happiness = clampStat(@as(u16, world.people.items[other_index].moods.happiness) + 10);
}

fn personEndsConnectionsFromEnergy(person_id: usize, connections: []const Connection) bool {
    for (connections) |connection| {
        if (connection.stick_person_id == person_id) {
            return true;
        }

        if (connection.cave_person_id == person_id and !connection.stick_has_control) {
            return true;
        }
    }

    return false;
}

const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + self.w and py >= self.y and py < self.y + self.h;
    }
};

const UiState = struct {
    paused: bool = false,
    dark_mode: bool = false,
    selected_place: ?Place = null,
};

const Theme = struct {
    background: win.COLORREF,
    button: win.COLORREF,
    button_hover: win.COLORREF,
    panel: win.COLORREF,
    text: win.COLORREF,
    border: win.COLORREF,
};

fn currentTheme(dark_mode: bool) Theme {
    if (dark_mode) {
        return .{
            .background = rgb(24, 28, 35),
            .button = rgb(58, 66, 78),
            .button_hover = rgb(82, 92, 108),
            .panel = rgb(36, 46, 60),
            .text = rgb(235, 239, 244),
            .border = rgb(112, 122, 138),
        };
    }

    return .{
        .background = rgb(255, 255, 255),
        .button = rgb(230, 230, 230),
        .button_hover = rgb(204, 204, 204),
        .panel = rgb(173, 216, 230),
        .text = rgb(0, 0, 0),
        .border = rgb(0, 0, 0),
    };
}

fn worldReset(world: *World) void {
    world.people.clearRetainingCapacity();
    world.connections.clearRetainingCapacity();
    world.place_population = [_]usize{0} ** 10;
    world.male_count = 0;
    world.female_count = 0;
    world.futa_count = 0;
}

fn stepSimulation(world: *World, tick: *u64, random: std.Random, allocator: std.mem.Allocator) !void {
    tick.* += 1;
    const kind = randomPersonType(random);
    const place = randomPlace(random);
    const new_person = Person{
        .id = world.totalPeople() + 1,
        .first_name = randomFirstName(kind, random),
        .last_name = randomLastName(random),
        .age = randomAge(random),
        .kind = kind,
        .place = place,
        .moods = randomMoodLevels(random),
        .kinks = randomKinkLevels(random),
        .skills = randomSkillLevels(random),
        .owned_by_id = randomOwnedById(kind, place, world.people.items, random),
    };

    _ = try world.addPerson(new_person, allocator);
    if (tick.* % 10 == 0) {
        try updateConnectionActivity(world, random, allocator);
    }
}

fn rgb(r: u8, g: u8, b: u8) win.COLORREF {
    return @as(win.COLORREF, r) | (@as(win.COLORREF, g) << 8) | (@as(win.COLORREF, b) << 16);
}

fn toWinRect(rect: Rect) win.RECT {
    return .{
        .left = rect.x,
        .top = rect.y,
        .right = rect.x + rect.w,
        .bottom = rect.y + rect.h,
    };
}

fn fillRectColor(hdc: win.HDC, rect: Rect, color: win.COLORREF) void {
    const brush = win.CreateSolidBrush(color) orelse return;
    defer _ = win.DeleteObject(@ptrCast(brush));
    var win_rect = toWinRect(rect);
    _ = win.FillRect(hdc, &win_rect, brush);
}

fn drawText(hdc: win.HDC, x: i32, y: i32, text: []const u8) void {
    _ = win.TextOutA(hdc, x, y, text.ptr, @as(i32, @intCast(text.len)));
}

fn drawTextColored(hdc: win.HDC, x: i32, y: i32, text: []const u8, color: win.COLORREF) void {
    _ = win.SetTextColor(hdc, color);
    _ = win.SetBkMode(hdc, win.TRANSPARENT);
    drawText(hdc, x, y, text);
}

fn drawFrame(hdc: win.HDC, rect: Rect, fill: win.COLORREF, border: win.COLORREF) void {
    fillRectColor(hdc, rect, fill);

    const border_brush = win.CreateSolidBrush(border) orelse return;
    defer _ = win.DeleteObject(@ptrCast(border_brush));
    var border_rect = toWinRect(rect);
    _ = win.FrameRect(hdc, &border_rect, border_brush);
}

fn drawButton(hdc: win.HDC, rect: Rect, label: []const u8, hovered: bool, theme: Theme) void {
    drawFrame(hdc, rect, if (hovered) theme.button_hover else theme.button, theme.border);
    drawTextColored(hdc, rect.x + 10, rect.y + 10, label, theme.text);
}

fn clampI32(value: i32, min_value: i32, max_value: i32) i32 {
    return @max(min_value, @min(value, max_value));
}

fn formatMoodLevels(buf: []u8, moods: MoodLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "MoodLevels: warm {d}  energy {d}  happiness {d}", .{
        moods.warm,
        moods.energy,
        moods.happiness,
    });
}

fn formatKinkLevelsPrimary(buf: []u8, kinks: KinkLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "KinkLevels: top {d}  front {d}  back {d}  wet {d}  covered {d}", .{
        kinks.top,
        kinks.front,
        kinks.back,
        kinks.wet,
        kinks.covered,
    });
}

fn formatKinkLevelsSecondary(buf: []u8, kinks: KinkLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "            deep {d}  rough {d}  submit {d}  control {d}", .{
        kinks.deep,
        kinks.rough,
        kinks.submit,
        kinks.control,
    });
}

fn formatSkillLevelsPrimary(buf: []u8, skills: SkillLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "SkillLevels: top {d}  front {d}  back {d}  wet {d}  covered {d}", .{
        skills.top,
        skills.front,
        skills.back,
        skills.wet,
        skills.covered,
    });
}

fn formatSkillLevelsSecondary(buf: []u8, skills: SkillLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "             deep {d}  rough {d}  submit {d}  control {d}", .{
        skills.deep,
        skills.rough,
        skills.submit,
        skills.control,
    });
}

fn formatOwnedPeople(buf: []u8, owner_id: usize, people: []const Person) ![]const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer();
    var found_any = false;

    for (people) |other| {
        if (other.owned_by_id != owner_id) continue;

        if (found_any) {
            try writer.writeAll(", ");
        }

        try writer.print("{s} {s}", .{ other.first_name, other.last_name });
        found_any = true;
    }

    if (!found_any) {
        try writer.writeAll("no one");
    }

    return stream.getWritten();
}

fn formatAnatomy(buf: []u8, person: Person, connections: []const Connection) ![]const u8 {
    const stick_state = if (hasStick(person.kind))
        if (personHasStickConnection(person.id, connections)) "busy" else "free"
    else
        "none";

    return std.fmt.bufPrint(buf, "Stick: {s}  Cave slots open: {d}/{d}", .{
        stick_state,
        openCaveSlots(person, connections),
        totalCaveCapacity(person),
    });
}

fn personHasControlledCaveConnection(person_id: usize, connections: []const Connection) bool {
    for (connections) |connection| {
        if (connection.cave_person_id == person_id and connection.stick_has_control) {
            return true;
        }
    }

    return false;
}

fn drawPersonTooltip(
    hdc: win.HDC,
    client_rect: win.RECT,
    mouse_x: i32,
    mouse_y: i32,
    person: Person,
    people: []const Person,
    connections: []const Connection,
    theme: Theme,
) !void {
    const tooltip_w: i32 = 540;
    const tooltip_h: i32 = 228;
    const line_height: i32 = 18;
    const tooltip_x = clampI32(mouse_x + 18, 10, client_rect.right - tooltip_w - 10);
    const tooltip_y = clampI32(mouse_y + 18, 10, client_rect.bottom - tooltip_h - 10);
    const tooltip_rect = Rect{ .x = tooltip_x, .y = tooltip_y, .w = tooltip_w, .h = tooltip_h };

    drawFrame(hdc, tooltip_rect, theme.panel, theme.border);

    var y = tooltip_rect.y + 10;

    var name_buf: [96]u8 = undefined;
    const name_line = try std.fmt.bufPrint(&name_buf, "{s} {s}", .{ person.first_name, person.last_name });
    drawTextColored(hdc, tooltip_rect.x + 10, y, name_line, theme.text);
    y += line_height;

    var identity_buf: [128]u8 = undefined;
    const identity_line = try std.fmt.bufPrint(&identity_buf, "Age {d}  Type {s}  ID #{d}", .{ person.age, person.kind.asString(), person.id });
    drawTextColored(hdc, tooltip_rect.x + 10, y, identity_line, theme.text);
    y += line_height;

    var moods_buf: [128]u8 = undefined;
    const moods_line = try formatMoodLevels(&moods_buf, person.moods);
    drawTextColored(hdc, tooltip_rect.x + 10, y, moods_line, theme.text);
    y += line_height;

    var kinks_primary_buf: [160]u8 = undefined;
    const kinks_primary_line = try formatKinkLevelsPrimary(&kinks_primary_buf, person.kinks);
    drawTextColored(hdc, tooltip_rect.x + 10, y, kinks_primary_line, theme.text);
    y += line_height;

    var kinks_secondary_buf: [128]u8 = undefined;
    const kinks_secondary_line = try formatKinkLevelsSecondary(&kinks_secondary_buf, person.kinks);
    drawTextColored(hdc, tooltip_rect.x + 10, y, kinks_secondary_line, theme.text);
    y += line_height;

    var skills_primary_buf: [160]u8 = undefined;
    const skills_primary_line = try formatSkillLevelsPrimary(&skills_primary_buf, person.skills);
    drawTextColored(hdc, tooltip_rect.x + 10, y, skills_primary_line, theme.text);
    y += line_height;

    var skills_secondary_buf: [128]u8 = undefined;
    const skills_secondary_line = try formatSkillLevelsSecondary(&skills_secondary_buf, person.skills);
    drawTextColored(hdc, tooltip_rect.x + 10, y, skills_secondary_line, theme.text);
    y += line_height;

    var anatomy_buf: [160]u8 = undefined;
    const anatomy_line = try formatAnatomy(&anatomy_buf, person, connections);
    drawTextColored(hdc, tooltip_rect.x + 10, y, anatomy_line, theme.text);
    y += line_height;

    var connection_buf: [160]u8 = undefined;
    const connection_line = try std.fmt.bufPrint(&connection_buf, "Active connections: {d}  Controlled: {s}", .{
        personConnectionCount(person.id, connections),
        if (personHasControlledCaveConnection(person.id, connections)) "yes" else "no",
    });
    drawTextColored(hdc, tooltip_rect.x + 10, y, connection_line, theme.text);
    y += line_height;

    var owner_buf: [160]u8 = undefined;
    const owner_line = if (person.owned_by_id) |owner_id| blk: {
        const owner = findPersonById(people, owner_id) orelse
            break :blk try std.fmt.bufPrint(&owner_buf, "Owned: yes, by unknown owner", .{});
        break :blk try std.fmt.bufPrint(&owner_buf, "Owned: yes, by {s} {s}", .{ owner.first_name, owner.last_name });
    } else try std.fmt.bufPrint(&owner_buf, "Owned: no", .{});
    drawTextColored(hdc, tooltip_rect.x + 10, y, owner_line, theme.text);
    y += line_height;

    var owned_buf: [256]u8 = undefined;
    const owned_names = try formatOwnedPeople(&owned_buf, person.id, people);

    var owns_line_buf: [288]u8 = undefined;
    const owns_line = try std.fmt.bufPrint(&owns_line_buf, "Owns: {s}", .{owned_names});
    drawTextColored(hdc, tooltip_rect.x + 10, y, owns_line, theme.text);
}

fn wndProc(hwnd: ?win.HWND, msg: win.UINT, w_param: win.WPARAM, l_param: win.LPARAM) callconv(.winapi) win.LRESULT {
    switch (msg) {
        win.WM_DESTROY => {
            win.PostQuitMessage(0);
            return 0;
        },
        else => return win.DefWindowProcA(hwnd, msg, w_param, l_param),
    }
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
    var world = World.init();
    defer world.deinit(allocator);

    const h_instance = win.GetModuleHandleA(null);
    var wc: win.WNDCLASSA = std.mem.zeroes(win.WNDCLASSA);
    wc.style = win.CS_HREDRAW | win.CS_VREDRAW;
    wc.lpfnWndProc = wndProc;
    wc.hInstance = h_instance;
    wc.lpszClassName = "ZigGameWindowClass";
    wc.hCursor = win.LoadCursorA(null, win.IDC_ARROW);

    if (wc.hCursor == null) return error.LoadCursorFailed;
    if (win.RegisterClassA(&wc) == 0) return error.RegisterClassFailed;

    const hwnd = win.CreateWindowExA(
        0,
        wc.lpszClassName,
        "Zig World UI",
        win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
        win.CW_USEDEFAULT,
        win.CW_USEDEFAULT,
        1200,
        800,
        null,
        null,
        h_instance,
        null,
    ) orelse return error.WindowCreateFailed;

    var seed: u64 = undefined;
    try std.posix.getrandom(std.mem.asBytes(&seed));
    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    var ui = UiState{};
    var tick: u64 = 0;
    var last_step_ms = std.time.milliTimestamp();
    var should_quit = false;

    while (!should_quit) {
        var msg: win.MSG = undefined;
        var click_pos: ?struct { x: i32, y: i32 } = null;

        while (win.PeekMessageA(&msg, null, 0, 0, win.PM_REMOVE) != 0) {
            if (msg.message == win.WM_QUIT) {
                should_quit = true;
                break;
            }

            if (msg.message == win.WM_LBUTTONDOWN) {
                var cursor: win.POINT = undefined;
                _ = win.GetCursorPos(&cursor);
                _ = win.ScreenToClient(hwnd, &cursor);
                click_pos = .{ .x = cursor.x, .y = cursor.y };
            }

            _ = win.TranslateMessage(&msg);
            _ = win.DispatchMessageA(&msg);
        }

        var cursor: win.POINT = undefined;
        _ = win.GetCursorPos(&cursor);
        _ = win.ScreenToClient(hwnd, &cursor);
        const mouse_x = cursor.x;
        const mouse_y = cursor.y;

        var client_rect: win.RECT = undefined;
        _ = win.GetClientRect(hwnd, &client_rect);

        const pause_rect = Rect{ .x = 20, .y = 20, .w = 110, .h = 35 };
        const reset_rect = Rect{ .x = 145, .y = 20, .w = 90, .h = 35 };
        const back_rect = Rect{ .x = 20, .y = 70, .w = 90, .h = 35 };
        const dark_mode_rect = Rect{ .x = client_rect.right - 150, .y = 20, .w = 130, .h = 35 };
        const pause_hovered = pause_rect.contains(mouse_x, mouse_y);
        const reset_hovered = reset_rect.contains(mouse_x, mouse_y);
        const back_hovered = back_rect.contains(mouse_x, mouse_y);
        const dark_mode_hovered = dark_mode_rect.contains(mouse_x, mouse_y);
        const theme = currentTheme(ui.dark_mode);

        if (click_pos) |click| {
            if (dark_mode_rect.contains(click.x, click.y)) {
                ui.dark_mode = !ui.dark_mode;
            } else if (pause_rect.contains(click.x, click.y)) {
                ui.paused = !ui.paused;
            } else if (reset_rect.contains(click.x, click.y)) {
                worldReset(&world);
                tick = 0;
                ui.selected_place = null;
                last_step_ms = std.time.milliTimestamp();
            } else if (ui.selected_place != null and back_rect.contains(click.x, click.y)) {
                ui.selected_place = null;
            }
        }

        if (!ui.paused and std.time.milliTimestamp() - last_step_ms >= 1000) {
            try stepSimulation(&world, &tick, random, allocator);
            last_step_ms += 1000;
        }

        const hdc = win.GetDC(hwnd) orelse return error.GetDeviceContextFailed;
        defer _ = win.ReleaseDC(hwnd, hdc);

        const bg = win.CreateSolidBrush(theme.background) orelse return error.CreateBrushFailed;
        defer _ = win.DeleteObject(@ptrCast(bg));
        _ = win.FillRect(hdc, &client_rect, bg);

        drawButton(hdc, pause_rect, if (ui.paused) "Play" else "Pause", pause_hovered, theme);
        drawButton(hdc, reset_rect, "Reset", reset_hovered, theme);
        drawButton(hdc, dark_mode_rect, if (ui.dark_mode) "Light Mode" else "Dark Mode", dark_mode_hovered, theme);

        var status_buf: [128]u8 = undefined;
        const status = try std.fmt.bufPrint(&status_buf, "Tick: {d}  Total: {d}", .{ tick, world.totalPeople() });
        drawTextColored(hdc, 260, 30, status, theme.text);

        if (ui.selected_place) |selected_place| {
            drawButton(hdc, back_rect, "Back", back_hovered, theme);
            drawTextColored(hdc, 130, 80, selected_place.asString(), theme.text);

            drawTextColored(hdc, 20, 130, "People in place:", theme.text);
            var y_people: i32 = 155;
            var hovered_person: ?Person = null;
            for (world.people.items) |person| {
                if (person.place != selected_place) continue;
                const person_rect = Rect{ .x = 24, .y = y_people - 2, .w = 560, .h = 18 };
                if (person_rect.contains(mouse_x, mouse_y)) {
                    hovered_person = person;
                }
                var person_buf: [220]u8 = undefined;
                const person_line = try std.fmt.bufPrint(&person_buf, "#{d} {s} {s}, age {d} ({s})", .{ person.id, person.first_name, person.last_name, person.age, person.kind.asString() });
                drawTextColored(hdc, 30, y_people, person_line, theme.text);
                y_people += 18;
            }

            drawTextColored(hdc, 620, 130, "Current connections:", theme.text);
            var y_conn: i32 = 155;
            for (world.connections.items) |connection| {
                const stick = findPersonById(world.people.items, connection.stick_person_id) orelse continue;
                const cave = findPersonById(world.people.items, connection.cave_person_id) orelse continue;
                if (stick.place != selected_place or cave.place != selected_place) continue;

                var conn_type_buf: [48]u8 = undefined;
                const conn_type = if (connection.stick_has_control)
                    try std.fmt.bufPrint(&conn_type_buf, "{s}, control", .{@tagName(connection.cave_type)})
                else
                    @tagName(connection.cave_type);

                var conn_buf: [240]u8 = undefined;
                const conn_line = try std.fmt.bufPrint(&conn_buf, "{s} {s} -> {s} {s} ({s})", .{
                    stick.first_name,
                    stick.last_name,
                    cave.first_name,
                    cave.last_name,
                    conn_type,
                });
                drawTextColored(hdc, 630, y_conn, conn_line, theme.text);
                y_conn += 18;
            }

            if (hovered_person) |person| {
                try drawPersonTooltip(hdc, client_rect, mouse_x, mouse_y, person, world.people.items, world.connections.items, theme);
            }
        } else {
            var hovered_place: ?Place = null;
            var place_index: usize = 0;
            for (std.enums.values(Place)) |place| {
                const col = @as(i32, @intCast(place_index % 2));
                const row = @as(i32, @intCast(place_index / 2));
                const rect = Rect{ .x = 20 + col * 360, .y = 120 + row * 110, .w = 330, .h = 90 };
                const is_hovered = rect.contains(mouse_x, mouse_y);
                if (is_hovered) hovered_place = place;
                drawButton(hdc, rect, place.asString(), is_hovered, theme);

                var pop_buf: [96]u8 = undefined;
                const pop_text = try std.fmt.bufPrint(&pop_buf, "Population: {d}/{d}", .{ world.place_population[@intFromEnum(place)], World.place_capacity });
                drawTextColored(hdc, rect.x + 10, rect.y + 45, pop_text, theme.text);

                if (click_pos) |click| {
                    if (rect.contains(click.x, click.y)) {
                        ui.selected_place = place;
                    }
                }
                place_index += 1;
            }

            if (hovered_place) |place| {
                const panel = Rect{ .x = 760, .y = 120, .w = 400, .h = 130 };
                drawFrame(hdc, panel, theme.panel, theme.border);
                drawTextColored(hdc, panel.x + 10, panel.y + 10, place.asString(), theme.text);

                var info_buf: [120]u8 = undefined;
                const info = try std.fmt.bufPrint(&info_buf, "Population: {d}   Capacity: {d}", .{ world.place_population[@intFromEnum(place)], World.place_capacity });
                drawTextColored(hdc, panel.x + 10, panel.y + 40, info, theme.text);
                drawTextColored(hdc, panel.x + 10, panel.y + 70, "Click a place to inspect details", theme.text);
            }
        }

        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}
