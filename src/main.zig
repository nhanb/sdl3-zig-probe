const std = @import("std");
const assert = std.debug.assert;
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_MAIN_HANDLED' should be defined before including 'SDL_main.h'.
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

pub fn main() u8 {
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_SetMainReady()' should be called before calling 'SDL_Init()'.
    c.SDL_SetMainReady();

    // This is more or less what 'SDL_main.h' does behind the curtains.
    const status = c.SDL_EnterAppMainCallbacks(0, null, appInit, appIterate, appEvent, appQuit);

    return @bitCast(@as(i8, @truncate(status)));
}

// We will use this renderer to draw into this window every frame.
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;

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

    assert(c.SDL_SetRenderDrawColor(renderer, 100, 0, 0, c.SDL_ALPHA_OPAQUE));
    assert(c.SDL_RenderClear(renderer));

    var window_w: c_int = undefined;
    var window_h: c_int = undefined;
    assert(c.SDL_GetWindowSize(window, &window_w, &window_h));
    std.debug.print(
        ">> {d}: {d}x{d}\n",
        .{ std.time.milliTimestamp(), window_w, window_h },
    );

    assert(c.SDL_SetRenderDrawColor(renderer, 0, 0, 100, 255));
    assert(c.SDL_RenderFillRect(renderer, &c.SDL_FRect{
        .h = 100,
        .w = 100,
        .x = @floatFromInt(@divTrunc(window_w, 2) - 100 / 2),
        .y = @floatFromInt(@divTrunc(window_h, 2) - 100 / 2),
    }));
    assert(c.SDL_RenderPresent(renderer));

    return c.SDL_APP_CONTINUE; // carry on with the program!
}

// This function runs once at shutdown.
fn appQuit(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    _ = appstate;
    _ = result;
    // SDL will clean up the window/renderer for us.
}
