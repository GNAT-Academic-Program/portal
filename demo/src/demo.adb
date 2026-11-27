with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Bedrock.Screen; use Bedrock.Screen;
with Portal.Backend; use Portal.Backend;
with Portal.Framebuffer; use Portal.Framebuffer;
with Portal.Input; use Portal.Input;

procedure Demo is
   type Buffer_Access is access Buffer;
   procedure Free_Frame is new Ada.Unchecked_Deallocation
     (Buffer, Buffer_Access);

   Frame : Buffer_Access := null;
   Win : Window_Id := No_Window;
   OK : Boolean;
   E : Event;
   Running, Drawable : Boolean := True;
   Paused : Boolean := False;
   type Control_Mode is (Keyboard, Absolute_Mouse, Relative_Mouse);
   Mode : Control_Mode := Keyboard;
   Current_Shape : Cursor_Shape := Arrow;
   Cursor_Shown : Boolean := True;
   Resize_Needed : Boolean := False;
   W_Px : Pixels := 640;
   H_Px : Pixels := 480;
   Paddle_Width : constant Extent := 12;
   Paddle_Height : Extent := 80;
   Paddle_Speed : constant Pixels := 5;
   Ball_Size : constant Extent := 12;
   Ball_Speed : constant Pixels := 4;
   Left_X : constant Pixels := 20;
   function Right_X return Pixels is (W_Px - 32);
   Left_Y, Right_Y : Pixels := 200;
   Ball_X : Pixels := 314;
   Ball_Y : Pixels := 234;
   Ball_DX : Pixels := Ball_Speed;
   Ball_DY : Pixels := 3;
   Left_Score, Right_Score : Natural := 0;
   Frames, FPS, Last_Report : Natural := 0;
   Last_DX, Last_DY : Integer := 0;
   Last_X, Last_Y : Integer := 0;

   procedure Update_Title;
   function Clamp_Paddle (Y : Integer) return Pixels;
   procedure Reset_Ball;
   procedure Reset_Game;
   procedure Resize_Frame;
   procedure Update_Paddles;
   procedure Update_Ball;
   procedure Render;
   procedure Cleanup;

   procedure Update_Title is
   begin
      if not Drawable then
         Set_Title (Win, "Ada Pong | Resize to 160x120 through 1920x1080");
         return;
      end if;
      Set_Title (Win, "Ada Pong |" & Left_Score'Image
                 & " :" & Right_Score'Image
                 & " |" & W_Px'Image & " x" & H_Px'Image
                 & " |" & Scale (Win)'Image & "% DPI"
                 & " |" & FPS'Image & " FPS"
                 & " | " & Control_Mode'Image (Mode)
                 & " | " & Cursor_Shape'Image (Current_Shape)
                 & (if Cursor_Shown then "" else " (hidden)")
                 & (if Paused then " | Paused" else ""));
   end Update_Title;

   function Clamp_Paddle (Y : Integer) return Pixels is
     (Pixels (Integer'Max
        (0, Integer'Min (Y, Integer (H_Px) - Integer (Paddle_Height)))));

   procedure Reset_Ball is
   begin
      Ball_X := W_Px / 2 - Pixels (Ball_Size) / 2;
      Ball_Y := H_Px / 2 - Pixels (Ball_Size) / 2;
      Ball_DX := -Ball_DX;
      Ball_DY := 3;
   end Reset_Ball;

   procedure Reset_Game is
   begin
      Left_Score := 0;
      Right_Score := 0;
      Paddle_Height := Extent'Min (80, Extent (H_Px / 2));
      Left_Y := Clamp_Paddle
        ((Integer (H_Px) - Integer (Paddle_Height)) / 2);
      Right_Y := Left_Y;
      Reset_Ball;
      Update_Title;
   end Reset_Game;

   procedure Resize_Frame is
      S : constant Bedrock.Screen.Size := Get_Size (Win);
      New_W : Pixels;
      New_H : Pixels;
      New_Frame : Buffer_Access;
   begin
      --  The demo bounds allocation; this is not a PAL size limitation.
      Drawable := S.Width in 160 .. 1920
        and then S.Height in 120 .. 1080;
      if not Drawable then
         Update_Title;
         return;
      end if;
      New_W := Pixels (S.Width);
      New_H := Pixels (S.Height);
      if Frame /= null and then New_W = W_Px and then New_H = H_Px then
         Update_Title;
         return;
      end if;
      --  Buffer discriminants are upper bounds, not pixel counts.
      New_Frame := new Buffer (Extent (New_H - 1), Extent (New_W - 1));
      Free_Frame (Frame);
      Frame := New_Frame;
      W_Px := New_W;
      H_Px := New_H;
      Paddle_Height := Extent'Min (Paddle_Height, Extent (H_Px / 2));
      Left_Y := Clamp_Paddle (Integer (Left_Y));
      Right_Y := Clamp_Paddle (Integer (Right_Y));
      Reset_Ball;
      Update_Title;
      Put_Line ("Drawable:" & W_Px'Image & " x" & H_Px'Image);
   end Resize_Frame;

   procedure Update_Paddles is
   begin
      if Is_Key_Down (Key_W) then
         Left_Y := Left_Y - Paddle_Speed;
      end if;
      if Is_Key_Down (Key_S) then
         Left_Y := Left_Y + Paddle_Speed;
      end if;
      if Mode = Keyboard then
         if Is_Key_Down (Key_I) then
            Right_Y := Right_Y - Paddle_Speed;
         end if;
         if Is_Key_Down (Key_K) then
            Right_Y := Right_Y + Paddle_Speed;
         end if;
      end if;
      Left_Y := Clamp_Paddle (Integer (Left_Y));
      Right_Y := Clamp_Paddle (Integer (Right_Y));
   end Update_Paddles;

   procedure Update_Ball is
   begin
      Ball_X := Ball_X + Ball_DX;
      Ball_Y := Ball_Y + Ball_DY;
      if Ball_Y <= 0 then
         Ball_Y := 0;
         Ball_DY := abs Ball_DY;
      elsif Ball_Y + Pixels (Ball_Size) >= H_Px then
         Ball_Y := H_Px - Pixels (Ball_Size);
         Ball_DY := -abs Ball_DY;
      end if;
      if Ball_DX < 0
        and then Ball_X <= Left_X + Pixels (Paddle_Width)
        and then Ball_X + Pixels (Ball_Size) >= Left_X
        and then Ball_Y + Pixels (Ball_Size) > Left_Y
        and then Ball_Y < Left_Y + Pixels (Paddle_Height)
      then
         Ball_X := Left_X + Pixels (Paddle_Width);
         Ball_DX := abs Ball_DX;
      elsif Ball_DX > 0
        and then Ball_X + Pixels (Ball_Size) >= Right_X
        and then Ball_X <= Right_X + Pixels (Paddle_Width)
        and then Ball_Y + Pixels (Ball_Size) > Right_Y
        and then Ball_Y < Right_Y + Pixels (Paddle_Height)
      then
         Ball_X := Right_X - Pixels (Ball_Size);
         Ball_DX := -abs Ball_DX;
      end if;
      if Ball_X + Pixels (Ball_Size) < 0 then
         Right_Score := Right_Score + 1;
         Reset_Ball;
         Update_Title;
      elsif Ball_X >= W_Px then
         Left_Score := Left_Score + 1;
         Reset_Ball;
         Update_Title;
      end if;
   end Update_Ball;

   procedure Render is
      Swatch : constant Extent := Extent (Natural'Min (24,
        Natural'Max (4, 8 * Natural'Min (300, Scale (Win)) / 100)));
   begin
      Clear (Frame.all, (20, 20, 30, 255));
      for I in 0 .. Natural ((H_Px - 1) / 60) loop
         Fill (Frame.all, ((W_Px / 2 - 2, Pixels (I * 60)), (4, 30)),
               (90, 90, 110, 255));
      end loop;
      Fill (Frame.all, ((Left_X, Left_Y), (Paddle_Width, Paddle_Height)),
            (80, 160, 255, 255));
      Fill (Frame.all, ((Right_X, Right_Y), (Paddle_Width, Paddle_Height)),
            (255, 170, 80, 255));
      Fill (Frame.all, ((Ball_X, Ball_Y), (Ball_Size, Ball_Size)),
            (255, 255, 255, 255));
      --  Pure RGB swatches expose channel swaps and demonstrate DPI layout.
      Fill (Frame.all, ((8, 8), (Swatch, Swatch)), (255, 0, 0, 255));
      Fill (Frame.all, ((12 + Pixels (Swatch), 8), (Swatch, Swatch)),
            (0, 255, 0, 255));
      Fill (Frame.all, ((16 + 2 * Pixels (Swatch), 8), (Swatch, Swatch)),
            (0, 0, 255, 255));
      Present (Win, Frame.all);
   end Render;

   procedure Cleanup is
   begin
      Free_Frame (Frame);
      if Is_Initialized then
         Set_Cursor_Visible (True);
         if Win /= No_Window and then Is_Open (Win) then
            Destroy_Window (Win);
         end if;
         Finalize;
      end if;
   end Cleanup;

begin
   Initialize (OK);
   if not OK then
      Put_Line ("Error: Could not initialize backend.");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Create_Window (Title => "Ada Pong", Size => (640, 480),
                  Flags => (Resizable => True, Borderless => False,
                            Hidden => False), Window => Win);
   if Win = No_Window then
      Put_Line ("Error: Could not create window.");
      Cleanup;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;
   Set_Cursor (Win, Current_Shape);
   Set_Cursor_Visible (Cursor_Shown);
   Resize_Frame;
   Put_Line ("W/S: left | I/K: right | M: cycle input mode");
   Put_Line ("C: cursor shape | V: cursor visibility | Wheel: paddle height");
   Put_Line ("Click/Space: pause | F2: resize | R: reset | Esc: quit");
   Last_Report := Natural (Now);

   while Running loop
      declare
         Frame_Start : constant Natural := Natural (Now);
         Elapsed, Current : Natural;
      begin
         for Event_Index in 1 .. 512 loop
            Poll (E);
            exit when E.Kind = None;
            case E.Kind is
               when Quit | Window_Close =>
                  Running := False;
               when Window_Resized =>
                  Resize_Needed := True;
               when Window_Focus_Out =>
                  Paused := True;
                  Update_Title;
               when Key_Down =>
                  if E.Key = Key_Escape then
                     Running := False;
                  elsif not E.Repeat then
                     case E.Key is
                        when Key_M =>
                           if Mode = Control_Mode'Last then
                              Mode := Control_Mode'First;
                           else
                              Mode := Control_Mode'Succ (Mode);
                           end if;
                           Last_DX := 0;
                           Last_DY := 0;
                           Update_Title;
                        when Key_C =>
                           if Current_Shape = Cursor_Shape'Last then
                              Current_Shape := Cursor_Shape'First;
                           else
                              Current_Shape :=
                                Cursor_Shape'Succ (Current_Shape);
                           end if;
                           Set_Cursor (Win, Current_Shape);
                           Update_Title;
                        when Key_V =>
                           Cursor_Shown := not Cursor_Shown;
                           Set_Cursor_Visible (Cursor_Shown);
                           Update_Title;
                        when Key_Space =>
                           Paused := not Paused;
                           Update_Title;
                        when Key_R =>
                           Reset_Game;
                        when Key_F2 =>
                           if Drawable and then W_Px <= 700 then
                              Set_Size (Win, (960, 600));
                           else
                              Set_Size (Win, (640, 480));
                           end if;
                        when others =>
                           null;
                     end case;
                  end if;
               when Mouse_Move =>
                  Last_DX := Integer (E.Delta_X);
                  Last_DY := Integer (E.Delta_Y);
                  Last_X := Integer (E.At_Pos.X);
                  Last_Y := Integer (E.At_Pos.Y);
                  if Drawable and then not Paused then
                     case Mode is
                        when Keyboard =>
                           null;
                        when Absolute_Mouse =>
                           Right_Y := Clamp_Paddle
                             (Last_Y - Integer (Paddle_Height) / 2);
                        when Relative_Mouse =>
                           Right_Y := Clamp_Paddle
                             (Integer (Right_Y) + Last_DY);
                     end case;
                  end if;
               when Mouse_Down =>
                  if E.Button = Left then
                     Paused := not Paused;
                     Update_Title;
                  end if;
               when Mouse_Wheel =>
                  if Drawable and then E.Wheel_Y /= 0 then
                     Paddle_Height := Extent (Integer'Max (32,
                       Integer'Min (Integer'Min (160, Integer (H_Px / 2)),
                         Integer (Paddle_Height)
                         + 8 * Integer (E.Wheel_Y))));
                     Left_Y := Clamp_Paddle (Integer (Left_Y));
                     Right_Y := Clamp_Paddle (Integer (Right_Y));
                  end if;
               when others =>
                  null;
            end case;
            exit when not Running;
         end loop;
         exit when not Running;
         if Resize_Needed then
            Resize_Frame;
            Resize_Needed := False;
         end if;
         if Drawable and then Frame /= null then
            if not Paused then
               Update_Paddles;
               Update_Ball;
            end if;
            Render;
            Frames := Frames + 1;
         end if;
         Current := Natural (Now);
         if Current - Last_Report >= 1_000 then
            FPS := Frames * 1_000 / (Current - Last_Report);
            Frames := 0;
            Last_Report := Current;
            Update_Title;
            if Mode /= Keyboard then
               Put_Line ("Mouse:" & Last_X'Image & "," & Last_Y'Image
                         & " | Delta:" & Last_DX'Image & "," & Last_DY'Image
                         & " | Paddle:" & Paddle_Height'Image);
            end if;
         end if;
         Elapsed := Natural (Now) - Frame_Start;
         if Elapsed < 16 then
            Sleep (16 - Elapsed);
         end if;
      end;
   end loop;
   Put_Line ("Game over!" & Left_Score'Image & " :" & Right_Score'Image);
   Cleanup;
exception
   when others =>
      Cleanup;
      raise;
end Demo;
