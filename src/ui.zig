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

const I32Point = struct {
    x: i32,
    y: i32,
};

const UiState = struct {
    paused: bool = false,
    dark_mode: bool = false,
    selected_place: ?world.Place = null,
    show_people_list: bool = true,
    show_connections_list: bool = true,
    people_scroll: i32 = 0,
    connections_scroll: i32 = 0,
    filter_modal_open: bool = false,
    gender_dropdown_open: bool = false,
    race_dropdown_open: bool = false,
    selected_gender_mask: u8 = allGenderMask(),
    selected_race_mask: u16 = allRaceMask(),
};

const Theme = struct {
    background: win.COLORREF,
    button: win.COLORREF,
    button_hover: win.COLORREF,
    panel: win.COLORREF,
    text: win.COLORREF,
    border: win.COLORREF,
};

const PlaceViewLayout = struct {
    people_toggle_rect: Rect,
    connections_toggle_rect: Rect,
    filter_button_rect: Rect,
    people_panel_rect: ?Rect,
    connections_panel_rect: ?Rect,
    map_label_pos: I32Point,
    map_rect: Rect,
    legend_pos: I32Point,
};

const FilterModalLayout = struct {
    modal_rect: Rect,
    close_button_rect: Rect,
    gender_button_rect: Rect,
    race_button_rect: Rect,
    gender_dropdown_rect: Rect,
    race_dropdown_rect: Rect,
};

