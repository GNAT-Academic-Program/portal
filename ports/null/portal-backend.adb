--  The null port: no display. Every window "exists", Present drops
--  the frame, Poll returns Quit after N calls so a loop terminates.
--  CI and tests build against this port. It is also the template for
--  a new port: copy it, replace the bodies.

with Ada.Calendar;

package body Portal.Backend with SPARK_Mode => Off is

   Initialized : Boolean := False;
   Open        : array (Valid_Window_Id) of Boolean := [others => False];
   Sizes       : array (Valid_Window_Id) of Portal.Size;
   Polls       : Natural := 0;
   Start       : Ada.Calendar.Time;

   Quit_After  : constant := 100;
   --  Poll returns Quit exactly once, on the Nth call, so that "loop
   --  until Quit" showcases finish under CI.

   Max_Queue : constant := 256;
   Queue     : array (1 .. Max_Queue) of Event;
   Q_Head, Q_Count : Natural := 0;

   Clipboard      : String (1 .. Max_Clipboard);
   Clipboard_Last : Natural := 0;

   function Is_Initialized return Boolean is (Initialized);
   function Is_Open (W : Window_Id) return Boolean is
     (W /= No_Window and then Open (W));

   procedure Initialize (Success : out Boolean) is
   begin
      Start := Ada.Calendar.Clock;
      Initialized := True;
      Success := True;
   end Initialize;

   procedure Finalize is
   begin
      Open := [others => False];
      Initialized := False;
   end Finalize;

   procedure Create_Window
     (Title  : String;
      Size   : Portal.Size;
      Flags  : Window_Flags;
      Window : out Window_Id)
   is
      pragma Unreferenced (Title, Flags);
   begin
      Window := No_Window;
      for W in Valid_Window_Id loop
         if not Open (W) then
            Open (W) := True;
            Sizes (W) := Size;
            Window := W;
            return;
         end if;
      end loop;
   end Create_Window;

   procedure Destroy_Window (Window : Window_Id) is
   begin
      Open (Window) := False;
   end Destroy_Window;

   procedure Set_Title (Window : Window_Id; Title : String) is null;

   procedure Set_Size (Window : Window_Id; Size : Portal.Size) is
   begin
      Sizes (Window) := Size;
   end Set_Size;

   function Get_Size (Window : Window_Id) return Portal.Size is (Sizes (Window));

   procedure Show (Window : Window_Id) is null;
   procedure Hide (Window : Window_Id) is null;

   function Scale (Window : Window_Id) return Positive is (100);

   procedure Present (Window : Window_Id; Frame : Buffer) is null;

   procedure Poll (E : out Event) is
   begin
      if Q_Count > 0 then
         E := Queue (Q_Head + 1);
         Q_Head := (Q_Head + 1) mod Max_Queue;
         Q_Count := Q_Count - 1;
         return;
      end if;
      Polls := Polls + 1;
      if Polls = Quit_After then
         E := (Kind => Quit, Time => Now, Window => No_Window);
      else
         E := No_Event;
      end if;
   end Poll;

   procedure Wait (E : out Event; Timeout_Ms : Natural) is
   begin
      Poll (E);
      if E.Kind = None and then Timeout_Ms > 0 then
         Sleep (Timeout_Ms);
      end if;
   end Wait;

   procedure Push (E : Event) is
   begin
      if Q_Count < Max_Queue then
         Queue ((Q_Head + Q_Count) mod Max_Queue + 1) := E;
         Q_Count := Q_Count + 1;
      end if;
   end Push;

   function Is_Key_Down (K : Key) return Boolean is (False);
   function Current_Modifiers return Modifiers is (No_Modifiers);
   function Mouse_Position (Window : Window_Id) return Point is ((0, 0));
   function Mouse_Buttons return Button_State is ([others => False]);
   function Gamepad (Id : Valid_Gamepad_Id) return Gamepad_State is
     ((Connected => False, others => <>));

   procedure Set_Text_Input (Window : Window_Id; Enabled : Boolean) is null;
   procedure Set_Cursor (Window : Window_Id; Shape : Cursor_Shape) is null;
   procedure Set_Cursor_Visible (Visible : Boolean) is null;

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
