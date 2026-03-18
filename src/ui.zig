const std = @import("std");
const sim = @import("sim.zig");
const world = @import("world.zig");
const win = @import("win32.zig").win;

const ConnectionGroup = struct {
    cave_person_id: usize,
};

const TooltipStyle = enum {
    solid,
    translucent,
};

const ClickPos = struct {
    x: i32,
    y: i32,
};

const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    inline fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + self.w and py >= self.y and py < self.y + self.h;
    }
};

const UiState = struct {
    paused: bool = false,
    dark_mode: bool = false,
    selected_place: ?world.Place = null,
};

const Theme = struct {
    background: win.COLORREF,
    button: win.COLORREF,
    button_hover: win.COLORREF,
    panel: win.COLORREF,
    text: win.COLORREF,
    border: win.COLORREF,
};

pub fn run(allocator: std.mem.Allocator) !void {
    var world_state = world.World.init();
    defer world_state.deinit(allocator);

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

    try world.prefillPlaces(&world_state, random, allocator);

    var ui = UiState{};
    var tick: u64 = 0;
    var last_step_ms = std.time.milliTimestamp();
    var should_quit = false;

    while (!should_quit) {
        var msg: win.MSG = undefined;
        var click_pos: ?ClickPos = null;

        while (win.PeekMessageA(&msg, null, 0, 0, win.PM_REMOVE) != 0) {
            if (msg.message == win.WM_QUIT) {
                should_quit = true;
                break;
            }

            if (msg.message == win.WM_LBUTTONDOWN) {
                var cursor_click: win.POINT = undefined;
                _ = win.GetCursorPos(&cursor_click);
                _ = win.ScreenToClient(hwnd, &cursor_click);
                click_pos = .{ .x = cursor_click.x, .y = cursor_click.y };
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
                world.reset(&world_state);
                try world.prefillPlaces(&world_state, random, allocator);
                tick = 0;
                ui.selected_place = null;
                last_step_ms = std.time.milliTimestamp();
            } else if (ui.selected_place != null and back_rect.contains(click.x, click.y)) {
                ui.selected_place = null;
            }
        }

        while (!ui.paused and std.time.milliTimestamp() - last_step_ms >= sim.step_interval_ms) {
            try sim.stepSimulation(&world_state, &tick, random, allocator);
            last_step_ms += sim.step_interval_ms;
        }

        const hdc = win.GetDC(hwnd) orelse return error.GetDeviceContextFailed;
        defer _ = win.ReleaseDC(hwnd, hdc);

        const backbuffer_dc = win.CreateCompatibleDC(hdc) orelse return error.GetDeviceContextFailed;
        defer _ = win.DeleteDC(backbuffer_dc);

        const backbuffer_bitmap = win.CreateCompatibleBitmap(hdc, client_rect.right, client_rect.bottom) orelse return error.CreateBrushFailed;
        defer _ = win.DeleteObject(@ptrCast(backbuffer_bitmap));

        const previous_bitmap = win.SelectObject(backbuffer_dc, @ptrCast(backbuffer_bitmap)) orelse return error.CreateBrushFailed;
        defer _ = win.SelectObject(backbuffer_dc, previous_bitmap);

        const bg = win.CreateSolidBrush(theme.background) orelse return error.CreateBrushFailed;
        defer _ = win.DeleteObject(@ptrCast(bg));
        _ = win.FillRect(backbuffer_dc, &client_rect, bg);

        drawButton(backbuffer_dc, pause_rect, if (ui.paused) "Play" else "Pause", pause_hovered, theme);
        drawButton(backbuffer_dc, reset_rect, "Reset", reset_hovered, theme);
        drawButton(backbuffer_dc, dark_mode_rect, if (ui.dark_mode) "Light Mode" else "Dark Mode", dark_mode_hovered, theme);

        var status_buf: [128]u8 = undefined;
        const status = try std.fmt.bufPrint(&status_buf, "Tick: {d}  Total: {d}", .{ tick, world_state.totalPeople() });
        drawTextColored(backbuffer_dc, 260, 30, status, theme.text);

        if (ui.selected_place) |selected_place| {
            try drawPlaceView(backbuffer_dc, client_rect, &world_state, mouse_x, mouse_y, selected_place, back_rect, back_hovered, theme);
        } else {
            try drawOverview(backbuffer_dc, &ui, &world_state, mouse_x, mouse_y, click_pos, theme);
        }

        _ = win.BitBlt(hdc, 0, 0, client_rect.right, client_rect.bottom, backbuffer_dc, 0, 0, win.SRCCOPY);
        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}

fn drawOverview(
    hdc: win.HDC,
    ui: *UiState,
    world_state: *const world.World,
    mouse_x: i32,
    mouse_y: i32,
    click_pos: ?ClickPos,
    theme: Theme,
) !void {
    var hovered_place: ?world.Place = null;
    var place_index: usize = 0;
    for (std.enums.values(world.Place)) |place| {
        const col = @as(i32, @intCast(place_index % 2));
        const row = @as(i32, @intCast(place_index / 2));
        const rect = Rect{ .x = 20 + col * 360, .y = 120 + row * 110, .w = 330, .h = 90 };
        const is_hovered = rect.contains(mouse_x, mouse_y);
        if (is_hovered) hovered_place = place;
        drawButton(hdc, rect, place.asString(), is_hovered, theme);

        var pop_buf: [96]u8 = undefined;
        const pop_text = try std.fmt.bufPrint(&pop_buf, "Population: {d}/{d}", .{ world_state.place_population[@intFromEnum(place)], world.World.place_capacity });
        drawTextColored(hdc, rect.x + 10, rect.y + 45, pop_text, theme.text);

        if (click_pos) |click| {
            if (rect.contains(click.x, click.y)) ui.selected_place = place;
        }
        place_index += 1;
    }

    if (hovered_place) |place| {
        const panel = Rect{ .x = 760, .y = 120, .w = 400, .h = 130 };
        drawFrame(hdc, panel, theme.panel, theme.border);
        drawTextColored(hdc, panel.x + 10, panel.y + 10, place.asString(), theme.text);

        var info_buf: [120]u8 = undefined;
        const info = try std.fmt.bufPrint(&info_buf, "Population: {d}   Capacity: {d}", .{ world_state.place_population[@intFromEnum(place)], world.World.place_capacity });
        drawTextColored(hdc, panel.x + 10, panel.y + 40, info, theme.text);
        drawTextColored(hdc, panel.x + 10, panel.y + 70, "Click a place to inspect details", theme.text);
    }
}

fn drawPlaceView(
    hdc: win.HDC,
    client_rect: win.RECT,
    world_state: *const world.World,
    mouse_x: i32,
    mouse_y: i32,
    selected_place: world.Place,
    back_rect: Rect,
    back_hovered: bool,
    theme: Theme,
) !void {
    drawButton(hdc, back_rect, "Back", back_hovered, theme);
    drawTextColored(hdc, 130, 80, selected_place.asString(), theme.text);

    drawTextColored(hdc, 20, 130, "People in place:", theme.text);
    var y_people: i32 = 155;
    var hovered_person: ?world.Person = null;
    var hovered_person_tooltip_style: TooltipStyle = .solid;
    for (world_state.people.items) |person| {
        if (person.place != selected_place) continue;
        const person_rect = Rect{ .x = 24, .y = y_people - 2, .w = 560, .h = 18 };
        if (person_rect.contains(mouse_x, mouse_y)) {
            hovered_person = person;
            hovered_person_tooltip_style = .solid;
        }
        var person_buf: [256]u8 = undefined;
        const person_line = try std.fmt.bufPrint(&person_buf, "#{d} {s} {s}, age {d}, {d}cm, {s}, {s} hair", .{
            person.id,
            person.first_name,
            person.last_name,
            person.age,
            person.height_cm,
            person.race.asString(),
            person.hair_color_kind.asString(),
        });
        drawTextColored(hdc, 30, y_people, person_line, theme.text);
        y_people += 18;

        var person_meta_buf: [220]u8 = undefined;
        const person_meta_line = try std.fmt.bufPrint(&person_meta_buf, "    {s}  {s} {s}", .{
            person.kind.asString(),
            person.hair_length.asString(),
            person.hair_style.asString(),
        });
        drawTextColored(hdc, 30, y_people, person_meta_line, theme.text);
        y_people += 18;
    }

    drawTextColored(hdc, 620, 130, "Current connections:", theme.text);
    var y_conn: i32 = 155;
    var hovered_connection_group: ?ConnectionGroup = null;
    for (world_state.connections.items, 0..) |connection, connection_index| {
        if (!isConnectionGroupFirstOccurrence(world_state.connections.items, connection_index)) continue;

        const stick = world.findPersonById(world_state.people.items, connection.stick_person_id) orelse continue;
        const cave = world.findPersonById(world_state.people.items, connection.cave_person_id) orelse continue;
        if (stick.place != selected_place or cave.place != selected_place) continue;
        if (cave.kind == .male) continue;

        const group = ConnectionGroup{ .cave_person_id = connection.cave_person_id };
        const connection_rect = Rect{ .x = 624, .y = y_conn - 2, .w = 520, .h = 34 };
        const is_hovered = connection_rect.contains(mouse_x, mouse_y);
        if (is_hovered) {
            hovered_connection_group = group;
            fillRectColor(hdc, connection_rect, theme.button_hover);
        }

        var conn_buf: [256]u8 = undefined;
        const conn_line = try std.fmt.bufPrint(&conn_buf, "{s} {s} ({s}) | connections {d}", .{
            cave.first_name,
            cave.last_name,
            cave.kind.asString(),
            countConnectionGroup(group, world_state.connections.items),
        });
        drawTextColored(hdc, 630, y_conn, conn_line, theme.text);
        drawMoodTriplet(hdc, 910, y_conn, cave.moods, theme);
        drawCaveSpecialMoodBars(hdc, 910, y_conn + 16, cave.moods, theme);
        y_conn += 36;
    }

    const map_label_y = @max(360, y_conn + 20);
    drawTextColored(hdc, 620, map_label_y, "Room map (100x100 units):", theme.text);
    const map_rect = Rect{ .x = 620, .y = map_label_y + 26, .w = 420, .h = 420 };
    drawPlaceMap(hdc, map_rect, world_state, selected_place, mouse_x, mouse_y, &hovered_person, &hovered_person_tooltip_style, theme);
    drawTextColored(hdc, 1055, map_rect.y + 10, "Red: unconnected", theme.text);
    drawTextColored(hdc, 1055, map_rect.y + 30, "Green: connected", theme.text);

    if (hovered_person) |person| {
        try drawPersonTooltip(hdc, client_rect, mouse_x, mouse_y, person, world_state.people.items, world_state.connections.items, hovered_person_tooltip_style, theme);
    }

    if (hovered_connection_group) |group| {
        try drawConnectionGroupTooltip(hdc, client_rect, mouse_x, mouse_y, group, world_state.people.items, world_state.connections.items, .solid, theme);
    }
}

fn rgb(r: u8, g: u8, b: u8) win.COLORREF {
    return @as(win.COLORREF, r) | (@as(win.COLORREF, g) << 8) | (@as(win.COLORREF, b) << 16);
}

fn colorChannel(color: win.COLORREF, shift: u5) u8 {
    return @as(u8, @intCast((color >> shift) & 0xff));
}

fn blendColor(foreground: win.COLORREF, background: win.COLORREF, alpha: f32) win.COLORREF {
    const clamped_alpha = @max(0.0, @min(alpha, 1.0));
    const inv_alpha = 1.0 - clamped_alpha;

    const r = @as(u8, @intFromFloat((@as(f32, @floatFromInt(colorChannel(foreground, 0))) * clamped_alpha) +
        (@as(f32, @floatFromInt(colorChannel(background, 0))) * inv_alpha)));
    const g = @as(u8, @intFromFloat((@as(f32, @floatFromInt(colorChannel(foreground, 8))) * clamped_alpha) +
        (@as(f32, @floatFromInt(colorChannel(background, 8))) * inv_alpha)));
    const b = @as(u8, @intFromFloat((@as(f32, @floatFromInt(colorChannel(foreground, 16))) * clamped_alpha) +
        (@as(f32, @floatFromInt(colorChannel(background, 16))) * inv_alpha)));

    return rgb(r, g, b);
}

fn colorRefFromWorld(color: world.Color) win.COLORREF {
    return rgb(color.r, color.g, color.b);
}

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

fn drawFrameBlended(hdc: win.HDC, rect: Rect, fill: win.COLORREF, alpha: f32, border: win.COLORREF) void {
    const overlay_dc = win.CreateCompatibleDC(hdc) orelse return;
    defer _ = win.DeleteDC(overlay_dc);

    const overlay_bitmap = win.CreateCompatibleBitmap(hdc, rect.w, rect.h) orelse return;
    defer _ = win.DeleteObject(@ptrCast(overlay_bitmap));

    const previous_bitmap = win.SelectObject(overlay_dc, @ptrCast(overlay_bitmap)) orelse return;
    defer _ = win.SelectObject(overlay_dc, previous_bitmap);

    fillRectColor(overlay_dc, .{ .x = 0, .y = 0, .w = rect.w, .h = rect.h }, fill);

    const blend = win.BLENDFUNCTION{
        .BlendOp = win.AC_SRC_OVER,
        .BlendFlags = 0,
        .SourceConstantAlpha = @as(u8, @intFromFloat(@max(0.0, @min(alpha, 1.0)) * 255.0)),
        .AlphaFormat = 0,
    };
    _ = win.AlphaBlend(hdc, rect.x, rect.y, rect.w, rect.h, overlay_dc, 0, 0, rect.w, rect.h, blend);

    const border_brush = win.CreateSolidBrush(border) orelse return;
    defer _ = win.DeleteObject(@ptrCast(border_brush));
    var border_rect = toWinRect(rect);
    _ = win.FrameRect(hdc, &border_rect, border_brush);
}

fn drawButton(hdc: win.HDC, rect: Rect, label: []const u8, hovered: bool, theme: Theme) void {
    drawFrame(hdc, rect, if (hovered) theme.button_hover else theme.button, theme.border);
    drawTextColored(hdc, rect.x + 10, rect.y + 10, label, theme.text);
}

fn drawFilledCircle(hdc: win.HDC, center_x: i32, center_y: i32, radius: i32, color: win.COLORREF) void {
    const brush = win.CreateSolidBrush(color) orelse return;
    defer _ = win.DeleteObject(@ptrCast(brush));

    const pen = win.CreatePen(win.PS_SOLID, 1, color) orelse return;
    defer _ = win.DeleteObject(@ptrCast(pen));

    const previous_brush = win.SelectObject(hdc, @ptrCast(brush)) orelse return;
    defer _ = win.SelectObject(hdc, previous_brush);

    const previous_pen = win.SelectObject(hdc, @ptrCast(pen)) orelse return;
    defer _ = win.SelectObject(hdc, previous_pen);

    _ = win.Ellipse(hdc, center_x - radius, center_y - radius, center_x + radius, center_y + radius);
}

fn drawPersonMarker(hdc: win.HDC, center_x: i32, center_y: i32, radius: i32, person: world.Person, accent: win.COLORREF, theme: Theme, is_hovered: bool) void {
    const accent_color = if (is_hovered) blendColor(accent, theme.panel, 0.5) else accent;
    const skin_color = if (is_hovered) blendColor(colorRefFromWorld(person.skin_color), theme.panel, 0.4) else colorRefFromWorld(person.skin_color);
    const hair_color = if (is_hovered) blendColor(colorRefFromWorld(person.hair_color), theme.panel, 0.35) else colorRefFromWorld(person.hair_color);

    drawFilledCircle(hdc, center_x, center_y, radius + 2, accent_color);
    drawFilledCircle(hdc, center_x, center_y, radius, skin_color);
    drawFilledCircle(hdc, center_x, center_y, @max(1, radius - 1), hair_color);
}

fn clampI32(value: i32, min_value: i32, max_value: i32) i32 {
    return @max(min_value, @min(value, max_value));
}

fn moodColor(value: f32) win.COLORREF {
    const normalized = world.clampStat(value) / 100.0;
    const red = @as(u8, @intFromFloat(255.0 * (1.0 - normalized)));
    const green = @as(u8, @intFromFloat(255.0 * normalized));
    return rgb(red, green, 48);
}

fn drawMoodMeterColored(hdc: win.HDC, x: i32, y: i32, label: []const u8, value: f32, fill_color: win.COLORREF, theme: Theme) void {
    drawTextColored(hdc, x, y, label, theme.text);

    const meter_rect = Rect{ .x = x + 18, .y = y + 2, .w = 54, .h = 12 };
    drawFrame(hdc, meter_rect, theme.button, theme.border);

    const inner_w = meter_rect.w - 2;
    const fill_w = @as(i32, @intFromFloat(@as(f32, @floatFromInt(inner_w)) * (world.clampStat(value) / 100.0)));
    if (fill_w <= 0) return;

    fillRectColor(hdc, .{
        .x = meter_rect.x + 1,
        .y = meter_rect.y + 1,
        .w = fill_w,
        .h = meter_rect.h - 2,
    }, fill_color);
}

fn drawMoodMeter(hdc: win.HDC, x: i32, y: i32, label: []const u8, value: f32, theme: Theme) void {
    drawMoodMeterColored(hdc, x, y, label, value, moodColor(value), theme);
}

fn mapWorldToRect(map_rect: Rect, location: world.Vec2) struct { x: i32, y: i32, radius: i32 } {
    const scale_x = @as(f32, @floatFromInt(map_rect.w)) / world.place_size;
    const scale_y = @as(f32, @floatFromInt(map_rect.h)) / world.place_size;
    const scale = @min(scale_x, scale_y);
    const radius = @max(2, @as(i32, @intFromFloat(world.person_radius * scale)));

    return .{
        .x = map_rect.x + @as(i32, @intFromFloat(location.x * scale)),
        .y = map_rect.y + @as(i32, @intFromFloat(location.y * scale)),
        .radius = radius,
    };
}

fn drawPlaceMap(
    hdc: win.HDC,
    map_rect: Rect,
    world_state: *const world.World,
    selected_place: world.Place,
    mouse_x: i32,
    mouse_y: i32,
    hovered_person: *?world.Person,
    hovered_person_tooltip_style: *TooltipStyle,
    theme: Theme,
) void {
    drawFrame(hdc, map_rect, theme.panel, theme.border);

    for (world_state.people.items) |person| {
        if (person.place != selected_place) continue;

        const mapped = mapWorldToRect(map_rect, person.location);
        if (mouse_x >= mapped.x - mapped.radius and mouse_x <= mapped.x + mapped.radius and
            mouse_y >= mapped.y - mapped.radius and mouse_y <= mapped.y + mapped.radius)
        {
            hovered_person.* = person;
            hovered_person_tooltip_style.* = .translucent;
        }

        const is_connected = world.personConnectionCount(person.id, world_state.connections.items) > 0;
        const base_color = if (is_connected) rgb(52, 188, 92) else rgb(214, 54, 54);
        const is_hovered = hovered_person.* != null and hovered_person.*.?.id == person.id;
        drawPersonMarker(hdc, mapped.x, mapped.y, mapped.radius, person, base_color, theme, is_hovered);
    }
}

fn drawMoodTriplet(hdc: win.HDC, x: i32, y: i32, moods: world.MoodLevels, theme: Theme) void {
    drawMoodMeter(hdc, x, y, "A", moods.aroused, theme);
    drawMoodMeter(hdc, x + 86, y, "E", moods.energy, theme);
    drawMoodMeter(hdc, x + 172, y, "H", moods.happiness, theme);
}

fn drawCaveSpecialMoodBars(hdc: win.HDC, x: i32, y: i32, moods: world.MoodLevels, theme: Theme) void {
    drawMoodMeterColored(hdc, x, y, "W", moods.wet, rgb(255, 244, 170), theme);
    drawMoodMeterColored(hdc, x + 86, y, "C", moods.covered, rgb(255, 255, 255), theme);
}

fn formatSpecialMoods(buf: []u8, moods: world.MoodLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "Special moods: wet {d:.1}  covered {d:.1}", .{
        moods.wet,
        moods.covered,
    });
}

