with AUnit.Assertions;

with Bedrock.Screen; use Bedrock.Screen;
with Bedrock.Colors; use Bedrock.Colors;
with Portal;
with Portal.Backend;     use Portal.Backend;
with Portal.Framebuffer; use Portal.Framebuffer;
with Portal.Input;       use Portal.Input;
with Ada.Environment_Variables;
with GNAT.OS_Lib;
with Portal.Keymap;
with Ada.Unchecked_Deallocation;

package body Base_Tests is

   procedure Run_X11_Command (Command : String);

   procedure Test_X11_Event_Handling
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Backend_Lifecycle
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Queue_Capacity
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Physical_Keymap
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_X11_Mouse_Motion
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Cursor_Lifecycle
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Window_Resize
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Presentation
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Timing
     (T : in out AUnit.Test_Cases.Test_Case'Class);

   procedure Test_Unsupported_Format
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

   procedure Test_Queue_Capacity
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
      E  : Event;
   begin
      Initialize (OK);
      AUnit.Assertions.Assert (OK, "Initialization failed");

      --  Fill the event queue.
      for I in 1 .. 256 loop
         Push ((Kind => Quit, Time => Ticks (I),
                Window => No_Window));
      end loop;

      --  Verify that overflow does not overwrite existing events.
      Push ((Kind => Quit, Time => 999,
             Window => No_Window));

      --  Remove the first half of the queue.
      for I in 1 .. 128 loop
         Poll (E);

         AUnit.Assertions.Assert
           (E.Kind = Quit and then E.Time = Ticks (I),
            "Incorrect FIFO ordering");
      end loop;

      --  Refill the queue, forcing the ring buffer to wrap.
      for I in 257 .. 384 loop
         Push ((Kind => Quit, Time => Ticks (I),
                Window => No_Window));
      end loop;

      --  Verify the remaining events.
      for I in 129 .. 384 loop
         Poll (E);

         AUnit.Assertions.Assert
           (E.Kind = Quit and then E.Time = Ticks (I),
            "Incorrect ordering after queue wraparound");
      end loop;

      --  Verify that the queue is empty.
      Poll (E);

      AUnit.Assertions.Assert
        (E.Kind = None, "Queue should be empty");

      Finalize;

   exception
      when others =>
         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_Queue_Capacity;

   procedure Run_X11_Command (Command : String) is
      use GNAT.OS_Lib;

      Args : Argument_List (1 .. 2) :=
        [new String'("-c"), new String'(Command)];

      Status : Integer;
   begin
      Status := Spawn ("/bin/sh", Args);

      Free (Args (1));
      Free (Args (2));

      AUnit.Assertions.Assert
        (Status = 0, "Native command failed: " & Command);
   end Run_X11_Command;

   procedure Test_X11_Event_Handling
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
      W1 : Window_Id;
      W2 : Window_Id;
      E  : Event;

      Pressed     : Boolean := False;
      Released    : Boolean := False;
      Focus_Lost  : Boolean := False;
      State_Clear : Boolean := False;

      Input_Key : constant String :=
        (if Ada.Environment_Variables.Value
           ("PORTAL_TEST_X11_LAYOUT", "us") = "fr"
         then "z"
         else "w");
   begin
      Initialize (OK);
      AUnit.Assertions.Assert (OK, "Initialization failed");

      Create_Window
        ("PAL Queue A", (320, 240),
         (Hidden => False, others => <>), W1);

      Create_Window
        ("PAL Queue B", (320, 240),
         (Hidden => False, others => <>), W2);

      AUnit.Assertions.Assert
        (W1 /= No_Window and then W2 /= No_Window,
         "Window creation failed");

      --  Give the first window keyboard focus.
      Run_X11_Command
        ("xdotool search --sync --onlyvisible " &
         "--name '^PAL Queue A$' windowfocus --sync");

      --  Drain initial native window events.
      loop
         Poll (E);
         exit when E.Kind = None;
      end loop;

      --  Fill the application event queue.
      for I in 1 .. 256 loop
         Push ((Kind => Quit, Time => Ticks (I),
                Window => No_Window));
      end loop;

      --  Generate native keyboard events while the queue is full.
      Run_X11_Command ("xdotool key " & Input_Key);

      Sleep (50);

      --  Verify that existing events retain their order.
      for I in 1 .. 256 loop
         Poll (E);

         AUnit.Assertions.Assert
           (E.Kind = Quit and then E.Time = Ticks (I),
            "Queued event was lost or reordered");
      end loop;

      --  Verify that native keyboard events were preserved.
      for I in 1 .. 50 loop
         Wait (E, 20);

         if E.Kind = Key_Down
           and then E.Window = W1
           and then E.Key = Key_W
         then
            Pressed := True;
         elsif E.Kind = Key_Up
           and then E.Window = W1
           and then E.Key = Key_W
         then
            Released := Pressed;
            exit;
         end if;
      end loop;

      AUnit.Assertions.Assert
        (Pressed and Released,
         "Native keyboard events lost during queue saturation");

      --  Hold the physical W key and verify keyboard state.
      Run_X11_Command ("xdotool keydown " & Input_Key);

      Pressed := False;

      for I in 1 .. 50 loop
         Wait (E, 20);

         if E.Kind = Key_Down
           and then E.Window = W1
           and then E.Key = Key_W
         then
            Pressed := Is_Key_Down (Key_W);
            exit;
         end if;
      end loop;

      --  Transfer focus while W remains held.
      Run_X11_Command
        ("xdotool search --sync --onlyvisible " &
         "--name '^PAL Queue B$' windowfocus --sync");

      for I in 1 .. 50 loop
         Wait (E, 20);

         if E.Kind = Window_Focus_Out
           and then E.Window = W1
         then
            Focus_Lost := True;
            State_Clear := not Is_Key_Down (Key_W);
            exit;
         end if;
      end loop;

      --  Release the native key before evaluating assertions.
      Run_X11_Command ("xdotool keyup " & Input_Key);

      AUnit.Assertions.Assert
        (Pressed, "Keyboard state was not updated");

      AUnit.Assertions.Assert
        (Focus_Lost, "Focus loss event was not received");

      AUnit.Assertions.Assert
        (State_Clear, "Keyboard state retained after focus loss");

      Finalize;

   exception
      when others =>
         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_X11_Event_Handling;

   procedure Test_Physical_Keymap
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Portal.Keymap;
   begin
      --  Physical letter positions.
      AUnit.Assertions.Assert
        (Key_From_Name ("AD02") = Key_W, "Physical W");

      AUnit.Assertions.Assert
        (Key_From_Name ("AC02") = Key_S, "Physical S");

      AUnit.Assertions.Assert
        (Key_From_Name ("AD08") = Key_I, "Physical I");

      AUnit.Assertions.Assert
        (Key_From_Name ("AC08") = Key_K, "Physical K");

      --  Left and right modifiers.
      AUnit.Assertions.Assert
        (Key_From_Name ("LFSH") = Key_Left_Shift,
         "Left Shift");

      AUnit.Assertions.Assert
        (Key_From_Name ("RTSH") = Key_Right_Shift,
         "Right Shift");

      AUnit.Assertions.Assert
        (Key_From_Name ("LCTL") = Key_Left_Ctrl,
         "Left Ctrl");

      AUnit.Assertions.Assert
        (Key_From_Name ("RCTL") = Key_Right_Ctrl,
         "Right Ctrl");

      AUnit.Assertions.Assert
        (Key_From_Name ("LALT") = Key_Left_Alt,
         "Left Alt");

      AUnit.Assertions.Assert
        (Key_From_Name ("RALT") = Key_Right_Alt,
         "Right Alt");

      --  Special and function keys.
      AUnit.Assertions.Assert
        (Key_From_Name ("ESC ") = Key_Escape,
         "Escape");

      AUnit.Assertions.Assert
        (Key_From_Name ("FK02") = Key_F2,
         "F2");

      AUnit.Assertions.Assert
        (Key_From_Name ("RTRN") = Key_Return,
         "Return");

      AUnit.Assertions.Assert
        (Key_From_Name ("KPEN") = Key_KP_Enter,
         "Keypad Enter");

      --  Native names may contain null padding.
      AUnit.Assertions.Assert
        (Key_From_Name ("ESC" & ASCII.NUL) = Key_Escape,
         "Null-padded key name");

      --  Unsupported key.
      AUnit.Assertions.Assert
        (Key_From_Name ("ZZZZ") = Key_Unknown,
         "Unknown physical key");
   end Test_Physical_Keymap;

   procedure Test_X11_Mouse_Motion
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
      W  : Window_Id;
      E  : Event;

      procedure Expect_Move (X, Y, DX, DY : Pixels);

      procedure Expect_Move (X, Y, DX, DY : Pixels) is
      begin
         for I in 1 .. 50 loop
            Wait (E, 20);

            if E.Kind = Mouse_Move
              and then E.Window = W
              and then E.At_Pos = (X, Y)
            then
               AUnit.Assertions.Assert
                 (E.Delta_X = DX, "Incorrect horizontal delta");

               AUnit.Assertions.Assert
                 (E.Delta_Y = DY, "Incorrect vertical delta");

               return;
            end if;
         end loop;

         AUnit.Assertions.Assert
           (False, "Expected mouse movement was not received");
      end Expect_Move;

   begin
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK, "Initialization failed");

      Create_Window
        ("PAL Mouse Test", (320, 240),
         (Hidden => False, others => <>), W);

      AUnit.Assertions.Assert
        (W /= No_Window, "Window creation failed");

      Run_X11_Command
        ("xdotool search --sync --onlyvisible " &
         "--name '^PAL Mouse Test$' windowfocus --sync");

      --  Start with the pointer outside the window.
      Run_X11_Command ("xdotool mousemove 600 600");

      loop
         Poll (E);
         exit when E.Kind = None;
      end loop;

      --  First movement establishes the baseline.
      Run_X11_Command
        ("xdotool mousemove --window " &
         "$(xdotool search --name '^PAL Mouse Test$') 40 50");

      Expect_Move (40, 50, 0, 0);

      --  Positive movement.
      Run_X11_Command
        ("xdotool mousemove --window " &
         "$(xdotool search --name '^PAL Mouse Test$') 100 80");

      Expect_Move (100, 80, 60, 30);

      --  Negative movement.
      Run_X11_Command
        ("xdotool mousemove --window " &
         "$(xdotool search --name '^PAL Mouse Test$') 70 60");

      Expect_Move (70, 60, -30, -20);

      --  Leave the window and drain pending events.
      Run_X11_Command ("xdotool mousemove 600 600");

      loop
         Poll (E);
         exit when E.Kind = None;
      end loop;

      --  Reenter the window: the baseline must reset.
      Run_X11_Command
        ("xdotool mousemove --window " &
         "$(xdotool search --name '^PAL Mouse Test$') 150 120");

      Expect_Move (150, 120, 0, 0);

      Finalize;

   exception
      when others =>
         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_X11_Mouse_Motion;

   procedure Test_Cursor_Lifecycle
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
      W1 : Window_Id;
      W2 : Window_Id;
   begin
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK, "Initialization failed");

      Create_Window
        ("Cursor Test A", (320, 240),
         (Hidden => True, others => <>), W1);

      Create_Window
        ("Cursor Test B", (320, 240),
         (Hidden => True, others => <>), W2);

      AUnit.Assertions.Assert
        (W1 /= No_Window and then W2 /= No_Window,
         "Window creation failed");

      --  Exercise every supported cursor shape.
      for Shape in Cursor_Shape loop
         Set_Cursor (W1, Shape);
      end loop;

      --  Configure separate windows.
      Set_Cursor (W1, Crosshair);
      Set_Cursor (W2, Hand);

      --  Repeated visibility operations.
      Set_Cursor_Visible (False);
      Set_Cursor_Visible (False);
      Set_Cursor_Visible (False);

      --  Change a cursor while hidden.
      Set_Cursor (W1, I_Beam);

      Set_Cursor_Visible (True);
      Set_Cursor_Visible (True);

      --  Finalize while the cursor is hidden.
      Set_Cursor_Visible (False);

      Finalize;

      AUnit.Assertions.Assert
        (not Is_Initialized, "Finalization failed");

      --  Verify that the backend remains reusable.
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK, "Reinitialization failed");

      Create_Window
        ("Cursor Test C", (320, 240),
         (Hidden => True, others => <>), W1);

      AUnit.Assertions.Assert
        (W1 /= No_Window, "Window recreation failed");

      Set_Cursor (W1, Arrow);
      Set_Cursor_Visible (True);

      Destroy_Window (W1);
      Finalize;

   exception
      when others =>
         if Is_Initialized then
            Set_Cursor_Visible (True);
            Finalize;
         end if;

         raise;
   end Test_Cursor_Lifecycle;

   procedure Test_Window_Resize
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
      W  : Window_Id;
      E  : Event;

      procedure Expect_Resize
        (Expected : Bedrock.Screen.Size);

      procedure Expect_Resize
        (Expected : Bedrock.Screen.Size)
      is
      begin
         for I in 1 .. 100 loop
            Wait (E, 20);

            if E.Kind = Window_Resized
              and then E.Window = W
              and then E.Size = Expected
            then
               AUnit.Assertions.Assert
                 (Get_Size (W) = Expected,
                  "Incorrect size after resize");

               return;
            end if;
         end loop;

         AUnit.Assertions.Assert
           (False, "Expected resize event was not received");
      end Expect_Resize;

   begin
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK, "Initialization failed");

      Create_Window
        ("PAL Resize Test", (320, 240),
         (Hidden => True,
          Resizable => True,
          others => <>), W);

      AUnit.Assertions.Assert
        (W /= No_Window, "Window creation failed");

      AUnit.Assertions.Assert
        (Get_Size (W) = (320, 240),
         "Incorrect initial window size");

      --  Increase both dimensions.
      Set_Size (W, (640, 480));
      Expect_Resize ((640, 480));

      --  Decrease both dimensions.
      Set_Size (W, (400, 300));
      Expect_Resize ((400, 300));

      --  Resize to a non-square aspect ratio.
      Set_Size (W, (800, 400));
      Expect_Resize ((800, 400));

      --  Exercise the DPI scale query.
      AUnit.Assertions.Assert
        (Scale (W) in 50 .. 1000, "Unexpected DPI scale");

      Destroy_Window (W);

      AUnit.Assertions.Assert
        (not Is_Open (W), "Window destruction failed");

      Finalize;

   exception
      when others =>
         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_Window_Resize;

   procedure Test_Presentation
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      type Buffer_Access is access Buffer;

      procedure Free_Buffer is
        new Ada.Unchecked_Deallocation
          (Buffer, Buffer_Access);

      Frame : Buffer_Access := null;

      OK : Boolean;
      W  : Window_Id;

      procedure Present_Frames (W_Pixels, H_Pixels : Extent);

      procedure Present_Frames (W_Pixels, H_Pixels : Extent) is
      begin
         Free_Buffer (Frame);

         Frame := new Buffer
           (H_Pixels - 1, W_Pixels - 1);

         Clear (Frame.all, (255, 0, 0, 255));
         Present (W, Frame.all);

         Clear (Frame.all, (0, 255, 0, 255));
         Present (W, Frame.all);

         Clear (Frame.all, (0, 0, 255, 255));
         Present (W, Frame.all);
      end Present_Frames;

   begin
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK, "Initialization failed");

      Create_Window
        ("PAL Presentation Test", (1280, 720),
         (Hidden => True, others => <>), W);

      AUnit.Assertions.Assert
        (W /= No_Window, "Window creation failed");

      --  Initial allocation.
      Present_Frames (320, 240);

      --  Grow the conversion buffer.
      Present_Frames (640, 480);

      --  Exercise a larger framebuffer.
      Present_Frames (1280, 720);

      --  Present smaller frames after growing the buffer.
      Present_Frames (320, 240);

      Free_Buffer (Frame);

      Destroy_Window (W);
      Finalize;

      --  Verify presentation after backend reinitialization.
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK, "Reinitialization failed");

      Create_Window
        ("PAL Presentation Restart", (320, 240),
         (Hidden => True, others => <>), W);

      AUnit.Assertions.Assert
        (W /= No_Window, "Window recreation failed");

      Present_Frames (320, 240);

      Free_Buffer (Frame);

      Finalize;

   exception
      when others =>
         Free_Buffer (Frame);

         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_Presentation;

   procedure Test_Timing
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
      T1, T2, T3 : Ticks;
   begin
      Initialize (OK);

      AUnit.Assertions.Assert
        (OK, "Initialization failed");

      T1 := Now;

      Sleep (50);

      T2 := Now;

      AUnit.Assertions.Assert
        (T2 >= T1, "Clock moved backwards");

      AUnit.Assertions.Assert
        (T2 - T1 >= 30, "Insufficient elapsed time");

      Sleep (50);

      T3 := Now;

      AUnit.Assertions.Assert
        (T3 >= T2, "Clock moved backwards");

      AUnit.Assertions.Assert
        (T3 - T2 >= 30, "Insufficient elapsed time");

      Finalize;

      AUnit.Assertions.Assert
        (Now = 0, "Clock not reset after finalization");

   exception
      when others =>
         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_Timing;

   procedure Test_Unsupported_Format
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);

      OK : Boolean;
   begin
      Initialize (OK);

      AUnit.Assertions.Assert
        (not OK, "Unsupported pixel format was accepted");

      AUnit.Assertions.Assert
        (not Is_Initialized,
         "Backend initialized with unsupported pixel format");

   exception
      when others =>
         if Is_Initialized then
            Finalize;
         end if;

         raise;
   end Test_Unsupported_Format;

   --  All tests must be registered in this method to run
   overriding procedure Register_Tests (T : in out Base_Test) is
      Selection : constant String :=
        Ada.Environment_Variables.Value
          ("PORTAL_TEST_SUITE", "all");

      Native_X11 : constant Boolean :=
        Ada.Environment_Variables.Value
          ("PORTAL_TEST_X11_INPUT", "") = "1";
   begin
      --  Reject invalid test suite selections.
      if Selection /= "all"
        and then Selection /= "unit"
        and then Selection /= "integration"
        and then Selection /= "unsupported-format"
      then
         raise Program_Error with
           "Unknown test suite: " & Selection;
      end if;

      --  Negative initialization testing.
      if Selection = "unsupported-format" then
         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Unsupported_Format'Access,
            "IT-FB-02: Unsupported Pixel Format");

         return;
      end if;

      --  Backend-independent unit tests.
      if Selection = "all" or else Selection = "unit" then

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Types'Access,
            "UT: Types");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Blend'Access,
            "UT: Blend");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Framebuffer'Access,
            "UT: Framebuffer");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Events'Access,
            "UT: Events");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Physical_Keymap'Access,
            "UT: Physical Keymap");

      end if;

      --  Portable backend integration tests.
      if Selection = "all"
        or else Selection = "integration"
      then

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Backend_Queue'Access,
            "IT: Backend Queue");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Backend_Lifecycle'Access,
            "IT: Backend Lifecycle");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Queue_Capacity'Access,
            "IT: Queue Capacity");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Cursor_Lifecycle'Access,
            "IT: Cursor Lifecycle");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Window_Resize'Access,
            "IT: Window Resize");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Presentation'Access,
            "IT: Presentation");

         AUnit.Test_Cases.Registration.Register_Routine
           (T, Test_Timing'Access,
            "IT: Timing");

         --  Native X11 integration tests.
         if Native_X11 then

            AUnit.Test_Cases.Registration.Register_Routine
              (T, Test_X11_Event_Handling'Access,
               "IT-X11: Native Event Handling");

            AUnit.Test_Cases.Registration.Register_Routine
              (T, Test_X11_Mouse_Motion'Access,
               "IT-X11: Mouse Motion");

         end if;

      end if;
   end Register_Tests;

   --  Returns the name of the tests
   overriding function Name (T : Base_Test) return AUnit.Message_String is
   begin
      return AUnit.Format ("Ada PAL");
   end Name;

end Base_Tests;