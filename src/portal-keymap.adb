--  Portal.Keymap: XKB key name -> Key, independent of the layout.
--  Names shorter than 4 characters are padded with spaces.

with Portal.Input; use Portal.Input;

package body Portal.Keymap is

   type Name_Entry is record
      Name : Key_Name;
      K    : Key;
   end record;
   type Name_Table is array (Positive range <>) of Name_Entry;

   Physical_Keys : constant Name_Table :=
     [("AD01", Key_Q), ("AD02", Key_W), ("AD03", Key_E), ("AD04", Key_R),
      ("AD05", Key_T), ("AD06", Key_Y), ("AD07", Key_U), ("AD08", Key_I),
      ("AD09", Key_O), ("AD10", Key_P),
      ("AC01", Key_A), ("AC02", Key_S), ("AC03", Key_D), ("AC04", Key_F),
      ("AC05", Key_G), ("AC06", Key_H), ("AC07", Key_J), ("AC08", Key_K),
      ("AC09", Key_L),
      ("AB01", Key_Z), ("AB02", Key_X), ("AB03", Key_C), ("AB04", Key_V),
      ("AB05", Key_B), ("AB06", Key_N), ("AB07", Key_M),
      ("AE01", Key_1), ("AE02", Key_2), ("AE03", Key_3), ("AE04", Key_4),
      ("AE05", Key_5), ("AE06", Key_6), ("AE07", Key_7), ("AE08", Key_8),
      ("AE09", Key_9), ("AE10", Key_0),
      ("AE11", Key_Minus), ("AE12", Key_Equals),
      ("AD11", Key_Left_Bracket), ("AD12", Key_Right_Bracket),
      ("BKSL", Key_Backslash), ("AC10", Key_Semicolon),
      ("AC11", Key_Apostrophe), ("TLDE", Key_Grave),
      ("AB08", Key_Comma), ("AB09", Key_Period), ("AB10", Key_Slash),
      ("RTRN", Key_Return), ("ESC ", Key_Escape), ("BKSP", Key_Backspace),
      ("TAB ", Key_Tab), ("SPCE", Key_Space),
      ("INS ", Key_Insert), ("DELE", Key_Delete), ("HOME", Key_Home),
      ("END ", Key_End), ("PGUP", Key_Page_Up), ("PGDN", Key_Page_Down),
      ("LEFT", Key_Left), ("RGHT", Key_Right), ("UP  ", Key_Up),
      ("DOWN", Key_Down),
      ("FK01", Key_F1), ("FK02", Key_F2), ("FK03", Key_F3), ("FK04", Key_F4),
      ("FK05", Key_F5), ("FK06", Key_F6), ("FK07", Key_F7), ("FK08", Key_F8),
      ("FK09", Key_F9), ("FK10", Key_F10), ("FK11", Key_F11),
      ("FK12", Key_F12),
      ("LFSH", Key_Left_Shift), ("RTSH", Key_Right_Shift),
      ("LCTL", Key_Left_Ctrl), ("RCTL", Key_Right_Ctrl),
      ("LALT", Key_Left_Alt), ("RALT", Key_Right_Alt),
      ("LWIN", Key_Left_Super), ("RWIN", Key_Right_Super),
      ("CAPS", Key_Caps_Lock),
      ("KP0 ", Key_KP_0), ("KP1 ", Key_KP_1), ("KP2 ", Key_KP_2),
      ("KP3 ", Key_KP_3), ("KP4 ", Key_KP_4), ("KP5 ", Key_KP_5),
      ("KP6 ", Key_KP_6), ("KP7 ", Key_KP_7), ("KP8 ", Key_KP_8),
      ("KP9 ", Key_KP_9),
      ("KPDV", Key_KP_Divide), ("KPMU", Key_KP_Multiply),
      ("KPSU", Key_KP_Minus), ("KPAD", Key_KP_Plus),
      ("KPEN", Key_KP_Enter), ("KPDL", Key_KP_Period),
      ("PRSC", Key_Print_Screen), ("SCLK", Key_Scroll_Lock),
      ("PAUS", Key_Pause), ("MENU", Key_Menu)];

   function Key_From_Name (Name : Key_Name) return Key is
      N : Key_Name := Name;
   begin
      for C of N loop
         if C = ASCII.NUL then
            C := ' ';
         end if;
      end loop;
      for Entry_Of in Physical_Keys'Range loop
         if Physical_Keys (Entry_Of).Name = N then
            return Physical_Keys (Entry_Of).K;
         end if;
      end loop;
      return Key_Unknown;
   end Key_From_Name;

end Portal.Keymap;