fn formatKinkLevelsPrimary(buf: []u8, kinks: world.KinkLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "KinkLevels: top {d:.1}  front {d:.1}  back {d:.1}  wet {d:.1}  covered {d:.1}", .{
        kinks.top,
        kinks.front,
        kinks.back,
        kinks.wet,
        kinks.covered,
    });
}

fn formatKinkLevelsSecondary(buf: []u8, kinks: world.KinkLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "            deep {d:.1}  rough {d:.1}  submit {d:.1}  control {d:.1}", .{
        kinks.deep,
        kinks.rough,
        kinks.submit,
        kinks.control,
    });
}

fn formatSkillLevelsPrimary(buf: []u8, skills: world.SkillLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "SkillLevels: top {d:.1}  front {d:.1}  back {d:.1}  wet {d:.1}  covered {d:.1}", .{
        skills.top,
        skills.front,
        skills.back,
        skills.wet,
        skills.covered,
    });
}

fn formatSkillLevelsSecondary(buf: []u8, skills: world.SkillLevels) ![]const u8 {
    return std.fmt.bufPrint(buf, "             deep {d:.1}  rough {d:.1}  submit {d:.1}  control {d:.1}", .{
        skills.deep,
        skills.rough,
        skills.submit,
        skills.control,
    });
}

