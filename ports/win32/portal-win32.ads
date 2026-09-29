--  Win32 bindings, straight from windows.h, only what the port needs.
--  NOT COMPILE-CHECKED where this seed was built (no MinGW). The first
--  Windows team to build it fixes whatever the compiler says and opens
--  a PR against the seed; that is expected and welcome.

with Interfaces.C; use Interfaces.C;
with System;

private package Portal.Win32 is

   subtype HANDLE    is System.Address;
   subtype HWND      is HANDLE;
   subtype HINSTANCE is HANDLE;
   subtype HDC       is HANDLE;
   subtype HCURSOR   is HANDLE;
   subtype HICON     is HANDLE;
   subtype HBRUSH    is HANDLE;
   subtype LPCSTR    is System.Address;
   type UINT   is new unsigned;
   type DWORD  is new unsigned_long;  --  32-bit on Windows
   type BOOL   is new int;
   type WPARAM is mod 2 ** Standard'Address_Size;
   type LPARAM is mod 2 ** Standard'Address_Size;
   --  LPARAM is signed in C; we treat it as a bag of bits and extract
   --  signed halves ourselves. Returning it as LRESULT is the same bits.
   subtype LRESULT is LPARAM;
   type ATOM is new unsigned_short;

   type WNDPROC is access function
     (H : HWND; Msg : UINT; W : WPARAM; L : LPARAM) return LRESULT
     with Convention => Stdcall;

   type Win_Point is record
      X, Y : long;
   end record with Convention => C;

   type Win_Rect is record
      Left, Top, Right, Bottom : long;
   end record with Convention => C;

   type MSG is record
      Window  : HWND;
      Message : UINT;
      W       : WPARAM;
      L       : LPARAM;
      Time    : DWORD;
      Pt      : Win_Point;
      Private_Field : DWORD;
   end record with Convention => C;

   type WNDCLASSEXA is record
      Size        : UINT;
      Style       : UINT;
      Proc        : WNDPROC;
      Cls_Extra   : int := 0;
      Wnd_Extra   : int := 0;
      Instance    : HINSTANCE;
      Icon        : HICON := System.Null_Address;
      Cursor      : HCURSOR;
      Background  : HBRUSH := System.Null_Address;
      Menu_Name   : LPCSTR := System.Null_Address;
      Class_Name  : LPCSTR;
      Icon_Small  : HICON := System.Null_Address;
   end record with Convention => C;

   type BITMAPINFOHEADER is record
      Size          : DWORD;
      Width         : long;
      Height        : long;   --  negative = top-down
      Planes        : unsigned_short := 1;
      Bit_Count     : unsigned_short := 32;
      Compression   : DWORD := 0;  --  BI_RGB
      Size_Image    : DWORD := 0;
      X_Pels        : long := 0;
      Y_Pels        : long := 0;
      Clr_Used      : DWORD := 0;
      Clr_Important : DWORD := 0;
   end record with Convention => C;

   type BITMAPINFO is record
      Header : BITMAPINFOHEADER;
      Colors : DWORD := 0;  --  RGBQUAD[1], unused for 32bpp
   end record with Convention => C;

   ---------------------------------------------------------------------
   --  Constants
   ---------------------------------------------------------------------

   CS_OWNDC   : constant := 16#0020#;
   CS_HREDRAW : constant := 16#0002#;
   CS_VREDRAW : constant := 16#0001#;

   WS_OVERLAPPEDWINDOW : constant := 16#00CF0000#;
   WS_POPUP            : constant := 16#80000000#;
   WS_VISIBLE          : constant := 16#10000000#;
   WS_THICKFRAME       : constant := 16#00040000#;
   WS_MAXIMIZEBOX      : constant := 16#00010000#;
   CW_USEDEFAULT       : constant := -2147483648;

   SW_SHOW : constant := 5;
   SW_HIDE : constant := 0;

   PM_REMOVE : constant := 1;
   SRCCOPY   : constant := 16#00CC0020#;
   DIB_RGB_COLORS : constant := 0;

   WM_DESTROY      : constant := 16#0002#;
   WM_SIZE         : constant := 16#0005#;
   WM_SETFOCUS     : constant := 16#0007#;
   WM_KILLFOCUS    : constant := 16#0008#;
   WM_PAINT        : constant := 16#000F#;
   WM_CLOSE        : constant := 16#0010#;
   WM_KEYDOWN      : constant := 16#0100#;
   WM_KEYUP        : constant := 16#0101#;
   WM_CHAR         : constant := 16#0102#;
   WM_SYSKEYDOWN   : constant := 16#0104#;
   WM_SYSKEYUP     : constant := 16#0105#;
   WM_MOUSEMOVE    : constant := 16#0200#;
   WM_LBUTTONDOWN  : constant := 16#0201#;
   WM_LBUTTONUP    : constant := 16#0202#;
   WM_RBUTTONDOWN  : constant := 16#0204#;
   WM_RBUTTONUP    : constant := 16#0205#;
   WM_MBUTTONDOWN  : constant := 16#0207#;
   WM_MBUTTONUP    : constant := 16#0208#;
   WM_MOUSEWHEEL   : constant := 16#020A#;
   WM_XBUTTONDOWN  : constant := 16#020B#;
   WM_XBUTTONUP    : constant := 16#020C#;
   WM_MOUSELEAVE   : constant := 16#02A3#;

   IDC_ARROW : constant := 32512;
   IDC_IBEAM : constant := 32513;
   IDC_WAIT  : constant := 32514;
   IDC_CROSS : constant := 32515;
   IDC_SIZENWSE : constant := 32642;
   IDC_SIZENESW : constant := 32643;
   IDC_SIZEWE   : constant := 32644;
   IDC_SIZENS   : constant := 32645;
   IDC_NO       : constant := 32648;
   IDC_HAND     : constant := 32649;

   ---------------------------------------------------------------------
   --  Functions
   ---------------------------------------------------------------------

   function GetModuleHandleA (Name : LPCSTR) return HINSTANCE
     with Import, Convention => Stdcall, External_Name => "GetModuleHandleA";
   function RegisterClassExA (Class : access constant WNDCLASSEXA) return ATOM
     with Import, Convention => Stdcall, External_Name => "RegisterClassExA";
   function CreateWindowExA
     (Ex_Style : DWORD; Class_Name, Window_Name : LPCSTR; Style : DWORD;
      X, Y, W, H : int; Parent : HWND; Menu : HANDLE; Instance : HINSTANCE;
      Param : System.Address) return HWND
     with Import, Convention => Stdcall, External_Name => "CreateWindowExA";
   function DestroyWindow (H : HWND) return BOOL
     with Import, Convention => Stdcall, External_Name => "DestroyWindow";
   function ShowWindow (H : HWND; Cmd : int) return BOOL
     with Import, Convention => Stdcall, External_Name => "ShowWindow";
   function SetWindowTextA (H : HWND; Text : LPCSTR) return BOOL
     with Import, Convention => Stdcall, External_Name => "SetWindowTextA";
   function SetWindowPos
     (H, After : HWND; X, Y, W, Hh : int; Flags : UINT) return BOOL
     with Import, Convention => Stdcall, External_Name => "SetWindowPos";
   function GetClientRect (H : HWND; R : access Win_Rect) return BOOL
     with Import, Convention => Stdcall, External_Name => "GetClientRect";
   function AdjustWindowRect (R : access Win_Rect; Style : DWORD; Menu : BOOL) return BOOL
     with Import, Convention => Stdcall, External_Name => "AdjustWindowRect";
   function DefWindowProcA (H : HWND; Msg : UINT; W : WPARAM; L : LPARAM) return LRESULT
     with Import, Convention => Stdcall, External_Name => "DefWindowProcA";
   function PeekMessageA
     (M : access MSG; H : HWND; Min, Max : UINT; Remove : UINT) return BOOL
     with Import, Convention => Stdcall, External_Name => "PeekMessageA";
   function TranslateMessage (M : access constant MSG) return BOOL
     with Import, Convention => Stdcall, External_Name => "TranslateMessage";
   function DispatchMessageA (M : access constant MSG) return LRESULT
     with Import, Convention => Stdcall, External_Name => "DispatchMessageA";
   function GetDC (H : HWND) return HDC
     with Import, Convention => Stdcall, External_Name => "GetDC";
   function ReleaseDC (H : HWND; D : HDC) return int
     with Import, Convention => Stdcall, External_Name => "ReleaseDC";
   function StretchDIBits
     (D : HDC; XDest, YDest, DestW, DestH, XSrc, YSrc, SrcW, SrcH : int;
      Bits : System.Address; Info : access constant BITMAPINFO;
      Usage : UINT; Rop : DWORD) return int
     with Import, Convention => Stdcall, External_Name => "StretchDIBits";
   function LoadCursorA (Instance : HINSTANCE; Name : LPCSTR) return HCURSOR
     with Import, Convention => Stdcall, External_Name => "LoadCursorA";
   function SetCursor (C : HCURSOR) return HCURSOR
     with Import, Convention => Stdcall, External_Name => "SetCursor";
   function ShowCursor (Show : BOOL) return int
     with Import, Convention => Stdcall, External_Name => "ShowCursor";
   function GetCursorPos (P : access Win_Point) return BOOL
     with Import, Convention => Stdcall, External_Name => "GetCursorPos";
   function ScreenToClient (H : HWND; P : access Win_Point) return BOOL
     with Import, Convention => Stdcall, External_Name => "ScreenToClient";
   function GetDpiForWindow (H : HWND) return UINT
     with Import, Convention => Stdcall, External_Name => "GetDpiForWindow";
   function GetTickCount64 return Interfaces.Unsigned_64
     with Import, Convention => Stdcall, External_Name => "GetTickCount64";
   procedure Win_Sleep (Ms : DWORD)
     with Import, Convention => Stdcall, External_Name => "Sleep";

end Portal.Win32;
