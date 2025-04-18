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
const inter = @embedFile("Inter-Regular.otf");
const nebula_sans = @embedFile("NebulaSans-Book.ttf");

var scale: f32 = undefined;

// We will use this renderer to draw into this window every frame.
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;

var texture: ?*c.SDL_Texture = null;
var surface: ?*c.SDL_Surface = null;
var text_scale: f32 = 1;

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
    var buf: [128]u8 = undefined;
    assert(c.SDL_CreateWindowAndRenderer(
        std.fmt.bufPrintZ(&buf, "{d}x Text Shaping", .{text_scale}) catch unreachable,
        900,
        700,
        c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        &window,
        &renderer,
    ));
    //assert(c.SDL_MaximizeWindow(window));

    // Timer for FPS display
    frame_timer = std.time.Timer.start() catch unreachable;

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

fn dialogFileCallback(userdata: ?*anyopaque, filelist: [*c]const [*c]const u8, filter: c_int) callconv(.C) void {
    _ = userdata;
    _ = filter;

    if (filelist == null) {
        std.debug.print(">> error: {s}", .{c.SDL_GetError()});
        return;
    }

    if (filelist[0] == null) {
        std.debug.print(">> no file chosen\n", .{});
        return;
    }

    var i: usize = 0;
    while (true) {
        const file = filelist[i];
        if (file == null) {
            std.debug.print(">> filelist[{d}] is null. Aborted.\n", .{i});
            return;
        }
        std.debug.print(">> found file: {s}\n", .{file});
        i += 1;
    }
}

// This function runs when a new event (mouse input, keypresses, etc) occurs.
fn appEvent(appstate: ?*anyopaque, event: ?*c.SDL_Event) callconv(.c) c.SDL_AppResult {
    _ = appstate;

    switch (event.?.type) {
        c.SDL_EVENT_QUIT => return c.SDL_APP_SUCCESS,
        c.SDL_EVENT_KEY_DOWN => {
            switch (event.?.key.key) {
                c.SDLK_UP => text_scale += 1,
                c.SDLK_DOWN => if (text_scale > 1) {
                    text_scale -= 1;
                },
                c.SDLK_O => {
                    if (event.?.key.mod & c.SDL_KMOD_CTRL != 0) {
                        // ctrl + o to show "Open File" dialog
                        const filters = &[_]c.SDL_DialogFileFilter{
                            .{ .name = "MP4 Videos", .pattern = "mp4" },
                            .{ .name = "JPEG Images", .pattern = "jpg;jpeg" },
                            .{ .name = "All Files", .pattern = "*" },
                        };
                        c.SDL_ShowOpenFileDialog(
                            &dialogFileCallback,
                            null,
                            window,
                            filters,
                            filters.len,
                            "",
                            true,
                        );
                    }
                },
                else => {},
            }
            var buf: [128]u8 = undefined;
            assert(c.SDL_SetWindowTitle(
                window,
                std.fmt.bufPrintZ(&buf, "{d}x Text Shaping", .{text_scale}) catch unreachable,
            ));
        },
        else => {},
    }

    return c.SDL_APP_CONTINUE;
}

// This function runs once per frame, and is the heart of the program.
fn appIterate(appstate: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    _ = appstate;

    const frame_time_ns = frame_timer.lap();
    const fps = 1_000_000_000 / frame_time_ns;

    scale = c.SDL_GetWindowDisplayScale(window);

    // 1. Calculate layout

    var window_w: c_int = undefined;
    var window_h: c_int = undefined;
    assert(c.SDL_GetWindowSizeInPixels(window, &window_w, &window_h));

    const root = c.YGNodeNew();
    defer c.YGNodeFree(root);
    c.YGNodeStyleSetFlexDirection(root, c.YGFlexDirectionRow);
    c.YGNodeStyleSetWidth(root, @as(f32, @floatFromInt(window_w)));
    c.YGNodeStyleSetHeight(root, @as(f32, @floatFromInt(window_h)));

    const child0 = c.YGNodeNew();
    defer c.YGNodeFree(child0);
    c.YGNodeStyleSetFlexGrow(child0, 2.0);
    c.YGNodeStyleSetMargin(child0, c.YGEdgeRight, 10.0);
    c.YGNodeInsertChild(root, child0, 0);

    const child1 = c.YGNodeNew();
    defer c.YGNodeFree(child1);
    c.YGNodeStyleSetFlexGrow(child1, 1.0);
    c.YGNodeInsertChild(root, child1, 1);

    const text1 = c.YGNodeNew();
    defer c.YGNodeFree(text1);
    c.YGNodeStyleSetFlexGrow(text1, 1.0);
    c.YGNodeInsertChild(child1, text1, 0);

    const text2 = c.YGNodeNew();
    defer c.YGNodeFree(text2);
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

    // SDL_ttf
    assert(c.TTF_Init());
    inline for (.{
        c.TTF_HINTING_LIGHT,
        c.TTF_HINTING_LIGHT_SUBPIXEL,
        c.TTF_HINTING_NORMAL,
        c.TTF_HINTING_NONE,
    }, 0..) |hint, i| {
        const font = c.TTF_OpenFontIO(
            c.SDL_IOFromConstMem(inter_variable, inter_variable.len),
            true,
            16 * text_scale * scale,
        );
        assert(font != null);
        defer c.TTF_CloseFont(font);
        c.TTF_SetFontHinting(font, hint);
        c.TTF_SetFontKerning(font, true);

        const text =
            switch (hint) {
                c.TTF_HINTING_LIGHT => "Light",
                c.TTF_HINTING_LIGHT_SUBPIXEL => "Light_Subpixel",
                c.TTF_HINTING_NORMAL => "Normal",
                c.TTF_HINTING_NONE => "None",
                else => unreachable,
            } ++ ":\n" ++
            \\Một bốn bẩy mười. Kerning? yTyA
            \\Home Desktop Documents Downloads Music Videos My Computer
            \\Stanley Kubrick was an American film director, screenwriter, and producer of many films
            ;

        // Draw text using SDL_ttf:
        const engine = c.TTF_CreateRendererTextEngine(renderer);
        defer c.TTF_DestroyRendererTextEngine(engine);
        const ttf_text = c.TTF_CreateText(engine, font, text, text.len);
        defer c.TTF_DestroyText(ttf_text);
        assert(c.TTF_SetTextColor(ttf_text, 0, 0, 0, 255));
        assert(c.TTF_SetTextWrapWidth(ttf_text, @intFromFloat(c.YGNodeLayoutGetWidth(child0))));
        assert(c.TTF_DrawRendererText(ttf_text, 0, 85 + 140 * scale * i));
    }

    assert(c.SDL_RenderPresent(renderer));

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

// This function runs once at shutdown.
fn appQuit(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    _ = appstate;
    _ = result;
    // SDL will clean up the window/renderer for us.
}
