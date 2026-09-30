# Architecture

## Layers

```
application (toolkit, game, editor)
        |
Portal.Backend          THE API. One spec. Bodies: ports/null, ports/x11, ports/win32
        |
Portal.Framebuffer      Buffer + Clear/Fill/Blit/Blend/Clip. SPARK. No OS.
Portal.Events  = Bedrock.Input   Event, the closed variant record. Pure.
Portal.Input   = Bedrock.Input   Key, Modifiers, buttons, gamepads. Pure.
Portal                           defaults; Pixels, Point, Size, Rect, Color, Window_Id,
                                 Ticks come from Bedrock.Screen and Bedrock.Colors. Pure.
```

`Portal` and bedrock's packages are `Pure`: no state, no OS,
usable from anywhere including a bare-metal runtime later.
`Portal.Framebuffer` is SPARK and has no OS. `Portal.Backend` is the
only package with a platform behind it.

## Why a package body per port and not a tagged type

The obvious design is `type Backend is abstract tagged` with X11 and
Win32 as extensions, picked at runtime. We do not do that:

- A binary runs on exactly one platform. Choosing at runtime is
  choosing between one option.
- Dispatching calls need access-to-class-wide values. SPARK cannot
  reason about them; bare metal does not want them.
- With one body per port, `Portal.Backend.Poll` is a direct call. The
  contracts on the spec apply to every port, for free.

The port is picked by the `PORTAL_PORT` scenario variable in
`portal.gpr`, which adds `ports/<name>` to the source dirs. Adding a
port is adding a directory with one file, `portal-backend.adb`, plus
whatever thin bindings it needs (`portal-xlib.ads`, `portal-win32.ads`).

Generics were considered for the same job and rejected: the API does
not vary by type, only by body.

## Fundamental types

| Type | Definition | Why |
|---|---|---|
| `Pixels` | 16-bit signed | no display is wider; two sum in 32 bits |
| `Extent` | `Pixels` >= 0 | sizes can't be negative, by construction |
| `Ticks` | mod 2**64 ms | wraps never; subtract for intervals |
| `Window_Id` | 0 .. 8 | bounded, 0 is `No_Window` |
| `Color` | RGBA8888, 32 bits, explicit layout | one format, ports convert on Present |

## Events

`Portal.Events.Event` is a discriminated record with one variant per
`Event_Kind`. Closed on purpose: a handler is one `case`, the compiler
checks it is complete, and SPARK can prove things about it. SDL_Event is
the same idea in C. If a port has an event this record cannot express,
add a kind here; do not smuggle it through a user-data field.

Text input is its own event (`Text_Input`, one UTF-8 code point) and is
off by default; a text field enables it with `Set_Text_Input`. Key
events are scancodes (physical position); never build text on them.

## Framebuffer

`Buffer (Height, Width)` is a discriminated record holding a 2D array of
`Color`. Discriminants are the last valid index, so `Buffer (479, 639)`
is 640x480. Bounded by construction; no heap; every index is provable.

Primitives: `Clear`, `Fill` (opaque), `Fill_Blend` (source-over),
`Blit` (source-over copy), `Put`/`Get`. `Clip` is exposed so that the
clipping arithmetic can be tested and proved once and used by all.

Every primitive's postcondition states the buffer's dimensions are
unchanged; the proof targets (F1..F3 in the spec) are index safety and
"writes stay inside the clipped rect".

`Present` is the only way pixels leave the buffer. Ports convert to the
display's format on the way (X11 and Win32 want BGRX).

## Backend

The spec is small on purpose: lifetime, windows, present, events,
polled input state, cursor, clipboard, time. About 30 subprograms.
SDL3's video+events subsystems are ~150 functions; most of the
difference is things a toolkit does not need on day one (multiple
displays, fullscreen modes, window icons, drag and drop, HDR). Add them
when a client needs them, not before.

Contracts: every subprogram requires `Is_Initialized`; window
operations require `Is_Open (Window)`. Those two predicates are real
functions (not ghost) so that applications and tests can call them.

## Ports

A port is `ports/<name>/portal-backend.adb` plus bindings. Rules:

- `SPARK_Mode => Off` in the body only. The spec's contracts still
  apply and are still checked at runtime.
- Keep the event queue in the port (a bounded ring; `Push` feeds it
  too). `Poll` pumps the OS then dequeues.
- Translate at the edge. OS structures never escape the port.
- Bindings are hand-written from the C headers, only what is used,
  `External_Name` on every import. No generated 50k-line binding.

`ports/null` is the template. Copy it to start a new port.

### x11

Xlib, one connection, `XPutImage` for present, keysyms for keys. It
works and it is the slowest, simplest way to do each thing. The
`Milestone:` comments in the body list the upgrades: XShm, XInput2,
XKB, XIM, real selections, DPI.

### win32

One window class, `WndProc` translating messages, `StretchDIBits` for
present. Written without a Windows toolchain: semantic-checked with
`gcc -gnatc`, never linked. Expect small binding fixes.

## What is deliberately not here

- No renderer beyond the framebuffer. Triangles, textures, GPU: a
  separate package that takes the native handle the port can expose.
- No audio, no threads, no file dialogs, no networking. Different
  libraries.
- No bare-metal port. The pure packages are reusable there, but a
  windowing API is not what a panel with buttons wants. If that comes,
  it is a different top layer over the same leaves, not a fourth
  `ports/` directory.
