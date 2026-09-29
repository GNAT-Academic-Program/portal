--  Input vocabulary: keys, buttons, modifiers. Shared by the event
--  record and by the polled-state queries.
--
--  Keys are named by physical position on a US layout (scancodes),
--  like SDL_Scancode and GLFW_KEY_*. Text input is a separate event
--  that carries the translated character; do not build a text editor
--  on key events.

package Portal.Input with SPARK_Mode, Pure is

   type Key is
     (Key_Unknown,
      --  letters, digits
      Key_A, Key_B, Key_C, Key_D, Key_E, Key_F, Key_G, Key_H, Key_I, Key_J,
      Key_K, Key_L, Key_M, Key_N, Key_O, Key_P, Key_Q, Key_R, Key_S, Key_T,
      Key_U, Key_V, Key_W, Key_X, Key_Y, Key_Z,
      Key_0, Key_1, Key_2, Key_3, Key_4, Key_5, Key_6, Key_7, Key_8, Key_9,
      --  editing and navigation
      Key_Return, Key_Escape, Key_Backspace, Key_Tab, Key_Space,
      Key_Insert, Key_Delete, Key_Home, Key_End, Key_Page_Up, Key_Page_Down,
      Key_Left, Key_Right, Key_Up, Key_Down,
      --  punctuation, US layout positions
      Key_Minus, Key_Equals, Key_Left_Bracket, Key_Right_Bracket, Key_Backslash,
      Key_Semicolon, Key_Apostrophe, Key_Grave, Key_Comma, Key_Period, Key_Slash,
      --  function keys
      Key_F1, Key_F2, Key_F3, Key_F4, Key_F5, Key_F6,
      Key_F7, Key_F8, Key_F9, Key_F10, Key_F11, Key_F12,
      --  modifiers
      Key_Left_Shift, Key_Right_Shift, Key_Left_Ctrl, Key_Right_Ctrl,
      Key_Left_Alt, Key_Right_Alt, Key_Left_Super, Key_Right_Super,
      Key_Caps_Lock,
      --  keypad
      Key_KP_0, Key_KP_1, Key_KP_2, Key_KP_3, Key_KP_4,
      Key_KP_5, Key_KP_6, Key_KP_7, Key_KP_8, Key_KP_9,
      Key_KP_Divide, Key_KP_Multiply, Key_KP_Minus, Key_KP_Plus,
      Key_KP_Enter, Key_KP_Period,
      --  print, lock, misc
      Key_Print_Screen, Key_Scroll_Lock, Key_Pause, Key_Menu);

   type Modifiers is record
      Shift, Ctrl, Alt, Super, Caps_Lock : Boolean := False;
   end record
     with Pack, Size => 8;

   No_Modifiers : constant Modifiers := (others => False);

   type Mouse_Button is (Left, Middle, Right, Back, Forward);

   type Button_State is array (Mouse_Button) of Boolean
     with Pack;

   type Gamepad_Button is
     (South, East, West, North,            --  A B X Y on an Xbox layout
      Left_Shoulder, Right_Shoulder,
      Back, Start, Guide,
      Left_Stick, Right_Stick,
      DPad_Up, DPad_Down, DPad_Left, DPad_Right);

   type Gamepad_Axis is
     (Left_X, Left_Y, Right_X, Right_Y, Left_Trigger, Right_Trigger);

   type Axis_Value is range -32_768 .. 32_767;
   --  Raw stick position. Triggers use 0 .. 32_767.

   Max_Gamepads : constant := 4;
   type Gamepad_Id is range 0 .. Max_Gamepads;
   No_Gamepad : constant Gamepad_Id := 0;
   subtype Valid_Gamepad_Id is Gamepad_Id range 1 .. Max_Gamepads;

   type Gamepad_Buttons is array (Gamepad_Button) of Boolean
     with Pack;
   type Gamepad_Axes is array (Gamepad_Axis) of Axis_Value;

   type Gamepad_State is record
      Connected : Boolean := False;
      Buttons   : Gamepad_Buttons := [others => False];
      Axes      : Gamepad_Axes := [others => 0];
   end record;

end Portal.Input;
