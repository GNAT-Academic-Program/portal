--  Events: what the platform tells the application, one record at a
--  time. A closed variant record, like SDL_Event, so that a handler
--  is a single case statement and SPARK can see every branch.
--
--  Text is delivered as UTF-8 bytes in Text_Input, up to one code
--  point per event. Ports that get whole strings from an IME split
--  them.

with Portal.Input; use Portal.Input;

package Portal.Events with SPARK_Mode, Pure is

   type Event_Kind is
     (None,               --  queue was empty
      Quit,               --  the platform wants the app to stop
      Window_Shown,
      Window_Hidden,
      Window_Resized,     --  Size is the new client size
      Window_Moved,       --  Position is the new origin
      Window_Focus_In,
      Window_Focus_Out,
      Window_Close,       --  user asked to close this window
      Window_Expose,      --  contents lost, present again
      Key_Down,
      Key_Up,
      Text_Input,
      Mouse_Move,
      Mouse_Down,
      Mouse_Up,
      Mouse_Wheel,
      Mouse_Enter,
      Mouse_Leave,
      Gamepad_Connected,
      Gamepad_Disconnected,
      Gamepad_Button_Down,
      Gamepad_Button_Up,
      Gamepad_Axis_Motion,
      Clipboard_Changed);

   subtype Text_Bytes is String (1 .. 4);
   --  One UTF-8 code point, space padded.

   type Event (Kind : Event_Kind := None) is record
      Time   : Ticks     := 0;
      Window : Window_Id := No_Window;
      case Kind is
         when Window_Resized =>
            Size : Portal.Size;
         when Window_Moved =>
            Position : Point;
         when Key_Down | Key_Up =>
            Key      : Input.Key   := Key_Unknown;
            Mods     : Modifiers   := No_Modifiers;
            Repeat   : Boolean     := False;
         when Text_Input =>
            Text     : Text_Bytes  := "    ";
            Length   : Natural     := 0;
         when Mouse_Move =>
            At_Pos   : Point;
            Delta_X  : Pixels      := 0;
            Delta_Y  : Pixels      := 0;
            Held     : Button_State := [others => False];
         when Mouse_Down | Mouse_Up =>
            Button   : Mouse_Button := Left;
            Where    : Point;
            Clicks   : Positive     := 1;
         when Mouse_Wheel =>
            Wheel_X  : Pixels := 0;
            Wheel_Y  : Pixels := 0;
            Wheel_At : Point;
         when Gamepad_Connected | Gamepad_Disconnected =>
            Gamepad  : Gamepad_Id := No_Gamepad;
         when Gamepad_Button_Down | Gamepad_Button_Up =>
            Pad         : Gamepad_Id     := No_Gamepad;
            Pad_Button  : Gamepad_Button := South;
         when Gamepad_Axis_Motion =>
            Axis_Pad    : Gamepad_Id := No_Gamepad;
            Axis        : Gamepad_Axis := Left_X;
            Value       : Axis_Value := 0;
         when others =>
            null;
      end case;
   end record;

   No_Event : constant Event := (Kind => None, others => <>);

end Portal.Events;