fn formatOwnedPeople(buf: []u8, owner_id: usize, people: []const world.Person) ![]const u8 {
    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer();
    var found_any = false;

    for (people) |other| {
        if (other.owned_by_id != owner_id) continue;

        if (found_any) try writer.writeAll(", ");
        try writer.print("{s} {s}", .{ other.first_name, other.last_name });
        found_any = true;
    }

    if (!found_any) try writer.writeAll("no one");
    return stream.getWritten();
}

fn formatAnatomy(buf: []u8, person: world.Person, connections: []const world.Connection) ![]const u8 {
    const stick_state = if (world.hasStick(person.kind))
        if (world.personHasStickConnection(person.id, connections)) "busy" else "free"
    else
        "none";

    return std.fmt.bufPrint(buf, "Stick: {s}  Cave slots open: {d}/{d}", .{
        stick_state,
        world.openCaveSlots(person, connections),
        world.totalCaveCapacity(person),
    });
}

fn connectionGroupMatches(group: ConnectionGroup, connection: world.Connection) bool {
    return connection.cave_person_id == group.cave_person_id;
}

fn isConnectionGroupFirstOccurrence(connections: []const world.Connection, index: usize) bool {
    const target = connections[index];
    for (connections[0..index]) |existing| {
        if (existing.cave_person_id == target.cave_person_id) return false;
    }
    return true;
}