const person_type_options = [_]world.PersonType{ .male, .female, .futa };
const race_options = [_]world.Race{ .african, .east_asian, .european, .latino, .middle_eastern, .south_asian, .native_american, .pacific_islander, .mixed };

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
        var wheel_delta: i32 = 0;

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
            } else if (msg.message == win.WM_MOUSEWHEEL) {
                wheel_delta += wheelDeltaFromWParam(msg.wParam);
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
                ui.people_scroll = 0;
                ui.connections_scroll = 0;
                last_step_ms = std.time.milliTimestamp();
            } else if (ui.selected_place != null and back_rect.contains(click.x, click.y)) {
                ui.selected_place = null;
                ui.people_scroll = 0;
                ui.connections_scroll = 0;
                ui.filter_modal_open = false;
                ui.gender_dropdown_open = false;
                ui.race_dropdown_open = false;
            } else if (ui.selected_place != null) {
                const layout = layoutPlaceView(client_rect, ui);
                if (ui.filter_modal_open) {
                    handleFilterModalClick(&ui, &world_state, client_rect, click);
                    clampPlaceViewScroll(&ui, &world_state, ui.selected_place.?, client_rect);
                } else if (layout.people_toggle_rect.contains(click.x, click.y)) {
                    ui.show_people_list = !ui.show_people_list;
                    clampPlaceViewScroll(&ui, &world_state, ui.selected_place.? , client_rect);
                } else if (layout.filter_button_rect.contains(click.x, click.y)) {
                    ui.filter_modal_open = true;
                    ui.gender_dropdown_open = false;
                    ui.race_dropdown_open = false;
                } else if (layout.connections_toggle_rect.contains(click.x, click.y)) {
                    ui.show_connections_list = !ui.show_connections_list;
                    clampPlaceViewScroll(&ui, &world_state, ui.selected_place.? , client_rect);
                }
            }
        }

        if (ui.selected_place) |selected_place| {
            if (wheel_delta != 0 and !ui.filter_modal_open) {
                const layout = layoutPlaceView(client_rect, ui);
                const wheel_steps = @divTrunc(wheel_delta, 120);
                const scroll_amount = -wheel_steps * 36;

                if (scroll_amount != 0) {
                    if (layout.people_panel_rect) |panel| {
                        if (panel.contains(mouse_x, mouse_y)) {
                            scrollPlaceList(
                                &ui.people_scroll,
                                scroll_amount,
                                listViewportHeight(panel),
                                peopleContentHeightFiltered(&world_state, selected_place, ui.selected_gender_mask, ui.selected_race_mask),
                            );
                        }
                    }

                    if (layout.connections_panel_rect) |panel| {
                        if (panel.contains(mouse_x, mouse_y)) {
                            scrollPlaceList(
                                &ui.connections_scroll,
                                scroll_amount,
                                listViewportHeight(panel),
                                connectionContentHeight(&world_state, selected_place),
                            );
                        }
                    }
                }
            }

            clampPlaceViewScroll(&ui, &world_state, selected_place, client_rect);
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
            try drawPlaceView(backbuffer_dc, client_rect, &ui, &world_state, mouse_x, mouse_y, selected_place, back_rect, back_hovered, theme);
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
            if (rect.contains(click.x, click.y)) {
                ui.selected_place = place;
                ui.people_scroll = 0;
                ui.connections_scroll = 0;
                ui.filter_modal_open = false;
                ui.gender_dropdown_open = false;
                ui.race_dropdown_open = false;
            }
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
    ui: *const UiState,
    world_state: *const world.World,
    mouse_x: i32,
    mouse_y: i32,
    selected_place: world.Place,
    back_rect: Rect,
    back_hovered: bool,
    theme: Theme,
) !void {
    const layout = layoutPlaceView(client_rect, ui.*);
    drawButton(hdc, back_rect, "Back", back_hovered, theme);
    drawTextColored(hdc, 130, 80, selected_place.asString(), theme.text);
    var hovered_person: ?world.Person = null;
    var hovered_person_tooltip_style: TooltipStyle = .solid;
    var hovered_connection_group: ?ConnectionGroup = null;

    drawButton(
        hdc,
        layout.people_toggle_rect,
        if (ui.show_people_list) "Hide People" else "Show People",
        layout.people_toggle_rect.contains(mouse_x, mouse_y),
        theme,
    );
    drawButton(
        hdc,
        layout.filter_button_rect,
        "Filter",
        layout.filter_button_rect.contains(mouse_x, mouse_y),
        theme,
    );
    drawButton(
        hdc,
        layout.connections_toggle_rect,
        if (ui.show_connections_list) "Hide Connections" else "Show Connections",
        layout.connections_toggle_rect.contains(mouse_x, mouse_y),
        theme,
    );

    if (layout.people_panel_rect) |panel| {
        try drawPeoplePanel(
            hdc,
            panel,
            world_state,
            selected_place,
            ui.selected_gender_mask,
            ui.selected_race_mask,
            ui.people_scroll,
            mouse_x,
            mouse_y,
            &hovered_person,
            &hovered_person_tooltip_style,
            theme,
        );
    }

    if (layout.connections_panel_rect) |panel| {
        try drawConnectionsPanel(
            hdc,
            panel,
            world_state,
            selected_place,
            ui.connections_scroll,
            mouse_x,
            mouse_y,
            &hovered_connection_group,
            theme,
        );
    }

    drawTextColored(hdc, layout.map_label_pos.x, layout.map_label_pos.y, "Room map (100x100 units):", theme.text);
    drawPlaceMap(hdc, layout.map_rect, world_state, selected_place, mouse_x, mouse_y, &hovered_person, &hovered_person_tooltip_style, theme);
    drawTextColored(hdc, layout.legend_pos.x, layout.legend_pos.y, "Red: unconnected", theme.text);
    drawTextColored(hdc, layout.legend_pos.x, layout.legend_pos.y + 20, "Green: connected", theme.text);

    if (ui.filter_modal_open) {
        try drawFilterModal(hdc, client_rect, ui.*, mouse_x, mouse_y, theme);
    } else {
        if (hovered_person) |person| {
            try drawPersonTooltip(hdc, client_rect, mouse_x, mouse_y, person, world_state.people.items, world_state.connections.items, hovered_person_tooltip_style, theme);
        }

        if (hovered_connection_group) |group| {
            try drawConnectionGroupTooltip(hdc, client_rect, mouse_x, mouse_y, group, world_state.people.items, world_state.connections.items, .solid, theme);
        }
    }
}

fn wheelDeltaFromWParam(w_param: win.WPARAM) i32 {
    const raw = @as(u16, @truncate((w_param >> 16) & 0xffff));
    return @as(i16, @bitCast(raw));
}

fn listViewportHeight(panel: Rect) i32 {
    return @max(0, panel.h - 34);
}

fn scrollMax(viewport_h: i32, content_h: i32) i32 {
    return @max(0, content_h - viewport_h);
}

