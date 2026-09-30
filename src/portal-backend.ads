--  The platform seam. Every desktop port (X11, Wayland, Win32, Cocoa)
--  is a BODY of this package, selected at build time by the PORTAL_PORT
--  scenario variable in portal.gpr. No dispatching, no access-to-
--  subprogram, one port per binary.
--
--  This is the API the application sees. Everything below it is the
--  port's business: connections, native handles, event translation.
--
--  Scope, deliberately: what a UI toolkit or a 2D game needs from a
--  desktop, and nothing else. No audio, no threads, no file dialogs,
--  no GPU context (a later package can expose the native handle for
--  that). Compare with SDL3's video + events subsystems and GLFW.

with Portal.Framebuffer; use Portal.Framebuffer;
with Portal.Input;       use Portal.Input;

package Portal.Backend with SPARK_Mode is

   ---------------------------------------------------------------------
   --  Lifetime
   ---------------------------------------------------------------------

   function Is_Initialized return Boolean;

   procedure Initialize (Success : out Boolean)
     with Pre  => not Is_Initialized,
          Post => (if Success then Is_Initialized);
   --  Connects to the display. Fails (Success = False) when there is
   --  no display; never raises.

   procedure Finalize
     with Pre => Is_Initialized, Post => not Is_Initialized;
   --  Destroys every window and disconnects.

   ---------------------------------------------------------------------
   --  Windows
   ---------------------------------------------------------------------

   type Window_Flags is record
      Resizable  : Boolean := True;
      Borderless : Boolean := False;
      Hidden     : Boolean := False;
   end record;

   function Is_Open (W : Window_Id) return Boolean;
   --  False for No_Window and for destroyed windows.

   procedure Create_Window
     (Title  : String;
      Size   : Bedrock.Screen.Size;
      Flags  : Window_Flags;
      Window : out Window_Id)
     with Pre  => Is_Initialized,
          Post => (if Window /= No_Window then Is_Open (Window));
   --  Window = No_Window when Max_Windows are already open or the
   --  platform refused.

   procedure Destroy_Window (Window : Window_Id)
     with Pre => Is_Initialized and then Is_Open (Window),
          Post => not Is_Open (Window);

   procedure Set_Title (Window : Window_Id; Title : String)
     with Pre => Is_Initialized and then Is_Open (Window);

   procedure Set_Size (Window : Window_Id; Size : Bedrock.Screen.Size)
     with Pre => Is_Initialized and then Is_Open (Window);

   function Get_Size (Window : Window_Id) return Bedrock.Screen.Size
     with Pre => Is_Initialized and then Is_Open (Window);
   --  Client area, in physical pixels. This is the size to draw at.

   procedure Show (Window : Window_Id)
     with Pre => Is_Initialized and then Is_Open (Window);
   procedure Hide (Window : Window_Id)
     with Pre => Is_Initialized and then Is_Open (Window);

   function Scale (Window : Window_Id) return Positive
     with Pre => Is_Initialized and then Is_Open (Window);
   --  Display scale in percent (100, 150, 200). Logical px * Scale / 100
   --  is physical px. Applications lay out in logical px and draw in
   --  physical px.

   ---------------------------------------------------------------------
   --  Presenting pixels
   ---------------------------------------------------------------------

   procedure Present (Window : Window_Id; Frame : Buffer)
     with Pre => Is_Initialized and then Is_Open (Window);
   --  Copies Frame to the window. Frame should be Get_Size (Window);
   --  a smaller frame is drawn top-left, a larger one is cropped.
   --  Blocks until the copy is issued, not until vsync.

   ---------------------------------------------------------------------
   --  Events
   ---------------------------------------------------------------------

   procedure Poll (E : out Event)
     with Pre => Is_Initialized;
   --  Next pending event, or No_Event (Kind = None) if the queue is
   --  empty. Never blocks.

   procedure Wait (E : out Event; Timeout_Ms : Natural)
     with Pre => Is_Initialized;
   --  Like Poll, but blocks up to Timeout_Ms for an event. 0 is Poll.

   procedure Push (E : Event)
     with Pre => Is_Initialized;
   --  Appends an application event to the queue. Dropped if the
   --  queue is full.

   ---------------------------------------------------------------------
   --  Polled input state
   ---------------------------------------------------------------------

   function Is_Key_Down (K : Key) return Boolean
     with Pre => Is_Initialized;

   function Current_Modifiers return Modifiers
     with Pre => Is_Initialized;

   function Mouse_Position (Window : Window_Id) return Point
     with Pre => Is_Initialized and then Is_Open (Window);
   --  In window client coordinates, physical px.

   function Mouse_Buttons return Button_State
     with Pre => Is_Initialized;

   function Gamepad (Id : Valid_Gamepad_Id) return Gamepad_State
     with Pre => Is_Initialized;

   procedure Set_Text_Input (Window : Window_Id; Enabled : Boolean)
     with Pre => Is_Initialized and then Is_Open (Window);
   --  When enabled, key presses also produce Text_Input events (and
   --  the IME, if any, is active). A text field turns this on when
   --  focused and off when it loses focus.

   ---------------------------------------------------------------------
   --  Cursor and clipboard
   ---------------------------------------------------------------------

   type Cursor_Shape is
     (Arrow, I_Beam, Crosshair, Hand, Resize_EW, Resize_NS, Resize_NWSE,
      Resize_NESW, Not_Allowed, Busy);

   procedure Set_Cursor (Window : Window_Id; Shape : Cursor_Shape)
     with Pre => Is_Initialized and then Is_Open (Window);

   procedure Set_Cursor_Visible (Visible : Boolean)
     with Pre => Is_Initialized;

   Max_Clipboard : constant := 64 * 1024;

   procedure Get_Clipboard (Text : out String; Last : out Natural)
     with Pre  => Is_Initialized and then Text'Length <= Max_Clipboard,
          Post => Last <= Text'Last;
   --  UTF-8. Last = Text'First - 1 when empty. Truncated to Text.

   procedure Set_Clipboard (Text : String)
     with Pre => Is_Initialized and then Text'Length <= Max_Clipboard;

   ---------------------------------------------------------------------
   --  Time
   ---------------------------------------------------------------------

   function Now return Ticks;
   --  Milliseconds since Initialize. Valid without Initialize (0).

   procedure Sleep (Ms : Natural);

end Portal.Backend;