fn countConnectionGroup(group: ConnectionGroup, connections: []const world.Connection) u8 {
    var count: u8 = 0;
    for (connections) |connection| {
        if (connectionGroupMatches(group, connection)) count += 1;
    }
    return count;
}

fn skillLevelForConnection(person: world.Person, cave_type: world.CaveType, is_cave_person: bool, stick_has_control: bool) f32 {
    if (is_cave_person and stick_has_control) return person.skills.submit;
    return world.caveSkillLevel(&person.skills, cave_type);
}

fn kinkLevelForConnection(person: world.Person, cave_type: world.CaveType, is_cave_person: bool, stick_has_control: bool) f32 {
    if (is_cave_person and stick_has_control) return person.kinks.submit;
    if (!is_cave_person and stick_has_control) return person.kinks.control;
    return world.caveKinkLevel(&person.kinks, cave_type);
}

fn drawConnectionGroupTooltip(
    hdc: win.HDC,
    client_rect: win.RECT,
    mouse_x: i32,
    mouse_y: i32,
    group: ConnectionGroup,
    people: []const world.Person,
    connections: []const world.Connection,
    style: TooltipStyle,
    theme: Theme,
) !void {
    const cave = world.findPersonById(people, group.cave_person_id) orelse return;
    const group_count = countConnectionGroup(group, connections);
    const line_height: i32 = 18;
    const padding: i32 = 10;
    const tooltip_w: i32 = 700;
    const header_lines: i32 = 4;
    const lines_per_connection: i32 = 5;
    const tooltip_h: i32 = padding * 2 + (header_lines + (@as(i32, group_count) * lines_per_connection)) * line_height;
    const tooltip_x = clampI32(mouse_x + 18, 10, client_rect.right - tooltip_w - 10);
    const tooltip_y = clampI32(mouse_y + 18, 10, client_rect.bottom - tooltip_h - 10);
    const tooltip_rect = Rect{ .x = tooltip_x, .y = tooltip_y, .w = tooltip_w, .h = tooltip_h };

    switch (style) {
        .solid => drawFrame(hdc, tooltip_rect, theme.panel, theme.border),
        .translucent => drawFrameBlended(hdc, tooltip_rect, theme.panel, 0.5, theme.border),
    }

    var y = tooltip_rect.y + padding;

    var title_buf: [160]u8 = undefined;
    const title_line = try std.fmt.bufPrint(&title_buf, "Cave target: {s} {s} ({s})", .{ cave.first_name, cave.last_name, cave.kind.asString() });
    drawTextColored(hdc, tooltip_rect.x + padding, y, title_line, theme.text);
    y += line_height;

    var summary_buf: [160]u8 = undefined;
    const summary_line = try std.fmt.bufPrint(&summary_buf, "Stick-Cave connections: {d}", .{group_count});
    drawTextColored(hdc, tooltip_rect.x + padding, y, summary_line, theme.text);
    y += line_height;

    drawTextColored(hdc, tooltip_rect.x + padding, y, "Cave moods", theme.text);
    drawMoodTriplet(hdc, tooltip_rect.x + padding + 96, y, cave.moods, theme);
    y += line_height;

    drawTextColored(hdc, tooltip_rect.x + padding, y, "Cave fluids", theme.text);
    drawCaveSpecialMoodBars(hdc, tooltip_rect.x + padding + 96, y, cave.moods, theme);
    y += line_height;

    var connection_index: u8 = 1;
    for (connections) |connection| {
        if (!connectionGroupMatches(group, connection)) continue;
        const stick = world.findPersonById(people, connection.stick_person_id) orelse continue;

        var type_buf: [256]u8 = undefined;
        const type_line = try std.fmt.bufPrint(&type_buf, "#{d} {s} {s} -> cave {s}  control {s}", .{
            connection_index,
            stick.first_name,
            stick.last_name,
            world.caveTypeLabel(connection.cave_type),
            if (connection.stick_has_control) "yes" else "no",
        });
        drawTextColored(hdc, tooltip_rect.x + padding, y, type_line, theme.text);
        y += line_height;

        drawTextColored(hdc, tooltip_rect.x + padding, y, "Stick moods", theme.text);
        drawMoodTriplet(hdc, tooltip_rect.x + padding + 96, y, stick.moods, theme);
        y += line_height;

        var skill_buf: [320]u8 = undefined;
        const skill_line = try std.fmt.bufPrint(&skill_buf, "Skills  stick {s} {d:.1}  cave {s} {d:.1}", .{
            if (connection.stick_has_control) "control" else world.caveTypeLabel(connection.cave_type),
            skillLevelForConnection(stick, connection.cave_type, false, connection.stick_has_control),
            if (connection.stick_has_control) "submit" else world.caveTypeLabel(connection.cave_type),
            skillLevelForConnection(cave, connection.cave_type, true, connection.stick_has_control),
        });
        drawTextColored(hdc, tooltip_rect.x + padding, y, skill_line, theme.text);
        y += line_height;

        var kink_buf: [320]u8 = undefined;
        const kink_line = try std.fmt.bufPrint(&kink_buf, "Kinks   stick {s} {d:.1}  cave {s} {d:.1}", .{
            if (connection.stick_has_control) "control" else world.caveTypeLabel(connection.cave_type),
            kinkLevelForConnection(stick, connection.cave_type, false, connection.stick_has_control),
            if (connection.stick_has_control) "submit" else world.caveTypeLabel(connection.cave_type),
            kinkLevelForConnection(cave, connection.cave_type, true, connection.stick_has_control),
        });
        drawTextColored(hdc, tooltip_rect.x + padding, y, kink_line, theme.text);
        y += line_height;

        connection_index += 1;
    }
}