fn scrollPlaceList(offset: *i32, delta: i32, viewport_h: i32, content_h: i32) void {
    offset.* = clampI32(offset.* + delta, 0, scrollMax(viewport_h, content_h));
}

fn genderBit(kind: world.PersonType) u8 {
    return @as(u8, @intCast(@as(u16, 1) << @as(u3, @intCast(@intFromEnum(kind)))));
}

fn raceBit(race: world.Race) u16 {
    return @as(u16, @intCast(@as(u32, 1) << @as(u4, @intCast(@intFromEnum(race)))));
}

fn allGenderMask() u8 {
    var mask: u8 = 0;
    for (person_type_options) |kind| {
        mask |= genderBit(kind);
    }
    return mask;
}

fn allRaceMask() u16 {
    var mask: u16 = 0;
    for (race_options) |race| {
        mask |= raceBit(race);
    }
    return mask;
}

fn genderSelected(mask: u8, kind: world.PersonType) bool {
    return (mask & genderBit(kind)) != 0;
}

fn raceSelected(mask: u16, race: world.Race) bool {
    return (mask & raceBit(race)) != 0;
}

fn toggleGenderSelection(mask: *u8, kind: world.PersonType) void {
    mask.* ^= genderBit(kind);
}

fn toggleRaceSelection(mask: *u16, race: world.Race) void {
    mask.* ^= raceBit(race);
}

fn selectedGenderCount(mask: u8) usize {
    var count: usize = 0;
    for (person_type_options) |kind| {
        if (genderSelected(mask, kind)) count += 1;
    }
    return count;
}

fn selectedRaceCount(mask: u16) usize {
    var count: usize = 0;
    for (race_options) |race| {
        if (raceSelected(mask, race)) count += 1;
    }
    return count;
}

fn peopleCountInPlaceFiltered(world_state: *const world.World, selected_place: world.Place, gender_mask: u8, race_mask: u16) usize {
    var count: usize = 0;
    for (world_state.people.items) |person| {
        if (person.place == selected_place and personMatchesFilters(person, gender_mask, race_mask)) count += 1;
    }
    return count;
}

fn connectionGroupCountInPlace(world_state: *const world.World, selected_place: world.Place) usize {
    var count: usize = 0;
    for (world_state.connections.items, 0..) |connection, connection_index| {
        if (!isConnectionGroupFirstOccurrence(world_state.connections.items, connection_index)) continue;

        const stick = world.findPersonById(world_state.people.items, connection.stick_person_id) orelse continue;
        const cave = world.findPersonById(world_state.people.items, connection.cave_person_id) orelse continue;
        if (stick.place != selected_place or cave.place != selected_place) continue;
        if (cave.kind == .male) continue;
        count += 1;
    }
    return count;
}

fn peopleContentHeightFiltered(world_state: *const world.World, selected_place: world.Place, gender_mask: u8, race_mask: u16) i32 {
    return @as(i32, @intCast(peopleCountInPlaceFiltered(world_state, selected_place, gender_mask, race_mask))) * 36;
}

fn connectionContentHeight(world_state: *const world.World, selected_place: world.Place) i32 {
    return @as(i32, @intCast(connectionGroupCountInPlace(world_state, selected_place))) * 36;
}

fn clampPlaceViewScroll(ui: *UiState, world_state: *const world.World, selected_place: world.Place, client_rect: win.RECT) void {
    const layout = layoutPlaceView(client_rect, ui.*);

    if (layout.people_panel_rect) |panel| {
        ui.people_scroll = clampI32(ui.people_scroll, 0, scrollMax(listViewportHeight(panel), peopleContentHeightFiltered(world_state, selected_place, ui.selected_gender_mask, ui.selected_race_mask)));
    } else {
        ui.people_scroll = 0;
    }

    if (layout.connections_panel_rect) |panel| {
        ui.connections_scroll = clampI32(ui.connections_scroll, 0, scrollMax(listViewportHeight(panel), connectionContentHeight(world_state, selected_place)));
    } else {
        ui.connections_scroll = 0;
    }
}

fn makeSquareRect(x: i32, y: i32, max_w: i32, max_h: i32, min_side: i32) Rect {
    const side = @max(min_side, @min(max_w, max_h));
    return .{ .x = x, .y = y, .w = side, .h = side };
}

