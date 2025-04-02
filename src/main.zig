const std = @import("std");
const assert = std.debug.assert;
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_MAIN_HANDLED' should be defined before including 'SDL_main.h'.
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");

    @cInclude("yoga/Yoga.h");
});

// We will use this renderer to draw into this window every frame.
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;

var frame_timer: std.time.Timer = undefined;
const scale = 2;

pub fn main() u8 {
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_SetMainReady()' should be called before calling 'SDL_Init()'.
    c.SDL_SetMainReady();

    // This is more or less what 'SDL_main.h' does behind the curtains.
    const status = c.SDL_EnterAppMainCallbacks(0, null, appInit, appIterate, appEvent, appQuit);

    return @bitCast(@as(i8, @truncate(status)));
}

// This function runs once at startup.
fn appInit(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.SDL_AppResult {
    _ = appstate;
    _ = argc;
    _ = argv;
    _ = c.SDL_SetAppMetadata("Example HUMAN READABLE NAME", "1.0", "com.example.CATEGORY-NAME");

    assert(c.SDL_Init(c.SDL_INIT_VIDEO));
    assert(c.SDL_SetHint(c.SDL_HINT_MAIN_CALLBACK_RATE, "waitevent"));
    assert(c.SDL_CreateWindowAndRenderer("examples/CATEGORY/NAME", 640, 480, 0, &window, &renderer));
    assert(c.SDL_SetWindowResizable(window, true));
    assert(c.SDL_SetRenderScale(renderer, scale, scale));

    frame_timer = std.time.Timer.start() catch unreachable;

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

// This function runs when a new event (mouse input, keypresses, etc) occurs.
fn appEvent(appstate: ?*anyopaque, event: ?*c.SDL_Event) callconv(.c) c.SDL_AppResult {
    _ = appstate;

    switch (event.?.type) {
        c.SDL_EVENT_QUIT => return c.SDL_APP_SUCCESS,
        else => return c.SDL_APP_CONTINUE,
    }
}

// This function runs once per frame, and is the heart of the program.
fn appIterate(appstate: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    _ = appstate;

    const frame_time_ns = frame_timer.lap();
    const fps = 1_000_000_000 / frame_time_ns;

    // 1. Calculate layout

    var window_w: c_int = undefined;
    var window_h: c_int = undefined;
    assert(c.SDL_GetWindowSize(window, &window_w, &window_h));

    const root = c.YGNodeNew();
    c.YGNodeStyleSetFlexDirection(root, c.YGFlexDirectionRow);
    c.YGNodeStyleSetWidth(root, @floatFromInt(window_w));
    c.YGNodeStyleSetHeight(root, @floatFromInt(window_h));

    const child0 = c.YGNodeNew();
    c.YGNodeStyleSetFlexGrow(child0, 1.0);
    c.YGNodeStyleSetMargin(child0, c.YGEdgeRight, 10.0);
    c.YGNodeInsertChild(root, child0, 0);

    const child1 = c.YGNodeNew();
    c.YGNodeStyleSetFlexGrow(child1, 1.0);
    c.YGNodeInsertChild(root, child1, 1);

    const text1 = c.YGNodeNew();
    c.YGNodeStyleSetFlexGrow(text1, 1.0);
    c.YGNodeInsertChild(child1, text1, 0);

    const text2 = c.YGNodeNew();
    c.YGNodeStyleSetFlexGrow(text2, 1.0);
    c.YGNodeInsertChild(child1, text2, 1);

    c.YGNodeCalculateLayout(root, c.YGUndefined, c.YGUndefined, c.YGDirectionLTR);

    // 2. Render

    assert(c.SDL_SetRenderDrawColor(renderer, 100, 0, 0, c.SDL_ALPHA_OPAQUE));
    assert(c.SDL_RenderClear(renderer));

    assert(c.SDL_SetRenderDrawColor(renderer, 0, 0, 100, 255));
    assert(c.SDL_RenderFillRect(renderer, &c.SDL_FRect{
        .h = c.YGNodeLayoutGetHeight(child0) / scale,
        .w = c.YGNodeLayoutGetWidth(child0) / scale,
        .x = c.YGNodeLayoutGetLeft(child0) / scale,
        .y = c.YGNodeLayoutGetTop(child0) / scale,
    }));

    assert(c.SDL_SetRenderDrawColor(renderer, 0, 100, 0, 255));
    assert(c.SDL_RenderFillRect(renderer, &c.SDL_FRect{
        .h = c.YGNodeLayoutGetHeight(child1) / scale,
        .w = c.YGNodeLayoutGetWidth(child1) / scale,
        .x = c.YGNodeLayoutGetLeft(child1) / scale,
        .y = c.YGNodeLayoutGetTop(child1) / scale,
    }));

    assert(c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255));
    const text1_x = (c.YGNodeLayoutGetLeft(c.YGNodeGetParent(text1)) + c.YGNodeLayoutGetLeft(text1)) / scale;
    const text1_y = (c.YGNodeLayoutGetTop(c.YGNodeGetParent(text1)) + c.YGNodeLayoutGetTop(text1)) / scale;
    var buf: [32]u8 = undefined;
    assert(c.SDL_RenderDebugText(
        renderer,
        text1_x,
        text1_y,
        std.fmt.bufPrintZ(&buf, "text1: x={d}, y={d}", .{ text1_x, text1_y }) catch unreachable,
    ));

    const text2_x = (c.YGNodeLayoutGetLeft(c.YGNodeGetParent(text2)) + c.YGNodeLayoutGetLeft(text2)) / scale;
    const text2_y = (c.YGNodeLayoutGetTop(c.YGNodeGetParent(text2)) + c.YGNodeLayoutGetTop(text2)) / scale;
    assert(c.SDL_RenderDebugText(
        renderer,
        text2_x,
        text2_y,
        std.fmt.bufPrintZ(&buf, "text2: x={d}, y={d}", .{ text2_x, text2_y }) catch unreachable,
    ));

    assert(c.SDL_RenderDebugText(
        renderer,
        0,
        0,
        std.fmt.bufPrintZ(&buf, "Frame rate: {d}fps", .{fps}) catch unreachable,
    ));
    assert(c.SDL_RenderDebugText(
        renderer,
        0,
        10,
        std.fmt.bufPrintZ(&buf, "Frame time: {d}us", .{frame_time_ns / 1000}) catch unreachable,
    ));

    assert(c.SDL_RenderPresent(renderer));

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

// This function runs once at shutdown.
fn appQuit(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    _ = appstate;
    _ = result;
    // SDL will clean up the window/renderer for us.
}