fn drawPersonTooltip(
    hdc: win.HDC,
    client_rect: win.RECT,
    mouse_x: i32,
    mouse_y: i32,
    person: world.Person,
    people: []const world.Person,
    connections: []const world.Connection,
    style: TooltipStyle,
    theme: Theme,
) !void {
    const tooltip_w: i32 = 540;
    const tooltip_h: i32 = 336;
    const line_height: i32 = 18;
    const tooltip_x = clampI32(mouse_x + 18, 10, client_rect.right - tooltip_w - 10);
    const tooltip_y = clampI32(mouse_y + 18, 10, client_rect.bottom - tooltip_h - 10);
    const tooltip_rect = Rect{ .x = tooltip_x, .y = tooltip_y, .w = tooltip_w, .h = tooltip_h };

    switch (style) {
        .solid => drawFrame(hdc, tooltip_rect, theme.panel, theme.border),
        .translucent => drawFrameBlended(hdc, tooltip_rect, theme.panel, 0.5, theme.border),
    }

    var y = tooltip_rect.y + 10;

    var name_buf: [96]u8 = undefined;
    const name_line = try std.fmt.bufPrint(&name_buf, "{s} {s}", .{ person.first_name, person.last_name });
    drawTextColored(hdc, tooltip_rect.x + 10, y, name_line, theme.text);
    y += line_height;

    var identity_buf: [128]u8 = undefined;
    const identity_line = try std.fmt.bufPrint(&identity_buf, "Age {d}  Height {d}cm  Type {s}  ID #{d}", .{
        person.age,
        person.height_cm,
        person.kind.asString(),
        person.id,
    });
    drawTextColored(hdc, tooltip_rect.x + 10, y, identity_line, theme.text);
    y += line_height;

    var appearance_buf: [180]u8 = undefined;
    const appearance_line = try std.fmt.bufPrint(&appearance_buf, "Race {s}  Hair {s}, {s}, {s}", .{
        person.race.asString(),
        person.hair_color_kind.asString(),
        person.hair_length.asString(),
        person.hair_style.asString(),
    });
    drawTextColored(hdc, tooltip_rect.x + 10, y, appearance_line, theme.text);
    y += line_height;

    const skin_rect = Rect{ .x = tooltip_rect.x + 10, .y = y + 2, .w = 24, .h = 12 };
    const hair_rect = Rect{ .x = tooltip_rect.x + 144, .y = y + 2, .w = 24, .h = 12 };
    drawFrame(hdc, skin_rect, colorRefFromWorld(person.skin_color), theme.border);
    drawTextColored(hdc, tooltip_rect.x + 42, y, "Skin tone", theme.text);
    drawFrame(hdc, hair_rect, colorRefFromWorld(person.hair_color), theme.border);
    drawTextColored(hdc, tooltip_rect.x + 176, y, "Hair color", theme.text);
    y += line_height;

    var location_buf: [128]u8 = undefined;
    const location_line = try std.fmt.bufPrint(&location_buf, "Location ({d:.1}, {d:.1}) in {s}", .{
        person.location.x,
        person.location.y,
        person.place.asString(),
    });
    drawTextColored(hdc, tooltip_rect.x + 10, y, location_line, theme.text);
    y += line_height;

    drawTextColored(hdc, tooltip_rect.x + 10, y, "Moods", theme.text);
    drawMoodTriplet(hdc, tooltip_rect.x + 82, y, person.moods, theme);
    y += line_height;

    var special_moods_buf: [128]u8 = undefined;
    const special_moods_line = try formatSpecialMoods(&special_moods_buf, person.moods);
    drawTextColored(hdc, tooltip_rect.x + 10, y, special_moods_line, theme.text);
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
        world.personConnectionCount(person.id, connections),
        if (world.personHasControlledCaveConnection(person.id, connections)) "yes" else "no",
    });
    drawTextColored(hdc, tooltip_rect.x + 10, y, connection_line, theme.text);
    y += line_height;

    var owner_buf: [160]u8 = undefined;
    const owner_line = if (person.owned_by_id) |owner_id| blk: {
        const owner = world.findPersonById(people, owner_id) orelse break :blk try std.fmt.bufPrint(&owner_buf, "Owned: yes, by unknown owner", .{});
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
        win.WM_ERASEBKGND => return 1,
        win.WM_DESTROY => {
            win.PostQuitMessage(0);
            return 0;
        },
        else => return win.DefWindowProcA(hwnd, msg, w_param, l_param),
    }
}
