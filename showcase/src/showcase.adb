--  The showcase: the acceptance test for the project.
--
--  Opens a window, draws a bouncing square and a mouse-following
--  square into a software framebuffer, presents at ~60 Hz, prints
--  every event to stdout. Escape or the close button quits.
--
--  Against the null port (CI) there is no window: the loop runs until
--  the port's synthetic Quit and the program exits 0. That is the
--  whole test: build, run, exit clean, on every port.

with Bedrock.Screen; use Bedrock.Screen;
with Ada.Text_IO;        use Ada.Text_IO;
with Portal;             use Portal;
with Portal.Backend;     use Portal.Backend;
with Portal.Framebuffer; use Portal.Framebuffer;
with Portal.Input;       use Portal.Input;

procedure Showcase is

   W_Px : constant := 640;
   H_Px : constant := 480;

   Frame : Buffer (H_Px - 1, W_Px - 1);
   Win   : Window_Id;
   OK    : Boolean;
   E     : Event;

   --  A square bouncing around
   Box_X, Box_Y   : Pixels := 100;
   Box_DX, Box_DY : Pixels := 3;
   Box_Size       : constant Extent := 48;

   Mouse : Point := (0, 0);
   Frames : Natural := 0;
   Running : Boolean := True;

   procedure Log (S : String) is
   begin
      Put_Line (S);
   end Log;

begin
   Initialize (OK);
   if not OK then
      Log ("portal: no display; nothing to show");
      return;
   end if;

   Create_Window ("portal showcase", (W_Px, H_Px), (others => <>), Win);
   if Win = No_Window then
      Log ("portal: could not create a window");
      Finalize;
      return;
   end if;
   Set_Text_Input (Win, True);

   while Running loop
      --  Drain the queue
      loop
         Poll (E);
         exit when E.Kind = None;
         case E.Kind is
            when Quit | Window_Close =>
               Log ("quit"); Running := False;
            when Key_Down =>
               Log ("key down " & E.Key'Image & (if E.Repeat then " (repeat)" else ""));
               if E.Key = Key_Escape then
                  Running := False;
               end if;
            when Key_Up =>
               Log ("key up   " & E.Key'Image);
            when Text_Input =>
               Log ("text     '" & E.Text (1 .. E.Length) & "'");
            when Mouse_Move =>
               Mouse := E.At_Pos;
            when Mouse_Down =>
               Log ("mouse down " & E.Button'Image & " at" & E.Where.X'Image & "," & E.Where.Y'Image);
            when Mouse_Up =>
               Log ("mouse up   " & E.Button'Image);
            when Mouse_Wheel =>
               Log ("wheel" & E.Wheel_Y'Image);
            when Window_Resized =>
               Log ("resized to" & E.Size.Width'Image & "x" & E.Size.Height'Image);
            when others =>
               Log (E.Kind'Image);
         end case;
      end loop;

      --  Animate
      Box_X := Box_X + Box_DX;
      Box_Y := Box_Y + Box_DY;
      if Box_X <= 0 or else Box_X + Pixels (Box_Size) >= W_Px then
         Box_DX := -Box_DX;
      end if;
      if Box_Y <= 0 or else Box_Y + Pixels (Box_Size) >= H_Px then
         Box_DY := -Box_DY;
      end if;

      --  Draw
      Clear (Frame, (30, 30, 40, 255));
      Fill (Frame, ((0, 0), (W_Px, 8)), (70, 110, 200, 255));            --  top bar
      Fill (Frame, ((Box_X, Box_Y), (Box_Size, Box_Size)), (240, 180, 60, 255));
      Fill_Blend (Frame, ((Mouse.X - 16, Mouse.Y - 16), (32, 32)), (255, 80, 80, 128));

      Present (Win, Frame);
      Frames := Frames + 1;
      Sleep (16);
   end loop;

   Log ("frames:" & Frames'Image);
   Destroy_Window (Win);
   Finalize;
end Showcase;