fn layoutPlaceView(client_rect: win.RECT, ui: UiState) PlaceViewLayout {
    const content_top = 165;
    const bottom_margin = 24;
    const panel_bottom = client_rect.bottom - bottom_margin;
    const total_h = @max(220, panel_bottom - content_top);
    const left_w = 570;
    const right_x = 620;
    const right_w = @max(360, client_rect.right - right_x - 30);

    const people_toggle_rect = Rect{ .x = 130, .y = 118, .w = 150, .h = 32 };
    const filter_button_rect = Rect{ .x = 295, .y = 118, .w = 120, .h = 32 };
    const connections_toggle_rect = Rect{ .x = 480, .y = 118, .w = 190, .h = 32 };

    var people_panel_rect: ?Rect = null;
    var connections_panel_rect: ?Rect = null;
    var map_label_pos = I32Point{ .x = 20, .y = content_top };
    var map_rect = Rect{ .x = 20, .y = content_top + 26, .w = 320, .h = 320 };
    var legend_pos = I32Point{ .x = 20, .y = content_top + 360 };

    if (ui.show_people_list and ui.show_connections_list) {
        people_panel_rect = Rect{ .x = 20, .y = content_top, .w = left_w, .h = total_h };
        const connections_h = @max(170, @min(230, total_h / 2));
        connections_panel_rect = Rect{ .x = right_x, .y = content_top, .w = right_w, .h = connections_h };

        map_label_pos = I32Point{ .x = right_x, .y = connections_panel_rect.?.y + connections_panel_rect.?.h + 18 };
        map_rect = makeSquareRect(right_x, map_label_pos.y + 26, right_w, panel_bottom - (map_label_pos.y + 26), 220);
        legend_pos = I32Point{ .x = map_rect.x + map_rect.w + 15, .y = map_rect.y + 10 };
        if (legend_pos.x + 120 > client_rect.right - 10) {
            legend_pos = I32Point{ .x = map_rect.x, .y = map_rect.y + map_rect.h + 10 };
        }
    } else if (ui.show_people_list) {
        people_panel_rect = Rect{ .x = 20, .y = content_top, .w = left_w, .h = total_h };
        map_label_pos = I32Point{ .x = right_x, .y = content_top };
        map_rect = makeSquareRect(right_x, content_top + 26, right_w, panel_bottom - (content_top + 26), 240);
        legend_pos = I32Point{ .x = map_rect.x + map_rect.w + 15, .y = map_rect.y + 10 };
        if (legend_pos.x + 120 > client_rect.right - 10) {
            legend_pos = I32Point{ .x = map_rect.x, .y = map_rect.y + map_rect.h + 10 };
        }
    } else if (ui.show_connections_list) {
        connections_panel_rect = Rect{ .x = right_x, .y = content_top, .w = right_w, .h = total_h };
        map_label_pos = I32Point{ .x = 20, .y = content_top };
        map_rect = makeSquareRect(20, content_top + 26, left_w, panel_bottom - (content_top + 26), 260);
        legend_pos = I32Point{ .x = map_rect.x + map_rect.w + 15, .y = map_rect.y + 10 };
        if (legend_pos.x + 120 > right_x - 10) {
            legend_pos = I32Point{ .x = map_rect.x, .y = map_rect.y + map_rect.h + 10 };
        }
    } else {
        const map_area_x = 20;
        const map_area_w = client_rect.right - 40;
        map_label_pos = I32Point{ .x = map_area_x, .y = content_top };
        map_rect = makeSquareRect(map_area_x, content_top + 26, map_area_w, panel_bottom - (content_top + 26), 300);
        legend_pos = I32Point{ .x = map_rect.x + map_rect.w + 15, .y = map_rect.y + 10 };
        if (legend_pos.x + 120 > client_rect.right - 10) {
            legend_pos = I32Point{ .x = map_rect.x, .y = map_rect.y + map_rect.h + 10 };
        }
    }

    return .{
        .people_toggle_rect = people_toggle_rect,
        .connections_toggle_rect = connections_toggle_rect,
        .filter_button_rect = filter_button_rect,
        .people_panel_rect = people_panel_rect,
        .connections_panel_rect = connections_panel_rect,
        .map_label_pos = map_label_pos,
        .map_rect = map_rect,
        .legend_pos = legend_pos,
    };
}

