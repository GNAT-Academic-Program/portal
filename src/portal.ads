--  portal: the platform layer under a UI. Windows, input events, a
--  software framebuffer. What SDL and GLFW do, in Ada, for desktops
--  and for bare metal alike.
--
--  Root package: the fundamental types every other package shares.
--  Everything here is a plain scalar or a plain record. No access
--  types, no tagged types, no heap. A port that cannot represent one
--  of these types has found a bug in this spec, not in the port.

with Bedrock.Screen; use Bedrock.Screen;
with Bedrock.Colors; use Bedrock.Colors;

package Portal with SPARK_Mode, Pure is

   --  The fundamental types are bedrock's, the GAP foundation crate:
   --  Pixels, Point, Size, Rect, Ticks, Window_Id (Bedrock.Screen),
   --  Channel, Color (Bedrock.Colors), Key, Event (Bedrock.Input),
   --  Image (Bedrock.Buffers). A Color or a Key therefore means the
   --  same thing to portal, to yarlib on top of it, and to any tool
   --  that talks to both, with no conversion at any seam. The use
   --  clauses above make them visible throughout Portal's children; a
   --  client withs and uses the bedrock packages alongside Portal.

   Default_Size : constant Size := (Width => 800, Height => 600);
   --  What Open uses when a port is asked for (0, 0).

   Default_Clear : Color renames Black;
   --  What a freshly presented buffer shows before the first Clear.

end Portal;
