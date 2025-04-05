const std = @import("std");
const assert = std.debug.assert;
const c = @cImport({
    @cInclude("yoga/Yoga.h");

    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_MAIN_HANDLED' should be defined before including 'SDL_main.h'.
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

const noto_sans = @embedFile("NotoSans-Regular.ttf");
const inter_variable = @embedFile("InterVariable.ttf");

var scale: f32 = undefined;

// We will use this renderer to draw into this window every frame.
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var texture: ?*c.SDL_Texture = null;
var font: ?*c.TTF_Font = null;
var surface: ?*c.SDL_Surface = null;

var frame_timer: std.time.Timer = undefined;

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

    // SDL init boilerplate
    assert(c.SDL_Init(c.SDL_INIT_VIDEO));
    assert(c.SDL_SetHint(c.SDL_HINT_MAIN_CALLBACK_RATE, "waitevent"));
    //assert(c.SDL_SetHint(c.SDL_HINT_CPU_FEATURE_MASK, "-all"));
    assert(c.SDL_CreateWindowAndRenderer(
        "examples/CATEGORY/NAME",
        800,
        600,
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    ));
    //assert(c.SDL_MaximizeWindow(window));

    // Timer for FPS display
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

    scale = c.SDL_GetWindowDisplayScale(window);

    // SDL_ttf: load font
    assert(c.TTF_Init());
    font = c.TTF_OpenFontIO(
        //c.SDL_IOFromConstMem(noto_sans, noto_sans.len),
        c.SDL_IOFromConstMem(inter_variable, inter_variable.len),
        true,
        16.0 * scale,
    );
    assert(font != null);
    c.TTF_SetFontHinting(font, c.TTF_HINTING_LIGHT);
    c.TTF_SetFontKerning(font, true);

    // 1. Calculate layout

    var window_w: c_int = undefined;
    var window_h: c_int = undefined;
    assert(c.SDL_GetWindowSizeInPixels(window, &window_w, &window_h));

    const root = c.YGNodeNew();
    c.YGNodeStyleSetFlexDirection(root, c.YGFlexDirectionRow);
    c.YGNodeStyleSetWidth(root, @as(f32, @floatFromInt(window_w)));
    c.YGNodeStyleSetHeight(root, @as(f32, @floatFromInt(window_h)));

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

    const child0color = c.SDL_Color{ .r = 239, .g = 240, .b = 241, .a = 255 };
    assert(c.SDL_SetRenderDrawColor(
        renderer,
        child0color.r,
        child0color.g,
        child0color.b,
        child0color.a,
    ));
    assert(c.SDL_RenderFillRect(renderer, &c.SDL_FRect{
        .h = c.YGNodeLayoutGetHeight(child0),
        .w = c.YGNodeLayoutGetWidth(child0),
        .x = c.YGNodeLayoutGetLeft(child0),
        .y = c.YGNodeLayoutGetTop(child0),
    }));

    assert(c.SDL_SetRenderDrawColor(renderer, 0, 100, 0, 255));
    assert(c.SDL_RenderFillRect(renderer, &c.SDL_FRect{
        .h = c.YGNodeLayoutGetHeight(child1),
        .w = c.YGNodeLayoutGetWidth(child1),
        .x = c.YGNodeLayoutGetLeft(child1),
        .y = c.YGNodeLayoutGetTop(child1),
    }));

    assert(c.SDL_SetRenderDrawColor(renderer, 255, 255, 0, 255));
    const text1_x = (c.YGNodeLayoutGetLeft(c.YGNodeGetParent(text1)) + c.YGNodeLayoutGetLeft(text1));
    const text1_y = (c.YGNodeLayoutGetTop(c.YGNodeGetParent(text1)) + c.YGNodeLayoutGetTop(text1));
    var buf: [32]u8 = undefined;
    assert(c.SDL_RenderDebugText(
        renderer,
        text1_x,
        text1_y,
        std.fmt.bufPrintZ(&buf, "text1: x={d}, y={d}", .{ text1_x, text1_y }) catch unreachable,
    ));

    const text2_x = (c.YGNodeLayoutGetLeft(c.YGNodeGetParent(text2)) + c.YGNodeLayoutGetLeft(text2));
    const text2_y = (c.YGNodeLayoutGetTop(c.YGNodeGetParent(text2)) + c.YGNodeLayoutGetTop(text2));
    assert(c.SDL_RenderDebugText(
        renderer,
        text2_x,
        text2_y,
        std.fmt.bufPrintZ(&buf, "text2: x={d}, y={d}", .{ text2_x, text2_y }) catch unreachable,
    ));

    assert(c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255));
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

    assert(c.SDL_RenderDebugText(
        renderer,
        0,
        20,
        std.fmt.bufPrintZ(&buf, "Window size: {d}x{d}", .{ window_w, window_h }) catch unreachable,
    ));

    var major: c_int = 0;
    var minor: c_int = 0;
    var patch: c_int = 0;
    c.TTF_GetFreeTypeVersion(&major, &minor, &patch);
    assert(c.SDL_RenderDebugText(
        renderer,
        0,
        30,
        std.fmt.bufPrintZ(&buf, "Freetype: {d}.{d}.{d}", .{ major, minor, patch }) catch unreachable,
    ));
    c.TTF_GetHarfBuzzVersion(&major, &minor, &patch);
    assert(c.SDL_RenderDebugText(
        renderer,
        150,
        30,
        std.fmt.bufPrintZ(&buf, "Harfbuzz: {d}.{d}.{d}", .{ major, minor, patch }) catch unreachable,
    ));

    assert(c.SDL_RenderDebugText(
        renderer,
        0,
        40,
        std.fmt.bufPrintZ(&buf, "Display scale: {d}", .{c.SDL_GetWindowDisplayScale(window)}) catch unreachable,
    ));
    assert(c.SDL_RenderDebugText(
        renderer,
        0,
        50,
        std.fmt.bufPrintZ(&buf, "Pixel density: {d}", .{c.SDL_GetWindowPixelDensity(window)}) catch unreachable,
    ));
    assert(c.SDL_RenderDebugText(
        renderer,
        0,
        60,
        std.fmt.bufPrintZ(
            &buf,
            "Display content scale: {d}",
            .{c.SDL_GetDisplayContentScale(c.SDL_GetDisplayForWindow(window))},
        ) catch unreachable,
    ));

    const text =
        \\Một hai ba bốn năm sáu bẩy tám chín mười. Kerning? QyTyA
        \\Home Desktop Documents Downloads Music Videos
        \\My Computer
    ;
    // Draw text using SDL_ttf:
    surface = c.TTF_RenderText_Blended_Wrapped(
        font.?,
        text,
        text.len,
        c.SDL_Color{ .r = 0, .g = 0, .b = 0, .a = c.SDL_ALPHA_OPAQUE },
        @intFromFloat(c.YGNodeLayoutGetWidth(child0)),
    );
    if (surface) |sf| {
        texture = c.SDL_CreateTextureFromSurface(renderer, sf);
        c.SDL_DestroySurface(sf);
    } else {
        return c.SDL_APP_FAILURE;
    }
    if (texture == null) {
        c.SDL_Log("Couldn't create text: %s\n", c.SDL_GetError());
        return c.SDL_APP_FAILURE;
    }

    var text_dst = c.SDL_FRect{ .x = 0, .y = 65 };
    assert(c.SDL_GetTextureSize(texture, &text_dst.w, &text_dst.h));
    assert(c.SDL_RenderTexture(renderer, texture, null, &text_dst));

    assert(c.SDL_RenderPresent(renderer));

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

// This function runs once at shutdown.
fn appQuit(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    _ = appstate;
    _ = result;
    // SDL will clean up the window/renderer for us.
}
