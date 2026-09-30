--  Win32 port of Portal.Backend. One window class, a WndProc that
--  translates messages into Portal events, StretchDIBits for Present.
--
--  NOT COMPILE-CHECKED where this seed was built (no MinGW). Build it
--  on Windows with `alr build` after `set PORTAL_PORT=win32`; expect a
--  handful of binding fixes, then open a PR. Milestones for the team:
--  Raw Input for mouse deltas, XInput for gamepads, real clipboard
--  (OpenClipboard/GetClipboardData), WM_UNICHAR / surrogate pairs for
--  text, per-monitor DPI awareness manifest.

with Interfaces;          use Interfaces;
with Interfaces.C;        use Interfaces.C;
with System;              use type System.Address;
with Portal.Win32;        use Portal.Win32;

package body Portal.Backend with SPARK_Mode => Off is

   Initialized : Boolean := False;
   Instance    : HINSTANCE;
   Class_Name  : constant String := "PortalWindow" & ASCII.NUL;
   Start       : Unsigned_64 := 0;

   type Window_Slot is record
      Open   : Boolean := False;
      Handle : HWND := System.Null_Address;
      Size   : Bedrock.Screen.Size;
   end record;
   Slots : array (Valid_Window_Id) of Window_Slot;

   Max_Queue : constant := 256;
   Queue     : array (1 .. Max_Queue) of Event;
   Q_Head, Q_Count : Natural := 0;

   Keys_Down : array (Key) of Boolean := [others => False];
   Buttons   : Button_State := [others => False];
   Text_Enabled : array (Valid_Window_Id) of Boolean := [others => False];
   Cursor_Cur : HCURSOR := System.Null_Address;

   Clipboard      : String (1 .. Max_Clipboard);
   Clipboard_Last : Natural := 0;

   function To_Address (N : Integer) return System.Address is
     (System'To_Address (N));
   --  MAKEINTRESOURCE: a small integer smuggled through a pointer.

   function Is_Initialized return Boolean is (Initialized);
   function Is_Open (W : Window_Id) return Boolean is
     (W /= No_Window and then Slots (W).Open);

   procedure Enqueue (E : Event);
   function Dequeue return Event;
   function Id_Of (H : HWND) return Window_Id;
   function To_Key (VK : WPARAM) return Key;
   function Current_Mods return Modifiers;
   function Wnd_Proc (H : HWND; Msg : UINT; W : WPARAM; L : LPARAM) return LRESULT
     with Convention => Stdcall;
   procedure Pump;

   procedure Enqueue (E : Event) is
   begin
      if Q_Count < Max_Queue then
         Queue ((Q_Head + Q_Count) mod Max_Queue + 1) := E;
         Q_Count := Q_Count + 1;
      end if;
   end Enqueue;

   function Dequeue return Event is
      E : constant Event := Queue (Q_Head + 1);
   begin
      Q_Head := (Q_Head + 1) mod Max_Queue;
      Q_Count := Q_Count - 1;
      return E;
   end Dequeue;

   function Id_Of (H : HWND) return Window_Id is
   begin
      for W in Valid_Window_Id loop
         if Slots (W).Open and then Slots (W).Handle = H then
            return W;
         end if;
      end loop;
      return No_Window;
   end Id_Of;

   ---------------------------------------------------------------------
   --  Virtual key -> Key (winuser.h VK_* values)
   ---------------------------------------------------------------------

   function To_Key (VK : WPARAM) return Key is
   begin
      case VK is
         when 16#41# .. 16#5A# => return Key'Val (Key'Pos (Key_A) + Natural (VK - 16#41#));
         when 16#30# .. 16#39# => return Key'Val (Key'Pos (Key_0) + Natural (VK - 16#30#));
         when 16#0D# => return Key_Return;
         when 16#1B# => return Key_Escape;
         when 16#08# => return Key_Backspace;
         when 16#09# => return Key_Tab;
         when 16#20# => return Key_Space;
         when 16#2D# => return Key_Insert;
         when 16#2E# => return Key_Delete;
         when 16#24# => return Key_Home;
         when 16#23# => return Key_End;
         when 16#21# => return Key_Page_Up;
         when 16#22# => return Key_Page_Down;
         when 16#25# => return Key_Left;
         when 16#27# => return Key_Right;
         when 16#26# => return Key_Up;
         when 16#28# => return Key_Down;
         when 16#70# .. 16#7B# => return Key'Val (Key'Pos (Key_F1) + Natural (VK - 16#70#));
         when 16#A0# => return Key_Left_Shift;
         when 16#A1# => return Key_Right_Shift;
         when 16#A2# => return Key_Left_Ctrl;
         when 16#A3# => return Key_Right_Ctrl;
         when 16#A4# => return Key_Left_Alt;
         when 16#A5# => return Key_Right_Alt;
         when 16#5B# => return Key_Left_Super;
         when 16#5C# => return Key_Right_Super;
         when 16#14# => return Key_Caps_Lock;
         when 16#60# .. 16#69# => return Key'Val (Key'Pos (Key_KP_0) + Natural (VK - 16#60#));
         when others => return Key_Unknown;
      end case;
   end To_Key;

   function Current_Mods return Modifiers is
     ((Shift => Keys_Down (Key_Left_Shift) or Keys_Down (Key_Right_Shift),
       Ctrl  => Keys_Down (Key_Left_Ctrl)  or Keys_Down (Key_Right_Ctrl),
       Alt   => Keys_Down (Key_Left_Alt)   or Keys_Down (Key_Right_Alt),
       Super => Keys_Down (Key_Left_Super) or Keys_Down (Key_Right_Super),
       Caps_Lock => Keys_Down (Key_Caps_Lock)));

   ---------------------------------------------------------------------
   --  WndProc
   ---------------------------------------------------------------------

   function To_I16 (U : Unsigned_16) return Integer_16 is
     (if U >= 16#8000# then Integer_16 (Integer (U) - 65536) else Integer_16 (U));
   function Lo (L : LPARAM) return Pixels is
     (Pixels (To_I16 (Unsigned_16 (L and 16#FFFF#))));
   function Hi (L : LPARAM) return Pixels is
     (Pixels (To_I16 (Unsigned_16 ((L / 16#10000#) and 16#FFFF#))));

   function Wnd_Proc (H : HWND; Msg : UINT; W : WPARAM; L : LPARAM) return LRESULT is
      Id : constant Window_Id := Id_Of (H);
      T  : constant Ticks := Now;
   begin
      if Id = No_Window then
         return DefWindowProcA (H, Msg, W, L);
      end if;

      case Msg is
         when WM_CLOSE =>
            Enqueue ((Kind => Window_Close, Time => T, Window => Id));
            return 0;
         when WM_SIZE =>
            declare
               S : constant Bedrock.Screen.Size := (Extent (Lo (L)), Extent (Hi (L)));
            begin
               if S /= Slots (Id).Size then
                  Slots (Id).Size := S;
                  Enqueue ((Kind => Window_Resized, Time => T, Window => Id, Size => S));
               end if;
            end;
            return 0;
         when WM_PAINT =>
            Enqueue ((Kind => Window_Expose, Time => T, Window => Id));
            return DefWindowProcA (H, Msg, W, L);
         when WM_SETFOCUS =>
            Enqueue ((Kind => Window_Focus_In, Time => T, Window => Id)); return 0;
         when WM_KILLFOCUS =>
            Enqueue ((Kind => Window_Focus_Out, Time => T, Window => Id)); return 0;

         when WM_KEYDOWN | WM_SYSKEYDOWN | WM_KEYUP | WM_SYSKEYUP =>
            declare
               K    : constant Key := To_Key (W);
               Down : constant Boolean := Msg in WM_KEYDOWN | WM_SYSKEYDOWN;
               Repeat : constant Boolean := Down and then Keys_Down (K);
            begin
               Keys_Down (K) := Down;
               if Down then
                  Enqueue ((Kind => Key_Down, Time => T, Window => Id,
                            Key => K, Mods => Current_Mods, Repeat => Repeat));
               else
                  Enqueue ((Kind => Key_Up, Time => T, Window => Id,
                            Key => K, Mods => Current_Mods, Repeat => False));
               end if;
            end;
            return 0;

         when WM_CHAR =>
            if Text_Enabled (Id) and then W in 16#20# .. 16#7E# then
               Enqueue ((Kind => Text_Input, Time => T, Window => Id,
                         Text => [Character'Val (W), ' ', ' ', ' '], Length => 1));
            end if;
            return 0;

         when WM_MOUSEMOVE =>
            Enqueue ((Kind => Mouse_Move, Time => T, Window => Id,
                      At_Pos => (Lo (L), Hi (L)), Delta_X => 0, Delta_Y => 0,
                      Held => Buttons));
            return 0;

         when WM_LBUTTONDOWN | WM_RBUTTONDOWN | WM_MBUTTONDOWN | WM_XBUTTONDOWN
            | WM_LBUTTONUP | WM_RBUTTONUP | WM_MBUTTONUP | WM_XBUTTONUP =>
            declare
               Down : constant Boolean :=
                 Msg in WM_LBUTTONDOWN | WM_RBUTTONDOWN | WM_MBUTTONDOWN | WM_XBUTTONDOWN;
               B : constant Mouse_Button :=
                 (case Msg is
                    when WM_LBUTTONDOWN | WM_LBUTTONUP => Left,
                    when WM_RBUTTONDOWN | WM_RBUTTONUP => Right,
                    when WM_MBUTTONDOWN | WM_MBUTTONUP => Middle,
                    when others => (if (W / 16#10000#) = 1 then Back else Forward));
               P : constant Point := (Lo (L), Hi (L));
            begin
               Buttons (B) := Down;
               if Down then
                  Enqueue ((Kind => Mouse_Down, Time => T, Window => Id,
                            Button => B, Where => P, Clicks => 1));
               else
                  Enqueue ((Kind => Mouse_Up, Time => T, Window => Id,
                            Button => B, Where => P, Clicks => 1));
               end if;
            end;
            return 0;

         when WM_MOUSEWHEEL =>
            declare
               Delta_Raw : constant Integer_16 := To_I16 (Unsigned_16 ((W / 16#10000#) and 16#FFFF#));
            begin
               Enqueue ((Kind => Mouse_Wheel, Time => T, Window => Id,
                         Wheel_X => 0, Wheel_Y => Pixels (Integer (Delta_Raw) / 120),
                         Wheel_At => (Lo (L), Hi (L))));
            end;
            return 0;

         when WM_DESTROY =>
            return 0;

         when others =>
            return DefWindowProcA (H, Msg, W, L);
      end case;
   end Wnd_Proc;

   procedure Pump is
      M : aliased MSG;
   begin
      while PeekMessageA (M'Access, System.Null_Address, 0, 0, PM_REMOVE) /= 0 loop
         if TranslateMessage (M'Access) = 0 then null; end if;
         if DispatchMessageA (M'Access) = 0 then null; end if;
      end loop;
   end Pump;

   ---------------------------------------------------------------------
   --  Lifetime
   ---------------------------------------------------------------------

   procedure Initialize (Success : out Boolean) is
      WC : aliased WNDCLASSEXA;
   begin
      Instance := GetModuleHandleA (System.Null_Address);
      Start := GetTickCount64;
      WC := (Size => WNDCLASSEXA'Size / 8,
             Style => CS_OWNDC + CS_HREDRAW + CS_VREDRAW,
             Proc => Wnd_Proc'Access,
             Instance => Instance,
             Cursor => LoadCursorA (System.Null_Address, To_Address (IDC_ARROW)),
             Class_Name => Class_Name'Address,
             others => <>);
      Success := RegisterClassExA (WC'Access) /= 0;
      Initialized := Success;
   end Initialize;

   procedure Finalize is
   begin
      for W in Valid_Window_Id loop
         if Slots (W).Open then
            if DestroyWindow (Slots (W).Handle) = 0 then null; end if;
            Slots (W).Open := False;
         end if;
      end loop;
      Initialized := False;
   end Finalize;

   ---------------------------------------------------------------------
   --  Windows
   ---------------------------------------------------------------------

   procedure Create_Window
     (Title  : String;
      Size   : Bedrock.Screen.Size;
      Flags  : Window_Flags;
      Window : out Window_Id)
   is
      Style : DWORD := (if Flags.Borderless then WS_POPUP else WS_OVERLAPPEDWINDOW);
      R     : aliased Win_Rect := (0, 0, long (Size.Width), long (Size.Height));
      T     : constant String := Title & ASCII.NUL;
      H     : HWND;
   begin
      Window := No_Window;
      if not Flags.Resizable then
         Style := Style and not DWORD (WS_THICKFRAME + WS_MAXIMIZEBOX);
      end if;
      if not Flags.Hidden then
         Style := Style or WS_VISIBLE;
      end if;
      if AdjustWindowRect (R'Access, Style, 0) = 0 then null; end if;
      for W in Valid_Window_Id loop
         if not Slots (W).Open then
            H := CreateWindowExA
              (0, Class_Name'Address, T'Address, Style,
               CW_USEDEFAULT, CW_USEDEFAULT,
               int (R.Right - R.Left), int (R.Bottom - R.Top),
               System.Null_Address, System.Null_Address, Instance, System.Null_Address);
            if H = System.Null_Address then
               return;
            end if;
            Slots (W) := (Open => True, Handle => H, Size => Size);
            Window := W;
            return;
         end if;
      end loop;
   end Create_Window;

   procedure Destroy_Window (Window : Window_Id) is
   begin
      if DestroyWindow (Slots (Window).Handle) = 0 then null; end if;
      Slots (Window).Open := False;
   end Destroy_Window;

   procedure Set_Title (Window : Window_Id; Title : String) is
      T : constant String := Title & ASCII.NUL;
   begin
      if SetWindowTextA (Slots (Window).Handle, T'Address) = 0 then null; end if;
   end Set_Title;

   procedure Set_Size (Window : Window_Id; Size : Bedrock.Screen.Size) is
      R : aliased Win_Rect := (0, 0, long (Size.Width), long (Size.Height));
   begin
      if AdjustWindowRect (R'Access, WS_OVERLAPPEDWINDOW, 0) = 0 then null; end if;
      if SetWindowPos (Slots (Window).Handle, System.Null_Address, 0, 0,
                       int (R.Right - R.Left), int (R.Bottom - R.Top),
                       16#0002# + 16#0004#) = 0  --  SWP_NOMOVE | SWP_NOZORDER
      then
         null;
      end if;
   end Set_Size;

   function Get_Size (Window : Window_Id) return Bedrock.Screen.Size is (Slots (Window).Size);

   procedure Show (Window : Window_Id) is
   begin
      if ShowWindow (Slots (Window).Handle, SW_SHOW) = 0 then null; end if;
   end Show;

   procedure Hide (Window : Window_Id) is
   begin
      if ShowWindow (Slots (Window).Handle, SW_HIDE) = 0 then null; end if;
   end Hide;

   function Scale (Window : Window_Id) return Positive is
     (Positive (GetDpiForWindow (Slots (Window).Handle)) * 100 / 96);

   ---------------------------------------------------------------------
   --  Present: RGBA -> BGRX top-down DIB, StretchDIBits 1:1
   ---------------------------------------------------------------------

   type Byte is mod 2 ** 8;
   type Byte_Array is array (Natural range <>) of Byte with Pack;

   procedure Present (Window : Window_Id; Frame : Buffer) is
      W    : constant Natural := Natural (Width (Frame));
      H    : constant Natural := Natural (Height (Frame));
      Data : Byte_Array (0 .. W * H * 4 - 1);
      I    : Natural := 0;
      Info : aliased constant BITMAPINFO :=
        (Header => (Size => BITMAPINFOHEADER'Size / 8, Width => long (W),
                    Height => -long (H), others => <>),
         Colors => 0);
      DC : constant HDC := GetDC (Slots (Window).Handle);
   begin
      for Y in 0 .. Frame.Height loop
         for X in 0 .. Frame.Width loop
            declare
               C : constant Color := Frame.Data (Y, X);
            begin
               Data (I) := Byte (C.B); Data (I + 1) := Byte (C.G);
               Data (I + 2) := Byte (C.R); Data (I + 3) := 0;
               I := I + 4;
            end;
         end loop;
      end loop;
      if StretchDIBits (DC, 0, 0, int (W), int (H), 0, 0, int (W), int (H),
                        Data'Address, Info'Access, DIB_RGB_COLORS, SRCCOPY) = 0
      then
         null;
      end if;
      if ReleaseDC (Slots (Window).Handle, DC) = 0 then null; end if;
   end Present;

   ---------------------------------------------------------------------
   --  Events
   ---------------------------------------------------------------------

   procedure Poll (E : out Event) is
   begin
      Pump;
      if Q_Count > 0 then E := Dequeue; else E := No_Event; end if;
   end Poll;

   procedure Wait (E : out Event; Timeout_Ms : Natural) is
      Deadline : constant Ticks := Now + Ticks (Timeout_Ms);
   begin
      loop
         Poll (E);
         exit when E.Kind /= None or else Now >= Deadline;
         Sleep (1);
      end loop;
   end Wait;

   procedure Push (E : Event) is
   begin
      Enqueue (E);
   end Push;

   ---------------------------------------------------------------------
   --  Polled state
   ---------------------------------------------------------------------

   function Is_Key_Down (K : Key) return Boolean is (Keys_Down (K));
   function Current_Modifiers return Modifiers is (Current_Mods);

   function Mouse_Position (Window : Window_Id) return Point is
      P : aliased Win_Point;
   begin
      if GetCursorPos (P'Access) /= 0
        and then ScreenToClient (Slots (Window).Handle, P'Access) /= 0
      then
         return (Pixels (P.X), Pixels (P.Y));
      end if;
      return (0, 0);
   end Mouse_Position;

   function Mouse_Buttons return Button_State is (Buttons);

   function Gamepad (Id : Valid_Gamepad_Id) return Gamepad_State is
     ((Connected => False, others => <>));
   --  Milestone: XInputGetState.

   procedure Set_Text_Input (Window : Window_Id; Enabled : Boolean) is
   begin
      Text_Enabled (Window) := Enabled;
   end Set_Text_Input;

   procedure Set_Cursor (Window : Window_Id; Shape : Cursor_Shape) is
      pragma Unreferenced (Window);
      --  Win32 cursors are per-thread, not per-window; a WM_SETCURSOR
      --  handler that re-applies Cursor_Cur is a milestone.
      Id : constant Integer :=
        (case Shape is
           when Arrow => IDC_ARROW, when I_Beam => IDC_IBEAM, when Crosshair => IDC_CROSS,
           when Hand => IDC_HAND, when Resize_EW => IDC_SIZEWE, when Resize_NS => IDC_SIZENS,
           when Resize_NWSE => IDC_SIZENWSE, when Resize_NESW => IDC_SIZENESW,
           when Not_Allowed => IDC_NO, when Busy => IDC_WAIT);
   begin
      Cursor_Cur := LoadCursorA (System.Null_Address, To_Address (Id));
      if SetCursor (Cursor_Cur) = System.Null_Address then null; end if;
   end Set_Cursor;

   procedure Set_Cursor_Visible (Visible : Boolean) is
   begin
      if ShowCursor ((if Visible then 1 else 0)) = 0 then null; end if;
   end Set_Cursor_Visible;

   procedure Get_Clipboard (Text : out String; Last : out Natural) is
      N : constant Natural := Natural'Min (Text'Length, Clipboard_Last);
   begin
      Text (Text'First .. Text'First + N - 1) := Clipboard (1 .. N);
      Last := Text'First + N - 1;
   end Get_Clipboard;

   procedure Set_Clipboard (Text : String) is
   begin
      Clipboard (1 .. Text'Length) := Text;
      Clipboard_Last := Text'Length;
   end Set_Clipboard;

   function Now return Ticks is
     (if Initialized then Ticks (GetTickCount64 - Start) else 0);

   procedure Sleep (Ms : Natural) is
   begin
      Win_Sleep (DWORD (Ms));
   end Sleep;

end Portal.Backend;