fn drawPeoplePanel(
    hdc: win.HDC,
    panel: Rect,
    world_state: *const world.World,
    selected_place: world.Place,
    gender_mask: u8,
    race_mask: u16,
    scroll_offset: i32,
    mouse_x: i32,
    mouse_y: i32,
    hovered_person: *?world.Person,
    hovered_person_tooltip_style: *TooltipStyle,
    theme: Theme,
) !void {
    drawFrame(hdc, panel, theme.panel, theme.border);
    drawTextColored(hdc, panel.x + 10, panel.y + 8, "People in place:", theme.text);

    var gender_summary_buf: [64]u8 = undefined;
    const gender_summary = try genderSelectionSummary(&gender_summary_buf, gender_mask);
    var race_summary_buf: [96]u8 = undefined;
    const race_summary = try raceSelectionSummary(&race_summary_buf, race_mask);
    var filter_summary_buf: [192]u8 = undefined;
    const filter_summary = try std.fmt.bufPrint(&filter_summary_buf, "Filters: {s} | {s}", .{ gender_summary, race_summary });
    drawTextColored(hdc, panel.x + panel.w - 250, panel.y + 8, filter_summary, theme.text);

    const viewport_y = panel.y + 34;
    const viewport_bottom = panel.y + panel.h;
    var item_y = viewport_y - scroll_offset;

    for (world_state.people.items) |person| {
        if (person.place != selected_place) continue;
        if (!personMatchesFilters(person, gender_mask, race_mask)) continue;

        const item_rect = Rect{ .x = panel.x + 4, .y = item_y - 2, .w = panel.w - 8, .h = 34 };
        const visible = item_rect.y + item_rect.h > viewport_y and item_rect.y < viewport_bottom;
        const hovered = visible and item_rect.contains(mouse_x, mouse_y);
        if (hovered) {
            hovered_person.* = person;
            hovered_person_tooltip_style.* = .solid;
            fillRectColor(hdc, item_rect, theme.button_hover);
        }

        if (visible) {
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
            drawTextColored(hdc, panel.x + 10, item_y, person_line, theme.text);

            var person_meta_buf: [220]u8 = undefined;
            const person_meta_line = try std.fmt.bufPrint(&person_meta_buf, "    {s}  {s} {s}", .{
                person.kind.asString(),
                person.hair_length.asString(),
                person.hair_style.asString(),
            });
            drawTextColored(hdc, panel.x + 10, item_y + 18, person_meta_line, theme.text);
        }

        item_y += 36;
    }
}

fn personMatchesFilters(person: world.Person, gender_mask: u8, race_mask: u16) bool {
    return genderSelected(gender_mask, person.kind) and raceSelected(race_mask, person.race);
}

fn genderSelectionSummary(buf: []u8, mask: u8) ![]const u8 {
    const count = selectedGenderCount(mask);
    if (count == 0) return std.fmt.bufPrint(buf, "no genders", .{});
    if (mask == allGenderMask()) return std.fmt.bufPrint(buf, "all genders", .{});
    if (count == 1) {
        for (person_type_options) |kind| {
            if (genderSelected(mask, kind)) return std.fmt.bufPrint(buf, "{s}", .{kind.asString()});
        }
    }
    return std.fmt.bufPrint(buf, "{d} genders", .{count});
}

fn raceSelectionSummary(buf: []u8, mask: u16) ![]const u8 {
    const count = selectedRaceCount(mask);
    if (count == 0) return std.fmt.bufPrint(buf, "no races", .{});
    if (mask == allRaceMask()) return std.fmt.bufPrint(buf, "all races", .{});
    if (count == 1) {
        for (race_options) |race| {
            if (raceSelected(mask, race)) return std.fmt.bufPrint(buf, "{s}", .{race.asString()});
        }
    }
    return std.fmt.bufPrint(buf, "{d} races", .{count});
}

