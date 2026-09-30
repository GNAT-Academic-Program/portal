--  Unit tests for the pure parts: framebuffer and event types. Plain
--  Ada, no framework, non-zero exit on failure. Runs on the null port
--  in CI. Extend as you implement.

with Bedrock.Screen; use Bedrock.Screen;
with Bedrock.Colors; use Bedrock.Colors;
with Ada.Command_Line;
with Ada.Text_IO;        use Ada.Text_IO;
with Portal;             use Portal;
with Portal.Backend;     use Portal.Backend;
with Portal.Framebuffer; use Portal.Framebuffer;
with Portal.Input;       use Portal.Input;

procedure Tests is

   Failures : Natural := 0;

   procedure Check (Name : String; Condition : Boolean) is
   begin
      Put_Line ((if Condition then "PASS  " else "FAIL  ") & Name);
      if not Condition then
         Failures := Failures + 1;
      end if;
   end Check;

   ---------------------------------------------------------------------

   procedure Test_Types is
   begin
      Check ("Color is 32 bits", Color'Size = 32);
      Check ("Modifiers is 8 bits", Modifiers'Size = 8);
      Check ("Pixels is 16 bits", Pixels'Size = 16);
   end Test_Types;

   procedure Test_Blend is
      Red   : constant Color := (255, 0, 0, 255);
      Half  : constant Color := (255, 0, 0, 128);
      Clear : constant Color := (255, 0, 0, 0);
      Blue  : constant Color := (0, 0, 255, 255);
      M     : constant Color := Blend (Half, Blue);
   begin
      Check ("opaque over: src",     Blend (Red, Blue) = Red);
      Check ("transparent over: dst", Blend (Clear, Blue) = Blue);
      Check ("half over: mixed R",   M.R in 127 .. 129);
      Check ("half over: mixed B",   M.B in 126 .. 128);
      Check ("half over: alpha 255", M.A = 255);
   end Test_Blend;

   procedure Test_Framebuffer is
      B  : Buffer (9, 19);   --  20 x 10
      X0, Y0, X1, Y1 : Extent;
      Empty : Boolean;
   begin
      Check ("Width",  Width (B) = 20);
      Check ("Height", Height (B) = 10);
      Check ("In_Bounds corner", In_Bounds (B, (19, 9)));
      Check ("not In_Bounds",    not In_Bounds (B, (20, 9)));

      Clear (B, Black);
      Check ("Clear", Get (B, (5, 5)) = Black and Get (B, (19, 9)) = Black);

      Put (B, (3, 4), White);
      Check ("Put/Get", Get (B, (3, 4)) = White);

      Clip (B, ((-5, -5), (10, 10)), X0, Y0, X1, Y1, Empty);
      Check ("Clip top-left overhang", not Empty and X0 = 0 and Y0 = 0 and X1 = 4 and Y1 = 4);
      Clip (B, ((15, 5), (100, 100)), X0, Y0, X1, Y1, Empty);
      Check ("Clip bottom-right overhang", not Empty and X0 = 15 and Y0 = 5 and X1 = 19 and Y1 = 9);
      Clip (B, ((30, 30), (5, 5)), X0, Y0, X1, Y1, Empty);
      Check ("Clip fully outside", Empty);
      Clip (B, ((2, 2), (0, 5)), X0, Y0, X1, Y1, Empty);
      Check ("Clip zero width", Empty);

      Clear (B, Black);
      Fill (B, ((2, 2), (3, 3)), White);
      Check ("Fill inside",  Get (B, (2, 2)) = White and Get (B, (4, 4)) = White);
      Check ("Fill outside", Get (B, (5, 5)) = Black and Get (B, (1, 1)) = Black);

      Fill (B, ((-2, -2), (4, 4)), (9, 9, 9, 0));
      Check ("Fill clipped, alpha ignored", Get (B, (0, 0)) = (9, 9, 9, 255));

      Clear (B, Black);
      Fill_Blend (B, ((0, 0), (20, 10)), (255, 255, 255, 128));
      Check ("Fill_Blend", Get (B, (10, 5)).R in 127 .. 129);

      declare
         S : Buffer (1, 1);  --  2 x 2 white
      begin
         Clear (S, White);
         Clear (B, Black);
         Blit (B, S, (19, 9));
         Check ("Blit clipped corner", Get (B, (19, 9)) = White and Get (B, (18, 8)) = Black);
         Blit (B, S, (100, 100));
         Check ("Blit fully outside is no-op", Get (B, (19, 9)) = White);
      end;
   end Test_Framebuffer;

   procedure Test_Events is
      E : Event := (Kind => Key_Down, Time => 5, Window => 1,
                    Key => Key_A, Mods => No_Modifiers, Repeat => False);
   begin
      Check ("event kind", E.Kind = Key_Down and E.Key = Key_A);
      E := (Kind => Text_Input, Time => 0, Window => 1, Text => "a   ", Length => 1);
      Check ("text event", E.Text (1 .. E.Length) = "a");
   end Test_Events;

   procedure Test_Backend_Queue is
      OK : Boolean;
      E  : Event;
      W  : Window_Id;
   begin
      Initialize (OK);
      Check ("Initialize", OK and Is_Initialized);
      Create_Window ("t", (10, 10), (others => <>), W);
      Check ("Create_Window", W /= No_Window and Is_Open (W));
      Check ("Get_Size", Get_Size (W) = (10, 10));
      Push ((Kind => Mouse_Enter, Time => 1, Window => W));
      Push ((Kind => Mouse_Leave, Time => 2, Window => W));
      Poll (E);
      Check ("Push/Poll order 1", E.Kind = Mouse_Enter);
      Poll (E);
      Check ("Push/Poll order 2", E.Kind = Mouse_Leave);
      Set_Clipboard ("hello");
      declare
         S : String (1 .. 16);
         L : Natural;
      begin
         Get_Clipboard (S, L);
         Check ("clipboard round trip", S (1 .. L) = "hello");
      end;
      Destroy_Window (W);
      Check ("Destroy_Window", not Is_Open (W));
      Finalize;
      Check ("Finalize", not Is_Initialized);
   end Test_Backend_Queue;

begin
   Test_Types;
   Test_Blend;
   Test_Framebuffer;
   Test_Events;
   Test_Backend_Queue;

   New_Line;
   if Failures = 0 then
      Put_Line ("all tests passed");
   else
      Put_Line (Failures'Image & " failure(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
