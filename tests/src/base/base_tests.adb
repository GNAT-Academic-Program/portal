with AUnit.Assertions;

with Bedrock.Screen; use Bedrock.Screen;
with Bedrock.Colors; use Bedrock.Colors;
with Portal;
with Portal.Backend;     use Portal.Backend;
with Portal.Framebuffer; use Portal.Framebuffer;
with Portal.Input;       use Portal.Input;

package body Base_Tests is

   procedure Test_Backend_Lifecycle
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Types (T : in out AUnit.Test_Cases.Test_Case'Class) is
      --  This only needs done if the test case is not used
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Color'Size = 32, "Color is 32 bits");
      AUnit.Assertions.Assert (Modifiers'Size = 8, "Modifiers is 8 bits");
      AUnit.Assertions.Assert (Pixels'Size = 16, "Pixels is 16 bits");
   end Test_Types;

   procedure Test_Blend (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Red   : constant Color := (255, 0, 0, 255);
      Half  : constant Color := (255, 0, 0, 128);
      Clear : constant Color := (255, 0, 0, 0);
      Blue  : constant Color := (0, 0, 255, 255);
      M     : constant Color := Blend (Half, Blue);
   begin
      AUnit.Assertions.Assert (Blend (Red, Blue) = Red, "opaque over: src");
      AUnit.Assertions.Assert (
         Blend (Clear, Blue) = Blue, "transparent over: dst");
      AUnit.Assertions.Assert (M.R in 127 .. 129, "half over: mixed R");
      AUnit.Assertions.Assert (M.B in 126 .. 128, "half over: mixed B");
      AUnit.Assertions.Assert (M.A = 255, "half over: alpha 255");
   end Test_Blend;

   procedure Test_Framebuffer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      B  : Buffer (9, 19);   --  20 x 10
      X0, Y0, X1, Y1 : Extent;
      Empty : Boolean;
   begin
      AUnit.Assertions.Assert (Width (B) = 20, "Width");
      AUnit.Assertions.Assert (Height (B) = 10, "Height");
      AUnit.Assertions.Assert (In_Bounds (B, (19, 9)), "In_Bounds corner");
      AUnit.Assertions.Assert (not In_Bounds (B, (20, 9)), "not In_Bounds");

      Clear (B, Black);
      AUnit.Assertions.Assert (
         Get (B, (5, 5)) = Black and Get (B, (19, 9)) = Black, "Clear");

      Put (B, (3, 4), White);
      AUnit.Assertions.Assert (Get (B, (3, 4)) = White, "Put/Get");

      Clip (B, ((-5, -5), (10, 10)), X0, Y0, X1, Y1, Empty);
      AUnit.Assertions.Assert (
         not Empty and X0 = 0 and Y0 = 0 and X1 = 4 and Y1 = 4,
         "Clip top-left overhang");
      Clip (B, ((15, 5), (100, 100)), X0, Y0, X1, Y1, Empty);
      AUnit.Assertions.Assert (
         not Empty and X0 = 15 and Y0 = 5 and X1 = 19 and Y1 = 9,
         "Clip bottom-right overhang");
      Clip (B, ((30, 30), (5, 5)), X0, Y0, X1, Y1, Empty);
      AUnit.Assertions.Assert (Empty, "Clip fully outside");
      Clip (B, ((2, 2), (0, 5)), X0, Y0, X1, Y1, Empty);
      AUnit.Assertions.Assert (Empty, "Clip zero width");

      Clear (B, Black);
      Fill (B, ((2, 2), (3, 3)), White);
      AUnit.Assertions.Assert (
         Get (B, (2, 2)) = White and Get (B, (4, 4)) = White, "Fill inside");
      AUnit.Assertions.Assert (
         Get (B, (5, 5)) = Black and Get (B, (1, 1)) = Black, "Fill outside");

      Fill (B, ((-2, -2), (4, 4)), (9, 9, 9, 0));
      AUnit.Assertions.Assert (
         Get (B, (0, 0)) = (9, 9, 9, 255), "Fill clipped, alpha ignored");

      Clear (B, Black);
      Fill_Blend (B, ((0, 0), (20, 10)), (255, 255, 255, 128));
      AUnit.Assertions.Assert (
         Get (B, (10, 5)).R in 127 .. 129, "Fill_Blend");

      declare
         S : Buffer (1, 1);  --  2 x 2 white
      begin
         Clear (S, White);
         Clear (B, Black);
         Blit (B, S, (19, 9));
         AUnit.Assertions.Assert (
            Get (B, (19, 9)) = White and Get (B, (18, 8)) = Black,
            "Blit clipped corner");
         Blit (B, S, (100, 100));
         AUnit.Assertions.Assert (
            Get (B, (19, 9)) = White, "Blit fully outside is no-op");
      end;
   end Test_Framebuffer;

   procedure Test_Events (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      E : Event := (Kind => Key_Down, Time => 5, Window => 1,
                    Key => Key_A, Mods => No_Modifiers, Repeat => False);
   begin
      AUnit.Assertions.Assert (
         E.Kind = Key_Down and E.Key = Key_A, "event kind");
      E := (
         Kind => Text_Input,
         Time => 0,
         Window => 1,
         Text => "a   ",
         Length => 1);
      AUnit.Assertions.Assert (E.Text (1 .. E.Length) = "a", "text event");
   end Test_Events;

   procedure Test_Backend_Queue (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      OK : Boolean;
      E  : Event;
      W  : Window_Id;
   begin
      Initialize (OK);
      AUnit.Assertions.Assert (OK and Is_Initialized, "Initialize");
      Create_Window ("t", (10, 10), (others => <>), W);
      AUnit.Assertions.Assert (
         W /= No_Window and Is_Open (W), "Create_Window");
      AUnit.Assertions.Assert (Get_Size (W) = (10, 10), "Get_Size");
      Push ((Kind => Mouse_Enter, Time => 1, Window => W));
      Push ((Kind => Mouse_Leave, Time => 2, Window => W));
      Poll (E);
      AUnit.Assertions.Assert (E.Kind = Mouse_Enter, "Push/Poll order 1");
      Poll (E);
      AUnit.Assertions.Assert (E.Kind = Mouse_Leave, "Push/Poll order 2");
      Set_Clipboard ("hello");
      declare
         S : String (1 .. 16);
         L : Natural;
      begin
         Get_Clipboard (S, L);
         AUnit.Assertions.Assert (
            S (1 .. L) = "hello", "clipboard round trip");
      end;
      Destroy_Window (W);
      AUnit.Assertions.Assert (not Is_Open (W), "Destroy_Window");
      Finalize;
      AUnit.Assertions.Assert (not Is_Initialized, "Finalize");
   end Test_Backend_Queue;

   procedure Test_Backend_Lifecycle
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
      W1 : Window_Id;
      W2 : Window_Id;
      E  : Event;
      S  : String (1 .. 16);
      L  : Natural;
   begin
      --  Start the first backend session.
      Initialize (OK);
      AUnit.Assertions.Assert
        (OK and then Is_Initialized, "Initial initialization failed");

      --  Create two windows.
      Create_Window
        ("Lifecycle 1", (320, 240),
         (Hidden => True, others => <>), W1);

      Create_Window
        ("Lifecycle 2", (320, 240),
         (Hidden => True, others => <>), W2);

      AUnit.Assertions.Assert
        (W1 /= No_Window and then Is_Open (W1),
         "First window creation failed");

      AUnit.Assertions.Assert
        (W2 /= No_Window and then Is_Open (W2),
         "Second window creation failed");

      AUnit.Assertions.Assert
        (W1 /= W2, "Window identifiers must be distinct");

      --  Leave application state behind intentionally.
      Set_Clipboard ("previous session");

      Push ((Kind => Quit, Time => 0, Window => No_Window));

      --  Finalize without explicitly destroying the windows.
      Finalize;

      AUnit.Assertions.Assert
        (not Is_Initialized, "Backend remains initialized");

      AUnit.Assertions.Assert
        (not Is_Open (W1), "First window remains open");

      AUnit.Assertions.Assert
        (not Is_Open (W2), "Second window remains open");

      AUnit.Assertions.Assert
        (Now = 0, "Clock must return zero after finalization");

      --  Start a second backend session.
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK and then Is_Initialized, "Reinitialization failed");

      --  No events should remain from the previous session.
      Poll (E);

      AUnit.Assertions.Assert
        (E.Kind = None, "Event queue was not reset");

      --  Verify that input state has been reset.
      for K in Key loop
         AUnit.Assertions.Assert
           (not Is_Key_Down (K), "Stale keyboard state");
      end loop;

      AUnit.Assertions.Assert
        (Mouse_Buttons = [Mouse_Button'Range => False],
         "Stale mouse button state");

      AUnit.Assertions.Assert
        (Current_Modifiers = No_Modifiers,
         "Stale modifier state");

      --  Verify that the local clipboard has been reset.
      Get_Clipboard (S, L);

      AUnit.Assertions.Assert
        (L = 0, "Clipboard was not reset");

      --  Verify that window slots can be reused.
      Create_Window
        ("Lifecycle 3", (320, 240),
         (Hidden => True, others => <>), W1);

      AUnit.Assertions.Assert
        (W1 /= No_Window and then Is_Open (W1),
         "Window creation after reinitialization failed");

      Destroy_Window (W1);

      AUnit.Assertions.Assert
        (not Is_Open (W1), "Window destruction failed");

      Finalize;

      AUnit.Assertions.Assert
        (not Is_Initialized, "Second finalization failed");

   exception
      when others =>
         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_Backend_Lifecycle;

   --  All tests must be registered in this method to run
   overriding procedure Register_Tests (T : in out Base_Test) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
         (T, Test_Types'Access, "Test Types");
      AUnit.Test_Cases.Registration.Register_Routine
         (T, Test_Blend'Access, "Test Blend");
      AUnit.Test_Cases.Registration.Register_Routine
         (T, Test_Framebuffer'Access, "Test Framebuffer");
      AUnit.Test_Cases.Registration.Register_Routine
         (T, Test_Events'Access, "Test Events");
      AUnit.Test_Cases.Registration.Register_Routine
         (T, Test_Backend_Queue'Access, "Test Backend Queue");
      AUnit.Test_Cases.Registration.Register_Routine
         (T, Test_Backend_Lifecycle'Access, "Test Backend Lifecycle");
   end Register_Tests;

   --  Returns the name of the tests
   overriding function Name (T : Base_Test) return AUnit.Message_String is
   begin
      return AUnit.Format ("Sample_Tests");
   end Name;

end Base_Tests;