fn layoutFilterModal(client_rect: win.RECT) FilterModalLayout {
    const modal_w = 560;
    const modal_h = 340;
    const modal_x = @max(20, @divTrunc(client_rect.right - modal_w, 2));
    const modal_y = @max(90, @divTrunc(client_rect.bottom - modal_h, 2));
    const modal_rect = Rect{ .x = modal_x, .y = modal_y, .w = modal_w, .h = modal_h };
    const close_button_rect = Rect{ .x = modal_rect.x + modal_rect.w - 42, .y = modal_rect.y + 12, .w = 24, .h = 24 };
    const gender_button_rect = Rect{ .x = modal_rect.x + 20, .y = modal_rect.y + 60, .w = 240, .h = 32 };
    const race_button_rect = Rect{ .x = modal_rect.x + 280, .y = modal_rect.y + 60, .w = 260, .h = 32 };
    const gender_dropdown_rect = Rect{ .x = gender_button_rect.x, .y = gender_button_rect.y + 38, .w = gender_button_rect.w, .h = 86 };
    const race_dropdown_rect = Rect{ .x = race_button_rect.x, .y = race_button_rect.y + 38, .w = race_button_rect.w, .h = 236 };

    return .{
        .modal_rect = modal_rect,
        .close_button_rect = close_button_rect,
        .gender_button_rect = gender_button_rect,
        .race_button_rect = race_button_rect,
        .gender_dropdown_rect = gender_dropdown_rect,
        .race_dropdown_rect = race_dropdown_rect,
    };
}

fn handleFilterModalClick(ui: *UiState, world_state: *const world.World, client_rect: win.RECT, click: ClickPos) void {
    const layout = layoutFilterModal(client_rect);
    if (!layout.modal_rect.contains(click.x, click.y)) {
        ui.filter_modal_open = false;
        ui.gender_dropdown_open = false;
        ui.race_dropdown_open = false;
        return;
    }

    if (layout.gender_button_rect.contains(click.x, click.y)) {
        ui.gender_dropdown_open = !ui.gender_dropdown_open;
        return;
    }

    if (layout.close_button_rect.contains(click.x, click.y)) {
        ui.filter_modal_open = false;
        ui.gender_dropdown_open = false;
        ui.race_dropdown_open = false;
        return;
    }

    if (layout.race_button_rect.contains(click.x, click.y)) {
        ui.race_dropdown_open = !ui.race_dropdown_open;
        return;
    }

    if (ui.gender_dropdown_open) {
        var option_y = layout.gender_dropdown_rect.y + 6;
        for (person_type_options) |kind| {
            const option_rect = Rect{ .x = layout.gender_dropdown_rect.x + 6, .y = option_y, .w = layout.gender_dropdown_rect.w - 12, .h = 22 };
            if (option_rect.contains(click.x, click.y)) {
                toggleGenderSelection(&ui.selected_gender_mask, kind);
                ui.people_scroll = 0;
                _ = world_state;
                return;
            }
            option_y += 24;
        }
    }

    if (ui.race_dropdown_open) {
        var option_y = layout.race_dropdown_rect.y + 6;
        for (race_options) |race| {
            const option_rect = Rect{ .x = layout.race_dropdown_rect.x + 6, .y = option_y, .w = layout.race_dropdown_rect.w - 12, .h = 22 };
            if (option_rect.contains(click.x, click.y)) {
                toggleRaceSelection(&ui.selected_race_mask, race);
                ui.people_scroll = 0;
                _ = world_state;
                return;
            }
            option_y += 24;
        }
    }
}

