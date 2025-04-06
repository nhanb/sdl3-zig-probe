Evaluating SDL3 as the base for a cross-platform, render-on-demand, hidpi-aware,
crisp, high-performance, immediate-mode GUI.

- Cross-platform: sdl3, 'nuff said
- Render on demand: `SDL_HINT_MAIN_CALLBACK_RATE = "waitevent"`
- Crisp text rendering with `SDL_ttf` which uses `freetype` & `harfbuzz`
- High performance:
    + smooth window resize with SDL3's new [main callbacks][1]
    + fast layout using facebook's [Yoga engine][2]

# Compile

Currently `SDL3_ttf` seems to [trigger UB][5], so we have to disable UBSan using
`ReleaseFast` for it to not crash immediately.

```sh
# Statically compile as many deps as possible:
zig build run -Doptimize=ReleaseFast

# Or, to use system libraries:
zig build run -fsys=sdl -fsys=sdl_ttf -fsys=freetype -fsys=harfbuzz -Doptimize=ReleaseFast
```

[Yoga](https://www.yogalayout.dev/) is currently not packaged for Arch Linux, so
it's always compiled from source & statically linked. Actually `sdl3_ttf` isn't
packaged either, but it's on AUR and probably gonna be official soon.

# Runtime

KDE Plasma 6.3 doesn't support [fifo-v1][3] (6.4 will, but it's not released
yet), so SDL3 still [defaults][4] to Xwayland on my computer.
We can still force Wayland by setting an envar: `SDL_VIDEODRIVER=wayland`.

[1]: https://wiki.libsdl.org/SDL3/README/main-functions
[2]: https://www.yogalayout.dev/
[3]: https://invent.kde.org/plasma/kwin/-/merge_requests/6474
[4]: https://github.com/libsdl-org/SDL/pull/9345#issuecomment-2023413737
[5]: https://github.com/libsdl-org/SDL_ttf/issues/537
