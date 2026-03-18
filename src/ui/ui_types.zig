const world = @import("../world.zig");
const win = @import("../win32.zig").win;
const ui_support = @import("ui_support.zig");

pub const ConnectionGroup = struct {
    cave_person_id: usize,
};

pub const TooltipStyle = enum {
    solid,
    translucent,
};

pub const ClickPos = struct {
    x: i32,
    y: i32,
};

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub inline fn contains(self: Rect, px: i32, py: i32) bool {
        return px >= self.x and px < self.x + self.w and py >= self.y and py < self.y + self.h;
    }
};

pub const I32Point = struct {
    x: i32,
    y: i32,
};

pub const UiState = struct {
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
    selected_gender_mask: u8 = ui_support.allGenderMask(),
    selected_race_mask: u16 = ui_support.allRaceMask(),

    pub fn resetSelection(self: *UiState) void {
        self.selected_place = null;
        self.people_scroll = 0;
        self.connections_scroll = 0;
        self.closeFilterModal();
    }

    pub fn resetScroll(self: *UiState) void {
        self.people_scroll = 0;
        self.connections_scroll = 0;
    }

    pub fn openFilterModal(self: *UiState) void {
        self.filter_modal_open = true;
        self.gender_dropdown_open = false;
        self.race_dropdown_open = false;
    }

    pub fn closeFilterModal(self: *UiState) void {
        self.filter_modal_open = false;
        self.gender_dropdown_open = false;
        self.race_dropdown_open = false;
    }
};

pub const Theme = struct {
    background: win.COLORREF,
    button: win.COLORREF,
    button_hover: win.COLORREF,
    panel: win.COLORREF,
    text: win.COLORREF,
    border: win.COLORREF,
};

pub const PlaceViewLayout = struct {
    people_toggle_rect: Rect,
    connections_toggle_rect: Rect,
    filter_button_rect: Rect,
    people_panel_rect: ?Rect,
    connections_panel_rect: ?Rect,
    map_label_pos: I32Point,
    map_rect: Rect,
    legend_pos: I32Point,
};

pub const FilterModalLayout = struct {
    modal_rect: Rect,
    close_button_rect: Rect,
    gender_button_rect: Rect,
    race_button_rect: Rect,
    gender_dropdown_rect: Rect,
    race_dropdown_rect: Rect,
};
