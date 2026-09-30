# portal

Windows, input events, and a software framebuffer for Ada. What SDL
and GLFW do, without the C, with contracts.

GNAT Academic Program capstone project. Proposal title: *Ada PAL:
Portable Alternative to SDL/GLFW*.

## What it is

The layer between an application and the desktop. Open a window, get
keyboard, mouse and gamepad events, put pixels on screen. That is all a
UI toolkit or a 2D game needs from the operating system, and it is what
every one of them re-implements or pulls a C library for.

- **One spec, one body per platform.** `Portal.Backend` is the API.
  X11, Win32 (and later Wayland, Cocoa) are bodies of it, chosen at
  build time. No dispatching, no function pointers, one port per
  binary.
- **Software framebuffer.** The application draws into an RGBA buffer;
  `Present` copies it to the window. Enough for a toolkit, a 2D game,
  an editor. A GPU path is a later package, not a v1 concern.
- **Plain types, contracts, SPARK.** Events are a closed variant
  record. The framebuffer is bounded and provable. Ports are the only
  non-SPARK code, and they are thin.

## What is in the seed

```
src/portal.ads              defaults; the types are bedrock's (see below)          done
src/portal-input.ads        Key, Modifiers, Mouse_Button, Gamepad_*               done
src/portal-events.ads       Event: the closed variant record                      done
src/portal-framebuffer.ads  Buffer, Clear, Fill, Fill_Blend, Blit, Blend, Clip    done, SPARK
src/portal-backend.ads      THE API: windows, present, poll, input, cursor, clip  done
ports/null/                 no display; CI and tests                              done
ports/x11/                  Xlib port                                              works, minimal
ports/win32/                Win32 port                                             semantic-checked, never linked
adapters/adi2/              plan for putting adi2 on portal                        README only
showcase/                   window + bouncing square + event log                   acceptance test
tests/                      unit tests, no framework                               extend as you go
```

Read `ARCHITECTURE.md` before touching anything.

## Types come from bedrock

`Pixels`, `Point`, `Size`, `Rect`, `Ticks`, `Window_Id`, `Color`,
`Key`, `Event` and the pixel `Image` are declared in
[bedrock](https://github.com/GNAT-Academic-Program/bedrock), the GAP
foundation crate, and portal uses them as is. `Portal.Input` and
`Portal.Events` are renamings of `Bedrock.Input`. That is what lets
yarlib run on portal with no conversion at the seam, and it is why a
client says:

```ada
with Bedrock.Screen; use Bedrock.Screen;
with Bedrock.Colors; use Bedrock.Colors;
with Portal.Input;   use Portal.Input;
```

bedrock changes only through the GAP coordinator; if portal needs a
new fundamental type, that is a conversation, not a commit.

## Build

Three [Alire](https://alire.ada.dev) crates. The showcase and the tests
pin the library by path.

Pick a port first. It is an environment variable read by `portal.gpr`:

```
export PORTAL_PORT=x11      # Linux: needs libx11-dev
set PORTAL_PORT=win32       # Windows, cmd
$env:PORTAL_PORT="win32"    # Windows, PowerShell
```

Unset, the port is `null`: builds anywhere, opens nothing, and the
showcase exits on its own after 100 frames. That is what CI runs.

Library:

```
alr build
```

Showcase (opens a window; Escape or close to quit):

```
cd showcase
alr build
alr run
```

Tests (null port; exit code is non-zero on failure):

```
cd tests
alr build
./bin/tests
```

SPARK, from the library directory:

```
alr with gnatprove
alr exec -- gnatprove -P portal.gpr --mode=flow
alr exec -- gnatprove -P portal.gpr --mode=all
```

Contracts are checked at runtime in every build (`-gnata`). Loop
invariants are not (`policy.adc`); they are for the prover.

## Milestones

1. **The Win32 port links and runs.** It was written blind. Build it,
   fix what the compiler says, see the window, send a PR to the seed.
   One afternoon for a Windows team.
2. **The showcase feels right on both ports.** Resize follows the
   window, keys are layout-independent, text input handles dead keys
   and the IME, the wheel scrolls smoothly, the cursor changes, the
   clipboard is the real system clipboard. Each of these is a listed
   `Milestone:` comment in a port body. Each is a PR with a test or a
   manual check script.
3. **Proof.** `Portal.Framebuffer` proves clean under
   `gnatprove --mode=all` (targets F1 to F3 in its spec).
4. **A second Linux port: Wayland.** Same spec, new body. This is
   where the spec gets tested for real.
5. **adi2 on portal.** See `adapters/adi2/README.md`. The year's
   headline if it lands.

## Rules of the road

- Warnings are errors. Style checks are on. CI runs on every push, on
  Linux (null and x11) and Windows (win32).
- `src/` is SPARK and has no OS calls. Everything platform-specific is
  under `ports/<name>/` and is the only place `SPARK_Mode => Off` is
  allowed.
- A change to `Portal.Backend` (the spec) is a change to every port.
  Make it, update every port body (`null` at minimum), then argue for it.
- Fixed pixel format (RGBA8888), fixed event set. If a port cannot
  express something, the spec is wrong, fix the spec, not the port.

See `CONTRIBUTING.md` for the fork workflow.

## Contact

Olivier Henley, GAP Coordinator, AdaCore. Weekly meeting, plus the
project Discord.

## License

Apache-2.0. See `LICENSE`.