fn drawFilterModal(hdc: win.HDC, client_rect: win.RECT, ui: UiState, mouse_x: i32, mouse_y: i32, theme: Theme) !void {
    const overlay_rect = Rect{ .x = 0, .y = 0, .w = client_rect.right, .h = client_rect.bottom };
    drawFrameBlended(hdc, overlay_rect, theme.background, 0.4, theme.background);

    const layout = layoutFilterModal(client_rect);
    drawFrame(hdc, layout.modal_rect, theme.panel, theme.border);
    drawTextColored(hdc, layout.modal_rect.x + 20, layout.modal_rect.y + 18, "People List Filters", theme.text);
    drawCloseButton(hdc, layout.close_button_rect, layout.close_button_rect.contains(mouse_x, mouse_y));

    var gender_summary_buf: [64]u8 = undefined;
    const gender_summary = try genderSelectionSummary(&gender_summary_buf, ui.selected_gender_mask);
    var race_summary_buf: [96]u8 = undefined;
    const race_summary = try raceSelectionSummary(&race_summary_buf, ui.selected_race_mask);

    drawButton(
        hdc,
        layout.gender_button_rect,
        gender_summary,
        layout.gender_button_rect.contains(mouse_x, mouse_y),
        theme,
    );
    drawButton(
        hdc,
        layout.race_button_rect,
        race_summary,
        layout.race_button_rect.contains(mouse_x, mouse_y),
        theme,
    );
    drawTextColored(hdc, layout.gender_button_rect.x, layout.gender_button_rect.y - 20, "Gender", theme.text);
    drawTextColored(hdc, layout.race_button_rect.x, layout.race_button_rect.y - 20, "Race", theme.text);

    if (ui.gender_dropdown_open) {
        drawMultiSelectDropdown(hdc, layout.gender_dropdown_rect, mouse_x, mouse_y, theme);
        var option_y = layout.gender_dropdown_rect.y + 6;
        for (person_type_options) |kind| {
            const option_rect = Rect{ .x = layout.gender_dropdown_rect.x + 6, .y = option_y, .w = layout.gender_dropdown_rect.w - 12, .h = 22 };
            if (option_rect.contains(mouse_x, mouse_y)) fillRectColor(hdc, option_rect, theme.button_hover);

            var label_buf: [64]u8 = undefined;
            const label = try std.fmt.bufPrint(&label_buf, "[{s}] {s}", .{
                if (genderSelected(ui.selected_gender_mask, kind)) "x" else " ",
                kind.asString(),
            });
            drawTextColored(hdc, option_rect.x + 4, option_rect.y + 4, label, theme.text);
            option_y += 24;
        }
    }

    if (ui.race_dropdown_open) {
        drawMultiSelectDropdown(hdc, layout.race_dropdown_rect, mouse_x, mouse_y, theme);
        var option_y = layout.race_dropdown_rect.y + 6;
        for (race_options) |race| {
            const option_rect = Rect{ .x = layout.race_dropdown_rect.x + 6, .y = option_y, .w = layout.race_dropdown_rect.w - 12, .h = 22 };
            if (option_rect.contains(mouse_x, mouse_y)) fillRectColor(hdc, option_rect, theme.button_hover);

            var label_buf: [96]u8 = undefined;
            const label = try std.fmt.bufPrint(&label_buf, "[{s}] {s}", .{
                if (raceSelected(ui.selected_race_mask, race)) "x" else " ",
                race.asString(),
            });
            drawTextColored(hdc, option_rect.x + 4, option_rect.y + 4, label, theme.text);
            option_y += 24;
        }
    }
}

fn drawMultiSelectDropdown(hdc: win.HDC, rect: Rect, mouse_x: i32, mouse_y: i32, theme: Theme) void {
    _ = mouse_x;
    _ = mouse_y;
    drawFrame(hdc, rect, theme.button, theme.border);
}

fn drawCloseButton(hdc: win.HDC, rect: Rect, hovered: bool) void {
    const fill = if (hovered) rgb(216, 68, 68) else rgb(194, 54, 54);
    drawFrame(hdc, rect, fill, rgb(142, 30, 30));
    drawTextColored(hdc, rect.x + 7, rect.y + 4, "X", rgb(255, 255, 255));
}

