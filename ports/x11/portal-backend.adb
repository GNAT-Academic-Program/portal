--  X11 port of Portal.Backend. Xlib, one connection, XPutImage for
--  Present. Enough to open a window, draw, and get keyboard and
--  mouse. Milestones for the team: XShm (shared memory present),
--  XInput2 (raw mouse deltas), XKB (proper key translation), Xcursor,
--  clipboard through selections, DPI from Xft.dpi, gamepads via
--  evdev (X11 has none).

with Ada.Calendar;
with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with System;               use type System.Address;
with Portal.Xlib;          use Portal.Xlib;

package body Portal.Backend with SPARK_Mode => Off is

   Initialized : Boolean := False;
   Display     : Display_Ptr := Null_Display;
   Screen      : int;
   Visual      : Visual_Ptr;
   Depth       : int;
   Graphics    : GC;
   WM_Delete   : Atom;
   Start       : Ada.Calendar.Time;

   type Window_Slot is record
      Open   : Boolean := False;
      Handle : Xlib.Window := 0;
      Size   : Portal.Size;
   end record;
   Slots : array (Valid_Window_Id) of Window_Slot;

   Max_Queue : constant := 256;
   Queue     : array (1 .. Max_Queue) of Event;
   Q_Head, Q_Count : Natural := 0;

   Keys_Down : array (Key) of Boolean := [others => False];
   Mods      : Modifiers := No_Modifiers;
   Buttons   : Button_State := [others => False];
   Text_Enabled : array (Valid_Window_Id) of Boolean := [others => False];

   Clipboard      : String (1 .. Max_Clipboard);
   Clipboard_Last : Natural := 0;

   function Id_Of (H : Xlib.Window) return Window_Id;
   procedure Enqueue (E : Event);
   function Dequeue return Event;
   function To_Key (Sym : XID) return Key;
   function State_To_Mods (State : unsigned) return Modifiers;
   procedure Translate (Raw : aliased XEvent_Raw);
   procedure Pump;

   function Is_Initialized return Boolean is (Initialized);
   function Is_Open (W : Window_Id) return Boolean is
     (W /= No_Window and then Slots (W).Open);

   function Id_Of (H : Xlib.Window) return Window_Id is
   begin
      for W in Valid_Window_Id loop
         if Slots (W).Open and then Slots (W).Handle = H then
            return W;
         end if;
      end loop;
      return No_Window;
   end Id_Of;

   ---------------------------------------------------------------------
   --  Queue
   ---------------------------------------------------------------------

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

   ---------------------------------------------------------------------
   --  Key translation: keysym -> Portal.Input.Key. US layout, minimal.
   --  Milestone: XKB scancodes so this is layout independent.
   ---------------------------------------------------------------------

   function To_Key (Sym : XID) return Key is
   begin
      case Sym is
         when 16#61# .. 16#7A# =>  --  a .. z
            return Key'Val (Key'Pos (Key_A) + Natural (Sym - 16#61#));
         when 16#41# .. 16#5A# =>  --  A .. Z
            return Key'Val (Key'Pos (Key_A) + Natural (Sym - 16#41#));
         when 16#30# .. 16#39# =>  --  0 .. 9
            return Key'Val (Key'Pos (Key_0) + Natural (Sym - 16#30#));
         when 16#FF0D# => return Key_Return;
         when 16#FF1B# => return Key_Escape;
         when 16#FF08# => return Key_Backspace;
         when 16#FF09# => return Key_Tab;
         when 16#20#   => return Key_Space;
         when 16#FF63# => return Key_Insert;
         when 16#FFFF# => return Key_Delete;
         when 16#FF50# => return Key_Home;
         when 16#FF57# => return Key_End;
         when 16#FF55# => return Key_Page_Up;
         when 16#FF56# => return Key_Page_Down;
         when 16#FF51# => return Key_Left;
         when 16#FF53# => return Key_Right;
         when 16#FF52# => return Key_Up;
         when 16#FF54# => return Key_Down;
         when 16#FFBE# .. 16#FFC9# =>  --  F1 .. F12
            return Key'Val (Key'Pos (Key_F1) + Natural (Sym - 16#FFBE#));
         when 16#FFE1# => return Key_Left_Shift;
         when 16#FFE2# => return Key_Right_Shift;
         when 16#FFE3# => return Key_Left_Ctrl;
         when 16#FFE4# => return Key_Right_Ctrl;
         when 16#FFE9# => return Key_Left_Alt;
         when 16#FFEA# => return Key_Right_Alt;
         when 16#FFEB# => return Key_Left_Super;
         when 16#FFEC# => return Key_Right_Super;
         when 16#FFE5# => return Key_Caps_Lock;
         when others   => return Key_Unknown;
      end case;
   end To_Key;

   function State_To_Mods (State : unsigned) return Modifiers is
     ((Shift     => (State and 1) /= 0,
       Caps_Lock => (State and 2) /= 0,
       Ctrl      => (State and 4) /= 0,
       Alt       => (State and 8) /= 0,
       Super     => (State and 64) /= 0));

   ---------------------------------------------------------------------
   --  Translate one XEvent into zero or more Portal events
   ---------------------------------------------------------------------

   procedure Translate (Raw : aliased XEvent_Raw) is
      --  XEvent is a C union; each view overlays the same bytes.
      Any : XAny_Event with Import, Address => Raw'Address;
      KE  : aliased XKey_Event with Import, Address => Raw'Address;
      BE  : XButton_Event with Import, Address => Raw'Address;
      CE  : XConfigure_Event with Import, Address => Raw'Address;
      CM  : XClient_Message_Event with Import, Address => Raw'Address;

      W   : constant Window_Id := Id_Of (Any.Win);
      T   : constant Ticks := Now;
   begin
      if W = No_Window then
         return;
      end if;

      case Any.Kind is
         when Key_Press | Key_Release =>
            declare
               Sym : constant XID := XLookupKeysym (KE'Access, 0);
               K   : constant Key := To_Key (Sym);
               Down : constant Boolean := Any.Kind = Key_Press;
            begin
               Mods := State_To_Mods (KE.State);
               declare
                  Repeat : constant Boolean := Down and then Keys_Down (K);
               begin
                  Keys_Down (K) := Down;
                  if Down then
                     Enqueue ((Kind => Key_Down, Time => T, Window => W,
                               Key => K, Mods => Mods, Repeat => Repeat));
                  else
                     Enqueue ((Kind => Key_Up, Time => T, Window => W,
                               Key => K, Mods => Mods, Repeat => Repeat));
                  end if;
               end;
               --  Text: printable ASCII only. Milestone: XIM / xkb_compose.
               if Down and then Text_Enabled (W)
                 and then Sym in 16#20# .. 16#7E#
               then
                  Enqueue ((Kind => Text_Input, Time => T, Window => W,
                            Text => [Character'Val (Sym), ' ', ' ', ' '],
                            Length => 1));
               end if;
            end;

         when Button_Press | Button_Release =>
            declare
               P  : constant Point := (Pixels (BE.X), Pixels (BE.Y));
               Down : constant Boolean := Any.Kind = Button_Press;
            begin
               case BE.Button is
                  when 4 | 5 =>
                     if Down then
                        Enqueue ((Kind => Mouse_Wheel, Time => T, Window => W,
                                  Wheel_X => 0,
                                  Wheel_Y => (if BE.Button = 4 then 1 else -1),
                                  Wheel_At => P));
                     end if;
                  when 6 | 7 =>
                     if Down then
                        Enqueue ((Kind => Mouse_Wheel, Time => T, Window => W,
                                  Wheel_X => (if BE.Button = 6 then -1 else 1),
                                  Wheel_Y => 0, Wheel_At => P));
                     end if;
                  when others =>
                     declare
                        B : constant Mouse_Button :=
                          (case BE.Button is
                             when 1 => Left, when 2 => Middle, when 3 => Right,
                             when 8 => Back, when 9 => Forward, when others => Left);
                     begin
                        Buttons (B) := Down;
                        if Down then
                           Enqueue ((Kind => Mouse_Down, Time => T, Window => W,
                                     Button => B, Where => P, Clicks => 1));
                        else
                           Enqueue ((Kind => Mouse_Up, Time => T, Window => W,
                                     Button => B, Where => P, Clicks => 1));
                        end if;
                     end;
               end case;
            end;

         when Motion_Notify =>
            begin
               Enqueue ((Kind => Mouse_Move, Time => T, Window => W,
                         At_Pos => (Pixels (BE.X), Pixels (BE.Y)),
                         Delta_X => 0, Delta_Y => 0, Held => Buttons));
            end;

         when Enter_Notify => Enqueue ((Kind => Mouse_Enter, Time => T, Window => W));
         when Leave_Notify => Enqueue ((Kind => Mouse_Leave, Time => T, Window => W));
         when Focus_In     => Enqueue ((Kind => Window_Focus_In, Time => T, Window => W));
         when Focus_Out    => Enqueue ((Kind => Window_Focus_Out, Time => T, Window => W));
         when Expose       => Enqueue ((Kind => Window_Expose, Time => T, Window => W));
         when Map_Notify   => Enqueue ((Kind => Window_Shown, Time => T, Window => W));
         when Unmap_Notify => Enqueue ((Kind => Window_Hidden, Time => T, Window => W));

         when Configure_Notify =>
            declare
               S  : constant Portal.Size := (Extent (CE.Width), Extent (CE.Height));
            begin
               if S /= Slots (W).Size then
                  Slots (W).Size := S;
                  Enqueue ((Kind => Window_Resized, Time => T, Window => W, Size => S));
               end if;
            end;

         when Client_Message =>
            begin
               if Atom (CM.Data_L0) = WM_Delete then
                  Enqueue ((Kind => Window_Close, Time => T, Window => W));
               end if;
            end;

         when others => null;
      end case;
   end Translate;

   procedure Pump is
      Raw : aliased XEvent_Raw;
   begin
      while XPending (Display) > 0 loop
         XNextEvent (Display, Raw);
         Translate (Raw);
      end loop;
   end Pump;

   ---------------------------------------------------------------------
   --  Lifetime
   ---------------------------------------------------------------------

   procedure Initialize (Success : out Boolean) is
      Supported : aliased Bool;
      Name : chars_ptr := New_String ("WM_DELETE_WINDOW");
   begin
      Start := Ada.Calendar.Clock;
      Display := XOpenDisplay (Null_Ptr);
      if Display = Null_Display then
         Success := False;
         Free (Name);
         return;
      end if;
      Screen   := XDefaultScreen (Display);
      Visual   := XDefaultVisual (Display, Screen);
      Depth    := XDefaultDepth (Display, Screen);
      Graphics := XDefaultGC (Display, Screen);
      WM_Delete := XInternAtom (Display, Name, 0);
      Free (Name);
      if XkbSetDetectableAutoRepeat (Display, 1, Supported'Access) = 0 then
         null;  --  repeats will show as release+press; acceptable
      end if;
      Initialized := True;
      Success := True;
   end Initialize;

   procedure Finalize is
   begin
      for W in Valid_Window_Id loop
         if Slots (W).Open then
            XDestroyWindow (Display, Slots (W).Handle);
            Slots (W).Open := False;
         end if;
      end loop;
      XCloseDisplay (Display);
      Display := Null_Display;
      Initialized := False;
   end Finalize;

   ---------------------------------------------------------------------
   --  Windows
   ---------------------------------------------------------------------

   procedure Create_Window
     (Title  : String;
      Size   : Portal.Size;
      Flags  : Window_Flags;
      Window : out Window_Id)
   is
      H    : Xlib.Window;
      Name : chars_ptr;
      Prot : aliased Atom := WM_Delete;
   begin
      Window := No_Window;
      for W in Valid_Window_Id loop
         if not Slots (W).Open then
            H := XCreateSimpleWindow
              (Display, XDefaultRootWindow (Display), 0, 0,
               unsigned (Size.Width), unsigned (Size.Height), 0,
               XBlackPixel (Display, Screen), XBlackPixel (Display, Screen));
            XSelectInput
              (Display, H,
               Key_Press_Mask + Key_Release_Mask + Button_Press_Mask
               + Button_Release_Mask + Pointer_Motion_Mask + Enter_Window_Mask
               + Leave_Window_Mask + Exposure_Mask + Structure_Notify_Mask
               + Focus_Change_Mask);
            if XSetWMProtocols (Display, H, Prot'Access, 1) = 0 then
               null;
            end if;
            Name := New_String (Title);
            XStoreName (Display, H, Name);
            Free (Name);
            if not Flags.Hidden then
               XMapWindow (Display, H);
            end if;
            XFlush (Display);
            Slots (W) := (Open => True, Handle => H, Size => Size);
            Window := W;
            return;
         end if;
      end loop;
   end Create_Window;

   procedure Destroy_Window (Window : Window_Id) is
   begin
      XDestroyWindow (Display, Slots (Window).Handle);
      XFlush (Display);
      Slots (Window).Open := False;
   end Destroy_Window;

   procedure Set_Title (Window : Window_Id; Title : String) is
      Name : chars_ptr := New_String (Title);
   begin
      XStoreName (Display, Slots (Window).Handle, Name);
      Free (Name);
      XFlush (Display);
   end Set_Title;

   procedure Set_Size (Window : Window_Id; Size : Portal.Size) is
   begin
      XResizeWindow (Display, Slots (Window).Handle,
                     unsigned (Size.Width), unsigned (Size.Height));
      XFlush (Display);
   end Set_Size;

   function Get_Size (Window : Window_Id) return Portal.Size is
     (Slots (Window).Size);

   procedure Show (Window : Window_Id) is
   begin
      XMapWindow (Display, Slots (Window).Handle); XFlush (Display);
   end Show;

   procedure Hide (Window : Window_Id) is
   begin
      XUnmapWindow (Display, Slots (Window).Handle); XFlush (Display);
   end Hide;

   function Scale (Window : Window_Id) return Positive is (100);
   --  Milestone: read Xft.dpi from resources, or the monitor's mm size.

   ---------------------------------------------------------------------
   --  Present: RGBA8888 -> the visual's 32-bit BGRX via a temp buffer.
   --  Milestone: XShm, and a visual check instead of assuming 24/32.
   ---------------------------------------------------------------------

   type Byte is mod 2 ** 8;
   type Byte_Array is array (Natural range <>) of Byte with Pack;

   procedure Present (Window : Window_Id; Frame : Buffer) is
      W : constant Natural := Natural (Width (Frame));
      H : constant Natural := Natural (Height (Frame));
      Data : Byte_Array (0 .. W * H * 4 - 1);
      Img  : XImage_Ptr;
      I    : Natural := 0;
   begin
      for Y in 0 .. Frame.Height loop
         for X in 0 .. Frame.Width loop
            declare
               C : constant Color := Frame.Pixels (Y, X);
            begin
               Data (I)     := Byte (C.B);
               Data (I + 1) := Byte (C.G);
               Data (I + 2) := Byte (C.R);
               Data (I + 3) := 0;
               I := I + 4;
            end;
         end loop;
      end loop;
      Img := XCreateImage
        (Display, Visual, unsigned (Depth), ZPixmap, 0, Data'Address,
         unsigned (W), unsigned (H), 32, int (W * 4));
      if XPutImage (Display, Slots (Window).Handle, Graphics, Img,
                    0, 0, 0, 0, unsigned (W), unsigned (H)) /= 0
      then
         null;
      end if;
      --  XDestroyImage would free Data; we own it, so free only the struct.
      XFree (Img);
      XFlush (Display);
   end Present;

   ---------------------------------------------------------------------
   --  Events
   ---------------------------------------------------------------------

   procedure Poll (E : out Event) is
   begin
      Pump;
      if Q_Count > 0 then
         E := Dequeue;
      else
         E := No_Event;
      end if;
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
   function Current_Modifiers return Modifiers is (Mods);

   function Mouse_Position (Window : Window_Id) return Point is
      Root, Child : aliased Xlib.Window;
      RX, RY, WX, WY : aliased int;
      Mask : aliased unsigned;
   begin
      if XQueryPointer (Display, Slots (Window).Handle, Root'Access, Child'Access,
                        RX'Access, RY'Access, WX'Access, WY'Access, Mask'Access) /= 0
      then
         return (Pixels (WX), Pixels (WY));
      end if;
      return (0, 0);
   end Mouse_Position;

   function Mouse_Buttons return Button_State is (Buttons);

   function Gamepad (Id : Valid_Gamepad_Id) return Gamepad_State is
     ((Connected => False, others => <>));
   --  Milestone: /dev/input/js* or evdev.

   procedure Set_Text_Input (Window : Window_Id; Enabled : Boolean) is
   begin
      Text_Enabled (Window) := Enabled;
   end Set_Text_Input;

   ---------------------------------------------------------------------
   --  Cursor, clipboard
   ---------------------------------------------------------------------

   procedure Set_Cursor (Window : Window_Id; Shape : Cursor_Shape) is
      --  X11 cursor font glyph numbers (cursorfont.h)
      Glyph : constant unsigned :=
        (case Shape is
           when Arrow => 2, when I_Beam => 152, when Crosshair => 34,
           when Hand => 60, when Resize_EW => 108, when Resize_NS => 116,
           when Resize_NWSE => 14, when Resize_NESW => 12,
           when Not_Allowed => 0, when Busy => 150);
   begin
      XDefineCursor (Display, Slots (Window).Handle, XCreateFontCursor (Display, Glyph));
      XFlush (Display);
   end Set_Cursor;

   procedure Set_Cursor_Visible (Visible : Boolean) is null;
   --  Milestone: an invisible 1x1 pixmap cursor.

   procedure Get_Clipboard (Text : out String; Last : out Natural) is
      N : constant Natural := Natural'Min (Text'Length, Clipboard_Last);
   begin
      Text (Text'First .. Text'First + N - 1) := Clipboard (1 .. N);
      Last := Text'First + N - 1;
   end Get_Clipboard;
   --  Milestone: real CLIPBOARD selection (XConvertSelection).

   procedure Set_Clipboard (Text : String) is
   begin
      Clipboard (1 .. Text'Length) := Text;
      Clipboard_Last := Text'Length;
   end Set_Clipboard;

   ---------------------------------------------------------------------
   --  Time
   ---------------------------------------------------------------------

   function Now return Ticks is
      use Ada.Calendar;
   begin
      if not Initialized then
         return 0;
      end if;
      return Ticks (Duration'(Clock - Start) * 1000.0);
   end Now;

   procedure Sleep (Ms : Natural) is
   begin
      delay Duration (Ms) / 1000.0;
   end Sleep;

end Portal.Backend;
