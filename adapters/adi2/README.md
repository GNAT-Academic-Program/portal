# adi2 on portal

adi2 today has no platform seam: `src/adi-backend.ads` is empty and
SDL3 calls sit in 28 toolkit files (window, events, render, font,
image, widgets). About 590 distinct SDL symbols, in three layers:

1. platform: window, events, mouse, keyboard, cursor, clipboard,
   displays, dialogs, filesystem, locale
2. renderer: SDL_Renderer, FillRect, RenderGeometry (triangles),
   textures, surfaces, blend modes, ReadPixels
3. content: SDL_ttf (fonts, shaping), SDL_image (decoders, animations)

portal is layer 1. Layers 2 and 3 are out of scope for the year.

## The milestone

adi2 opens its window, gets its events, and presents its frames through
portal, with SDL's renderer, ttf and image left in place. Steps:

1. In adi2, write `Adi.Backend`: the layer-1 subset as an Ada spec
   with no SDL types. This is design work, done with the adi2 author.
2. Move adi2's existing SDL calls behind that spec: `Adi.Backend.SDL`.
   adi2 gets a platform seam it did not have; nothing else changes.
3. Implement `Adi.Backend.Portal` in this directory over
   `Portal.Backend`. The SDL renderer draws into a texture that the
   adapter copies to a `Portal.Framebuffer.Buffer` and presents.
   (Or, if adi2 gains a software renderer, straight into the buffer.)
4. adi2's test suite passes with `Adi.Backend.Portal`.

Step 1 and 2 are a pull request to adi2. Step 3 lives here. Step 4 is
the year's result.

## What is here

Nothing yet but this README. The adapter cannot be written before
`Adi.Backend` exists. Start with step 1.
