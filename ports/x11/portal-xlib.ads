--  X11 port. Thin bindings to Xlib, straight from Xlib.h, only what
--  Portal.Backend needs. No XCB, no extensions: XShm and XInput2 are
--  natural first milestones for the team.

with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with System;

private package Portal.Xlib is

   subtype Display_Ptr is System.Address;
   subtype Visual_Ptr  is System.Address;
   subtype GC          is System.Address;
   subtype XImage_Ptr  is System.Address;
   type XID is new unsigned_long;
   subtype Window is XID;
   subtype Atom   is XID;
   subtype Cursor is XID;
   type Bool is new int;

   Null_Display : constant Display_Ptr := System.Null_Address;

   ---------------------------------------------------------------------
   --  Event masks and types
   ---------------------------------------------------------------------

   Key_Press_Mask         : constant := 2 ** 0;
   Key_Release_Mask       : constant := 2 ** 1;
   Button_Press_Mask      : constant := 2 ** 2;
   Button_Release_Mask    : constant := 2 ** 3;
   Enter_Window_Mask      : constant := 2 ** 4;
   Leave_Window_Mask      : constant := 2 ** 5;
   Pointer_Motion_Mask    : constant := 2 ** 6;
   Exposure_Mask          : constant := 2 ** 15;
   Structure_Notify_Mask  : constant := 2 ** 17;
   Focus_Change_Mask      : constant := 2 ** 21;

   Key_Press        : constant := 2;
   Key_Release      : constant := 3;
   Button_Press     : constant := 4;
   Button_Release   : constant := 5;
   Motion_Notify    : constant := 6;
   Enter_Notify     : constant := 7;
   Leave_Notify     : constant := 8;
   Focus_In         : constant := 9;
   Focus_Out        : constant := 10;
   Expose           : constant := 12;
   Destroy_Notify   : constant := 17;
   Unmap_Notify     : constant := 18;
   Map_Notify       : constant := 19;
   Configure_Notify : constant := 22;
   Client_Message   : constant := 33;

   ZPixmap : constant := 2;

   ---------------------------------------------------------------------
   --  XEvent: we only read the common prefix and a few unions by
   --  overlaying records on a 192-byte buffer, as Xlib does.
   ---------------------------------------------------------------------

   type XEvent_Raw is array (1 .. 24) of unsigned_long
     with Convention => C;  --  192 bytes on LP64

   type XAny_Event is record
      Kind       : int;
      Serial     : unsigned_long;
      Send_Event : Bool;
      Display    : Display_Ptr;
      Win        : Window;
   end record with Convention => C;

   type XKey_Event is record
      Kind       : int;
      Serial     : unsigned_long;
      Send_Event : Bool;
      Display    : Display_Ptr;
      Win        : Window;
      Root       : Window;
      Subwindow  : Window;
      Time       : unsigned_long;
      X, Y       : int;
      X_Root     : int;
      Y_Root     : int;
      State      : unsigned;
      Keycode    : unsigned;
      Same_Screen : Bool;
   end record with Convention => C;

   type XButton_Event is record
      Kind       : int;
      Serial     : unsigned_long;
      Send_Event : Bool;
      Display    : Display_Ptr;
      Win        : Window;
      Root       : Window;
      Subwindow  : Window;
      Time       : unsigned_long;
      X, Y       : int;
      X_Root     : int;
      Y_Root     : int;
      State      : unsigned;
      Button     : unsigned;
      Same_Screen : Bool;
   end record with Convention => C;

   subtype XMotion_Event is XButton_Event;  --  same layout up to State

   type XConfigure_Event is record
      Kind       : int;
      Serial     : unsigned_long;
      Send_Event : Bool;
      Display    : Display_Ptr;
      Event      : Window;
      Win        : Window;
      X, Y       : int;
      Width      : int;
      Height     : int;
      Border     : int;
      Above      : Window;
      Override   : Bool;
   end record with Convention => C;

   type XClient_Message_Event is record
      Kind         : int;
      Serial       : unsigned_long;
      Send_Event   : Bool;
      Display      : Display_Ptr;
      Win          : Window;
      Message_Type : Atom;
      Format       : int;
      Data_L0      : long;  --  first long of the data union
   end record with Convention => C;

   ---------------------------------------------------------------------
   --  Functions
   ---------------------------------------------------------------------

   function XOpenDisplay (Name : chars_ptr) return Display_Ptr
     with Import, Convention => C, External_Name => "XOpenDisplay";
   procedure XCloseDisplay (D : Display_Ptr)
     with Import, Convention => C, External_Name => "XCloseDisplay";
   function XDefaultScreen (D : Display_Ptr) return int
     with Import, Convention => C, External_Name => "XDefaultScreen";
   function XDefaultRootWindow (D : Display_Ptr) return Window
     with Import, Convention => C, External_Name => "XDefaultRootWindow";
   function XDefaultVisual (D : Display_Ptr; Screen : int) return Visual_Ptr
     with Import, Convention => C, External_Name => "XDefaultVisual";
   function XDefaultDepth (D : Display_Ptr; Screen : int) return int
     with Import, Convention => C, External_Name => "XDefaultDepth";
   function XDefaultGC (D : Display_Ptr; Screen : int) return GC
     with Import, Convention => C, External_Name => "XDefaultGC";
   function XBlackPixel (D : Display_Ptr; Screen : int) return unsigned_long
     with Import, Convention => C, External_Name => "XBlackPixel";
   function XWhitePixel (D : Display_Ptr; Screen : int) return unsigned_long
     with Import, Convention => C, External_Name => "XWhitePixel";

   function XCreateSimpleWindow
     (D : Display_Ptr; Parent : Window;
      X, Y : int; Width, Height : unsigned; Border_Width : unsigned;
      Border, Background : unsigned_long) return Window
     with Import, Convention => C, External_Name => "XCreateSimpleWindow";
   procedure XDestroyWindow (D : Display_Ptr; W : Window)
     with Import, Convention => C, External_Name => "XDestroyWindow";
   procedure XMapWindow (D : Display_Ptr; W : Window)
     with Import, Convention => C, External_Name => "XMapWindow";
   procedure XUnmapWindow (D : Display_Ptr; W : Window)
     with Import, Convention => C, External_Name => "XUnmapWindow";
   procedure XStoreName (D : Display_Ptr; W : Window; Name : chars_ptr)
     with Import, Convention => C, External_Name => "XStoreName";
   procedure XResizeWindow (D : Display_Ptr; W : Window; Width, Height : unsigned)
     with Import, Convention => C, External_Name => "XResizeWindow";
   procedure XSelectInput (D : Display_Ptr; W : Window; Mask : long)
     with Import, Convention => C, External_Name => "XSelectInput";
   procedure XFlush (D : Display_Ptr)
     with Import, Convention => C, External_Name => "XFlush";
   procedure XSync (D : Display_Ptr; Discard : Bool)
     with Import, Convention => C, External_Name => "XSync";

   function XPending (D : Display_Ptr) return int
     with Import, Convention => C, External_Name => "XPending";
   procedure XNextEvent (D : Display_Ptr; E : out XEvent_Raw)
     with Import, Convention => C, External_Name => "XNextEvent";

   function XInternAtom (D : Display_Ptr; Name : chars_ptr; Only_If_Exists : Bool) return Atom
     with Import, Convention => C, External_Name => "XInternAtom";
   function XSetWMProtocols
     (D : Display_Ptr; W : Window; Protocols : access Atom; Count : int) return int
     with Import, Convention => C, External_Name => "XSetWMProtocols";

   function XCreateImage
     (D : Display_Ptr; V : Visual_Ptr; Depth : unsigned; Format : int;
      Offset : int; Data : System.Address; Width, Height : unsigned;
      Bitmap_Pad : int; Bytes_Per_Line : int) return XImage_Ptr
     with Import, Convention => C, External_Name => "XCreateImage";
   function XPutImage
     (D : Display_Ptr; W : Window; G : GC; Image : XImage_Ptr;
      Src_X, Src_Y, Dst_X, Dst_Y : int; Width, Height : unsigned) return int
     with Import, Convention => C, External_Name => "XPutImage";
   procedure XFree (Data : System.Address)
     with Import, Convention => C, External_Name => "XFree";

   function XLookupKeysym (E : access XKey_Event; Index : int) return XID
     with Import, Convention => C, External_Name => "XLookupKeysym";
   function XkbSetDetectableAutoRepeat
     (D : Display_Ptr; Detectable : Bool; Supported : access Bool) return Bool
     with Import, Convention => C, External_Name => "XkbSetDetectableAutoRepeat";

   function XCreateFontCursor (D : Display_Ptr; Shape : unsigned) return Cursor
     with Import, Convention => C, External_Name => "XCreateFontCursor";
   procedure XDefineCursor (D : Display_Ptr; W : Window; C : Cursor)
     with Import, Convention => C, External_Name => "XDefineCursor";
   procedure XUndefineCursor (D : Display_Ptr; W : Window)
     with Import, Convention => C, External_Name => "XUndefineCursor";

   function XQueryPointer
     (D : Display_Ptr; W : Window; Root, Child : access Window;
      Root_X, Root_Y, Win_X, Win_Y : access int; Mask : access unsigned) return Bool
     with Import, Convention => C, External_Name => "XQueryPointer";

end Portal.Xlib;
