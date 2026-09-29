--  portal: the platform layer under a UI. Windows, input events, a
--  software framebuffer. What SDL and GLFW do, in Ada, for desktops
--  and for bare metal alike.
--
--  Root package: the fundamental types every other package shares.
--  Everything here is a plain scalar or a plain record. No access
--  types, no tagged types, no heap. A port that cannot represent one
--  of these types has found a bug in this spec, not in the port.

package Portal with SPARK_Mode, Pure is

   ---------------------------------------------------------------------
   --  Geometry, in physical pixels
   ---------------------------------------------------------------------

   type Pixels is range -2 ** 15 .. 2 ** 15 - 1;
   --  A coordinate or an extent on screen. 16 bits: no display is
   --  wider than 32767 px and the sum of two fits in 32 bits.

   subtype Extent is Pixels range 0 .. Pixels'Last;

   type Point is record
      X, Y : Pixels := 0;
   end record;

   type Size is record
      Width, Height : Extent := 0;
   end record;

   type Rect is record
      Origin : Point;
      Extent : Size;
   end record;

   ---------------------------------------------------------------------
   --  Time
   ---------------------------------------------------------------------

   type Ticks is mod 2 ** 64;
   --  Milliseconds since the port started. Wraps after 584 million
   --  years; subtract two values to get an interval.

   ---------------------------------------------------------------------
   --  Windows
   ---------------------------------------------------------------------

   Max_Windows : constant := 8;
   --  A UI has a main window and a few popups. Bounded on purpose.

   type Window_Id is range 0 .. Max_Windows;
   No_Window : constant Window_Id := 0;
   subtype Valid_Window_Id is Window_Id range 1 .. Max_Windows;

   ---------------------------------------------------------------------
   --  Pixels in the framebuffer
   ---------------------------------------------------------------------

   type Channel is mod 2 ** 8;

   type Color is record
      R, G, B, A : Channel := 0;
   end record
     with Size => 32;
   --  RGBA8888, straight alpha. One format, on purpose: a port converts
   --  on present if its display wants something else.

   for Color use record
      R at 0 range 0 .. 7;
      G at 1 range 0 .. 7;
      B at 2 range 0 .. 7;
      A at 3 range 0 .. 7;
   end record;

   Black       : constant Color := (0, 0, 0, 255);
   White       : constant Color := (255, 255, 255, 255);
   Transparent : constant Color := (0, 0, 0, 0);

end Portal;
