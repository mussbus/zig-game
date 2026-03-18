const std = @import("std");
const sim = @import("../sim.zig");
const ui_layout = @import("ui_layout.zig");
const ui_render = @import("ui_render.zig");
const ui_support = @import("ui_support.zig");
const ui_types = @import("ui_types.zig");
const world = @import("../world.zig");
const win = @import("../win32.zig").win;

const ClickPos = ui_types.ClickPos;
const Rect = ui_types.Rect;
const UiState = ui_types.UiState;
const max_sim_steps_per_frame: u8 = 4;
const max_sim_lag_ms: i64 = @as(i64, sim.step_interval_ms) * max_sim_steps_per_frame;

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

        if (click_pos) |click| {
            if (dark_mode_rect.contains(click.x, click.y)) {
                ui.dark_mode = !ui.dark_mode;
            } else if (pause_rect.contains(click.x, click.y)) {
                ui.paused = !ui.paused;
            } else if (reset_rect.contains(click.x, click.y)) {
                world.reset(&world_state);
                try world.prefillPlaces(&world_state, random, allocator);
                tick = 0;
                ui.resetSelection();
                last_step_ms = std.time.milliTimestamp();
            } else if (ui.selected_place != null and back_rect.contains(click.x, click.y)) {
                ui.resetSelection();
            } else if (ui.selected_place) |selected_place| {
                const layout = ui_layout.layoutPlaceView(client_rect, ui);
                if (ui.filter_modal_open) {
                    handleFilterModalClick(&ui, client_rect, click);
                    ui_layout.clampPlaceViewScroll(&ui, &world_state, selected_place, client_rect);
                } else if (layout.people_toggle_rect.contains(click.x, click.y)) {
                    ui.show_people_list = !ui.show_people_list;
                    ui_layout.clampPlaceViewScroll(&ui, &world_state, selected_place, client_rect);
                } else if (layout.filter_button_rect.contains(click.x, click.y)) {
                    ui.openFilterModal();
                } else if (layout.connections_toggle_rect.contains(click.x, click.y)) {
                    ui.show_connections_list = !ui.show_connections_list;
                    ui_layout.clampPlaceViewScroll(&ui, &world_state, selected_place, client_rect);
                }
            } else if (overviewPlaceAt(click.x, click.y)) |place| {
                ui.selected_place = place;
                ui.resetScroll();
                ui.closeFilterModal();
            }
        }

        if (ui.selected_place) |selected_place| {
            if (wheel_delta != 0 and !ui.filter_modal_open) {
                const layout = ui_layout.layoutPlaceView(client_rect, ui);
                const wheel_steps = @divTrunc(wheel_delta, 120);
                const scroll_amount = -wheel_steps * 36;

                if (scroll_amount != 0) {
                    if (layout.people_panel_rect) |panel| {
                        if (panel.contains(mouse_x, mouse_y)) {
                            ui_layout.scrollPlaceList(
                                &ui.people_scroll,
                                scroll_amount,
                                ui_layout.listViewportHeight(panel),
                                ui_layout.peopleContentHeightFiltered(&world_state, selected_place, ui.selected_gender_mask, ui.selected_race_mask),
                            );
                        }
                    }

                    if (layout.connections_panel_rect) |panel| {
                        if (panel.contains(mouse_x, mouse_y)) {
                            ui_layout.scrollPlaceList(
                                &ui.connections_scroll,
                                scroll_amount,
                                ui_layout.listViewportHeight(panel),
                                ui_layout.connectionContentHeight(&world_state, selected_place),
                            );
                        }
                    }
                }
            }

            ui_layout.clampPlaceViewScroll(&ui, &world_state, selected_place, client_rect);
        }

        const now_ms = std.time.milliTimestamp();
        if (!ui.paused and now_ms - last_step_ms > max_sim_lag_ms) {
            // Drop excess backlog so a slow frame cannot monopolize the UI thread.
            last_step_ms = now_ms - max_sim_lag_ms;
        }

        var steps_this_frame: u8 = 0;
        while (!ui.paused and steps_this_frame < max_sim_steps_per_frame and std.time.milliTimestamp() - last_step_ms >= sim.step_interval_ms) {
            try sim.stepSimulation(&world_state, &tick, random, allocator);
            last_step_ms += sim.step_interval_ms;
            steps_this_frame += 1;
        }

        try ui_render.renderFrame(hwnd, client_rect, &ui, &world_state, tick, mouse_x, mouse_y);
        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}

fn wheelDeltaFromWParam(w_param: win.WPARAM) i32 {
    const raw = @as(u16, @truncate((w_param >> 16) & 0xffff));
    return @as(i16, @bitCast(raw));
}

fn overviewPlaceAt(x: i32, y: i32) ?world.Place {
    var place_index: usize = 0;
    for (std.enums.values(world.Place)) |place| {
        const col = @as(i32, @intCast(place_index % 2));
        const row = @as(i32, @intCast(place_index / 2));
        const rect = Rect{ .x = 20 + col * 360, .y = 120 + row * 110, .w = 330, .h = 90 };
        if (rect.contains(x, y)) return place;
        place_index += 1;
    }
    return null;
}

fn handleFilterModalClick(ui: *UiState, client_rect: win.RECT, click: ClickPos) void {
    const layout = ui_layout.layoutFilterModal(client_rect);
    if (!layout.modal_rect.contains(click.x, click.y)) {
        ui.closeFilterModal();
        return;
    }

    if (layout.gender_button_rect.contains(click.x, click.y)) {
        ui.gender_dropdown_open = !ui.gender_dropdown_open;
        return;
    }

    if (layout.close_button_rect.contains(click.x, click.y)) {
        ui.closeFilterModal();
        return;
    }

    if (layout.race_button_rect.contains(click.x, click.y)) {
        ui.race_dropdown_open = !ui.race_dropdown_open;
        return;
    }

    if (ui.gender_dropdown_open) {
        var option_y = layout.gender_dropdown_rect.y + 6;
        for (ui_support.person_type_options) |kind| {
            const option_rect = Rect{ .x = layout.gender_dropdown_rect.x + 6, .y = option_y, .w = layout.gender_dropdown_rect.w - 12, .h = 22 };
            if (option_rect.contains(click.x, click.y)) {
                ui_support.toggleGenderSelection(&ui.selected_gender_mask, kind);
                ui.people_scroll = 0;
                return;
            }
            option_y += 24;
        }
    }

    if (ui.race_dropdown_open) {
        var option_y = layout.race_dropdown_rect.y + 6;
        for (ui_support.race_options) |race| {
            const option_rect = Rect{ .x = layout.race_dropdown_rect.x + 6, .y = option_y, .w = layout.race_dropdown_rect.w - 12, .h = 22 };
            if (option_rect.contains(click.x, click.y)) {
                ui_support.toggleRaceSelection(&ui.selected_race_mask, race);
                ui.people_scroll = 0;
                return;
            }
            option_y += 24;
        }
    }
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
