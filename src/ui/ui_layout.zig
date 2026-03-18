const world = @import("../world.zig");
const ui_support = @import("ui_support.zig");
const ui_types = @import("ui_types.zig");
const win = @import("../win32.zig").win;

const Rect = ui_types.Rect;
const I32Point = ui_types.I32Point;
const UiState = ui_types.UiState;
const PlaceViewLayout = ui_types.PlaceViewLayout;
const FilterModalLayout = ui_types.FilterModalLayout;

pub fn listViewportHeight(panel: Rect) i32 {
    return @max(0, panel.h - 34);
}

pub fn scrollMax(viewport_h: i32, content_h: i32) i32 {
    return @max(0, content_h - viewport_h);
}

pub fn clampI32(value: i32, min_value: i32, max_value: i32) i32 {
    return @max(min_value, @min(value, max_value));
}

pub fn scrollPlaceList(offset: *i32, delta: i32, viewport_h: i32, content_h: i32) void {
    offset.* = clampI32(offset.* + delta, 0, scrollMax(viewport_h, content_h));
}

pub fn peopleContentHeightFiltered(world_state: *const world.World, selected_place: world.Place, gender_mask: u8, race_mask: u16) i32 {
    return @as(i32, @intCast(ui_support.peopleCountInPlaceFiltered(world_state, selected_place, gender_mask, race_mask))) * 36;
}

pub fn connectionContentHeight(world_state: *const world.World, selected_place: world.Place) i32 {
    return @as(i32, @intCast(ui_support.connectionGroupCountInPlace(world_state, selected_place))) * 36;
}

pub fn clampPlaceViewScroll(ui: *UiState, world_state: *const world.World, selected_place: world.Place, client_rect: win.RECT) void {
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

pub fn layoutPlaceView(client_rect: win.RECT, ui: UiState) PlaceViewLayout {
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

pub fn layoutFilterModal(client_rect: win.RECT) FilterModalLayout {
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
