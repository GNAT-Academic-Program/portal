--  A software framebuffer: a bounded RGBA8888 image the application
--  draws into, and the port copies to the window on Present.
--
--  This is the whole "renderer" of portal v1. It is deliberately
--  simple: fill, blit, per-pixel access. It is what a bare-metal
--  target has anyway, and on the desktop it is enough for a toolkit,
--  a 2D game, or a preview window. A GPU path can come later as a
--  separate package that hands the port a native surface instead.
--
--  Coordinates are (0, 0) top-left, X to the right, Y down.
--
--  PROOF TARGET
--    F1  No out-of-bounds pixel access, ever (index checks discharged).
--    F2  Fill and Blit never write outside the destination rectangle
--        clipped to the buffer.
--    F3  Blend is a total function on Color (no overflow in the mix).

package Portal.Framebuffer with SPARK_Mode is

   Max_Width  : constant := 4096;
   Max_Height : constant := 4096;
   --  Enough for a 4K display. A bare-metal port instantiates the
   --  buffer at its panel size; the desktop ports at the window size.

   subtype Column is Extent range 0 .. Max_Width - 1;
   subtype Row    is Extent range 0 .. Max_Height - 1;

   type Pixel_Array is array (Row range <>, Column range <>) of Color
     with Pack;

   type Buffer (Height : Row; Width : Column) is record
      Pixels : Pixel_Array (0 .. Height, 0 .. Width) := [others => [others => Transparent]];
   end record;
   --  Height and Width are the LAST valid index, so a 640x480 buffer
   --  is Buffer (479, 639). Bounded by discriminant: no heap.

   function Width  (B : Buffer) return Extent is (Extent (B.Width) + 1);
   function Height (B : Buffer) return Extent is (Extent (B.Height) + 1);

   function In_Bounds (B : Buffer; P : Point) return Boolean is
     (P.X in 0 .. Pixels (B.Width) and then P.Y in 0 .. Pixels (B.Height));

   ---------------------------------------------------------------------
   --  Pixels
   ---------------------------------------------------------------------

   function Get (B : Buffer; P : Point) return Color is
     (B.Pixels (Row (P.Y), Column (P.X)))
     with Pre => In_Bounds (B, P);

   procedure Put (B : in out Buffer; P : Point; C : Color)
     with
       Pre  => In_Bounds (B, P),
       Post => Get (B, P) = C
               and then B.Width = B.Width'Old and then B.Height = B.Height'Old;

   ---------------------------------------------------------------------
   --  Blending
   ---------------------------------------------------------------------

   function Blend (Src, Dst : Color) return Color;
   --  Source-over with straight alpha: Src drawn on top of Dst.
   --  Src.A = 255 returns Src; Src.A = 0 returns Dst.

   ---------------------------------------------------------------------
   --  Primitives
   ---------------------------------------------------------------------

   procedure Clear (B : in out Buffer; C : Color)
     with Post => B.Width = B.Width'Old and then B.Height = B.Height'Old
                  and then (for all Y in 0 .. B.Height =>
                              (for all X in 0 .. B.Width => B.Pixels (Y, X) = C));

   procedure Fill (B : in out Buffer; R : Rect; C : Color)
     with Post => B.Width = B.Width'Old and then B.Height = B.Height'Old;
   --  Opaque fill of R clipped to the buffer. C.A is ignored; use
   --  Fill_Blend for translucency. A rect entirely off-buffer is a
   --  no-op.

   procedure Fill_Blend (B : in out Buffer; R : Rect; C : Color)
     with Post => B.Width = B.Width'Old and then B.Height = B.Height'Old;
   --  Like Fill, source-over.

   procedure Blit
     (Dst    : in out Buffer;
      Src    : Buffer;
      At_Pos : Point)
     with Post => Dst.Width = Dst.Width'Old and then Dst.Height = Dst.Height'Old;
   --  Copies Src onto Dst with its top-left at At_Pos, clipped to Dst,
   --  source-over. Src may be larger than Dst or partly outside it.

   ---------------------------------------------------------------------
   --  Clipping helper, exposed for tests and proofs
   ---------------------------------------------------------------------

   procedure Clip
     (B      : Buffer;
      R      : Rect;
      X0, Y0 : out Extent;
      X1, Y1 : out Extent;
      Empty  : out Boolean)
     with Post => (if not Empty then
                     X0 <= X1 and then Y0 <= Y1
                     and then X1 <= B.Width and then Y1 <= B.Height);
   --  The inclusive pixel range of R inside B. Empty when nothing of
   --  R lies inside the buffer (including zero-extent rects).

end Portal.Framebuffer;