fn drawConnectionsPanel(
    hdc: win.HDC,
    panel: Rect,
    world_state: *const world.World,
    selected_place: world.Place,
    scroll_offset: i32,
    mouse_x: i32,
    mouse_y: i32,
    hovered_connection_group: *?ConnectionGroup,
    theme: Theme,
) !void {
    drawFrame(hdc, panel, theme.panel, theme.border);
    drawTextColored(hdc, panel.x + 10, panel.y + 8, "Current connections:", theme.text);

    const viewport_y = panel.y + 34;
    const viewport_bottom = panel.y + panel.h;
    var item_y = viewport_y - scroll_offset;

    for (world_state.connections.items, 0..) |connection, connection_index| {
        if (!isConnectionGroupFirstOccurrence(world_state.connections.items, connection_index)) continue;

        const stick = world.findPersonById(world_state.people.items, connection.stick_person_id) orelse continue;
        const cave = world.findPersonById(world_state.people.items, connection.cave_person_id) orelse continue;
        if (stick.place != selected_place or cave.place != selected_place) continue;
        if (cave.kind == .male) continue;

        const item_rect = Rect{ .x = panel.x + 4, .y = item_y - 2, .w = panel.w - 8, .h = 34 };
        const visible = item_rect.y + item_rect.h > viewport_y and item_rect.y < viewport_bottom;
        const group = ConnectionGroup{ .cave_person_id = connection.cave_person_id };
        const hovered = visible and item_rect.contains(mouse_x, mouse_y);
        if (hovered) {
            hovered_connection_group.* = group;
            fillRectColor(hdc, item_rect, theme.button_hover);
        }

        if (visible) {
            var conn_buf: [256]u8 = undefined;
            const conn_line = try std.fmt.bufPrint(&conn_buf, "{s} {s} ({s}) | connections {d}", .{
                cave.first_name,
                cave.last_name,
                cave.kind.asString(),
                countConnectionGroup(group, world_state.connections.items),
            });
            drawTextColored(hdc, panel.x + 10, item_y, conn_line, theme.text);
            drawMoodTriplet(hdc, panel.x + 290, item_y, cave.moods, theme);
            drawCaveSpecialMoodBars(hdc, panel.x + 290, item_y + 16, cave.moods, theme);
        }

        item_y += 36;
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
            .background = rgb(18, 23, 31),
            .button = rgb(50, 62, 77),
            .button_hover = rgb(68, 84, 102),
            .panel = rgb(29, 39, 53),
            .text = rgb(236, 241, 247),
            .border = rgb(98, 114, 133),
        };
    }

    return .{
        .background = rgb(243, 247, 250),
        .button = rgb(232, 239, 245),
        .button_hover = rgb(216, 227, 237),
        .panel = rgb(250, 252, 255),
        .text = rgb(25, 34, 44),
        .border = rgb(162, 177, 192),
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

fn fillRoundedRect(hdc: win.HDC, rect: Rect, color: win.COLORREF, radius: i32) void {
    const brush = win.CreateSolidBrush(color) orelse return;
    defer _ = win.DeleteObject(@ptrCast(brush));

    const pen = win.CreatePen(win.PS_SOLID, 1, color) orelse return;
    defer _ = win.DeleteObject(@ptrCast(pen));

    const previous_brush = win.SelectObject(hdc, @ptrCast(brush)) orelse return;
    defer _ = win.SelectObject(hdc, previous_brush);

    const previous_pen = win.SelectObject(hdc, @ptrCast(pen)) orelse return;
    defer _ = win.SelectObject(hdc, previous_pen);

    _ = win.RoundRect(hdc, rect.x, rect.y, rect.x + rect.w, rect.y + rect.h, radius, radius);
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
    const shadow_rect = Rect{ .x = rect.x, .y = rect.y + 2, .w = rect.w, .h = rect.h };
    fillRoundedRect(hdc, shadow_rect, blendColor(border, fill, 0.16), 12);

    const brush = win.CreateSolidBrush(fill) orelse return;
    defer _ = win.DeleteObject(@ptrCast(brush));

    const pen = win.CreatePen(win.PS_SOLID, 1, border) orelse return;
    defer _ = win.DeleteObject(@ptrCast(pen));

    const previous_brush = win.SelectObject(hdc, @ptrCast(brush)) orelse return;
    defer _ = win.SelectObject(hdc, previous_brush);

    const previous_pen = win.SelectObject(hdc, @ptrCast(pen)) orelse return;
    defer _ = win.SelectObject(hdc, previous_pen);

    _ = win.RoundRect(hdc, rect.x, rect.y, rect.x + rect.w, rect.y + rect.h, 12, 12);
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
    const fill = if (hovered) theme.button_hover else theme.button;
    drawFrame(hdc, rect, fill, blendColor(theme.border, fill, 0.72));
    drawTextColored(hdc, rect.x + 12, rect.y + 10, label, theme.text);
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
