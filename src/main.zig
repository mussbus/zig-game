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
    first_name: []const u8,
    last_name: []const u8,
    age: u8,
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
    const place_capacity: usize = 25;

    people: std.ArrayList(Person),
    place_population: [10]usize,
    male_count: usize,
    female_count: usize,
    futa_count: usize,

    pub fn init() World {
        return .{
            .people = .{},
            .place_population = [_]usize{0} ** 10,
            .male_count = 0,
            .female_count = 0,
            .futa_count = 0,
        };
    }

    pub fn deinit(self: *World, allocator: std.mem.Allocator) void {
        self.people.deinit(allocator);
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
    return switch (random.uintLessThan(u8, 3)) {
        0 => .male,
        1 => .female,
        else => .futa,
    };
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
    const person_first_name = people[person_index].first_name;
    const person_last_name = people[person_index].last_name;
    people[person_index].moods.warm = 0;
    people[person_index].connecting_to_id = null;
    people[person_index].connection_type = null;

    for (people, 0..) |*other, other_index| {
        if (other_index != person_index and other.id == partner_id) {
            const other_first_name = other.first_name;
            const other_last_name = other.last_name;
            other.moods.warm = 0;
            other.connecting_to_id = null;
            other.connection_type = null;

            std.debug.print("Tick: {s} {s} finished connecting with {s} {s}; warm reset to 0\n", .{ person_first_name, person_last_name, other_first_name, other_last_name });
            std.debug.print("Tick: {s} {s} finished connecting with {s} {s}; warm reset to 0\n", .{ other_first_name, other_last_name, person_first_name, person_last_name });
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

            std.debug.print("Tick: {s} {s} is connecting with {s} {s}\n", .{ person.first_name, person.last_name, other.first_name, other.last_name });

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
            std.debug.print("Tick: {s} {s} connected with {s} {s} ({s})\n", .{ person.first_name, person.last_name, other.first_name, other.last_name, @tagName(connection_type) });
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
        .connecting_to_id = null,
        .connection_type = null,
    };

    _ = try world.addPerson(new_person, allocator);
    if (tick.* % 10 == 0) {
        updateConnectionActivity(world, random);
    }
}

fn findPersonById(people: []const Person, person_id: usize) ?Person {
    for (people) |person| {
        if (person.id == person_id) return person;
    }
    return null;
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

fn drawPersonTooltip(
    hdc: win.HDC,
    client_rect: win.RECT,
    mouse_x: i32,
    mouse_y: i32,
    person: Person,
    people: []const Person,
    theme: Theme,
) !void {
    const tooltip_w: i32 = 540;
    const tooltip_h: i32 = 210;
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

    var connection_buf: [160]u8 = undefined;
    const connection_line = if (person.connecting_to_id) |partner_id| blk: {
        const partner = findPersonById(people, partner_id) orelse
            break :blk try std.fmt.bufPrint(&connection_buf, "Currently connecting: yes (unknown partner)", .{});
        break :blk try std.fmt.bufPrint(&connection_buf, "Currently connecting: yes, with {s} {s} ({s})", .{
            partner.first_name,
            partner.last_name,
            @tagName(person.connection_type orelse .top),
        });
    } else try std.fmt.bufPrint(&connection_buf, "Currently connecting: no", .{});
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
            for (world.people.items) |person| {
                const partner_id = person.connecting_to_id orelse continue;
                if (person.place != selected_place or person.id >= partner_id) continue;
                const partner = findPersonById(world.people.items, partner_id) orelse continue;
                if (partner.place != selected_place) continue;

                var conn_buf: [240]u8 = undefined;
                const conn_line = try std.fmt.bufPrint(&conn_buf, "{s} {s} <-> {s} {s} ({s})", .{ person.first_name, person.last_name, partner.first_name, partner.last_name, @tagName(person.connection_type.?) });
                drawTextColored(hdc, 630, y_conn, conn_line, theme.text);
                y_conn += 18;
            }

            if (hovered_person) |person| {
                try drawPersonTooltip(hdc, client_rect, mouse_x, mouse_y, person, world.people.items, theme);
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
