
with Ada.Text_IO;        use Ada.Text_IO;
with Bedrock.Screen;     use Bedrock.Screen;
with Portal;
with Portal.Backend;     use Portal.Backend;
with Portal.Framebuffer; use Portal.Framebuffer;
with Portal.Input;       use Portal.Input;

procedure Demo is

   ------------------------------------------------------------------
   --  Window and framebuffer
   ------------------------------------------------------------------

   W_Px : constant := 640;
   H_Px : constant := 480;

   Frame : Buffer (H_Px - 1, W_Px - 1);
   Win   : Window_Id;
   OK    : Boolean;
   E     : Event;

   Running : Boolean := True;

   ------------------------------------------------------------------
   --  Game configuration
   ------------------------------------------------------------------

   Paddle_Width  : constant Extent := 12;
   Paddle_Height : constant Extent := 80;
   Paddle_Speed  : constant Pixels := 5;

   Ball_Size  : constant Extent := 12;
   Ball_Speed : constant Pixels := 4;

   Left_X  : constant Pixels := 20;
   Right_X : constant Pixels := W_Px - 32;

   ------------------------------------------------------------------
   --  Game state
   ------------------------------------------------------------------

   Left_Y  : Pixels := 200;
   Right_Y : Pixels := 200;

   Ball_X  : Pixels := 314;
   Ball_Y  : Pixels := 234;
   Ball_DX : Pixels := Ball_Speed;
   Ball_DY : Pixels := 3;

   Left_Score  : Natural := 0;
   Right_Score : Natural := 0;

   ------------------------------------------------------------------
   --  Update the score in the window title
   ------------------------------------------------------------------

   procedure Update_Title is
   begin
      Set_Title
        (Win,
         "Ada Pong | Player 1:" & Left_Score'Image
         & " | Player 2:" & Right_Score'Image);
   end Update_Title;

   ------------------------------------------------------------------
   --  Reset ball to the middle
   ------------------------------------------------------------------

   procedure Reset_Ball is
   begin
      Ball_X := W_Px / 2 - Pixels (Ball_Size) / 2;
      Ball_Y := H_Px / 2 - Pixels (Ball_Size) / 2;

      --  Reverse horizontal direction after each point
      Ball_DX := -Ball_DX;
      Ball_DY := 3;
   end Reset_Ball;

   ------------------------------------------------------------------
   --  Move paddles according to keyboard state
   ------------------------------------------------------------------

   procedure Update_Paddles is
   begin

      --  Player 1: W and S
      if Is_Key_Down (Key_W) then
         Left_Y := Left_Y - Paddle_Speed;
      end if;

      if Is_Key_Down (Key_S) then
         Left_Y := Left_Y + Paddle_Speed;
      end if;

      --  Player 2: I and K
      if Is_Key_Down (Key_I) then
         Right_Y := Right_Y - Paddle_Speed;
      end if;

      if Is_Key_Down (Key_K) then
         Right_Y := Right_Y + Paddle_Speed;
      end if;

      --  Keep the paddles inside the window
      if Left_Y < 0 then
         Left_Y := 0;
      elsif Left_Y + Pixels (Paddle_Height) > H_Px then
         Left_Y := H_Px - Pixels (Paddle_Height);
      end if;

      if Right_Y < 0 then
         Right_Y := 0;
      elsif Right_Y + Pixels (Paddle_Height) > H_Px then
         Right_Y := H_Px - Pixels (Paddle_Height);
      end if;

   end Update_Paddles;

   ------------------------------------------------------------------
   --  Ball movement, collisions, and scoring
   ------------------------------------------------------------------

   procedure Update_Ball is
   begin

      --  Move the ball
      Ball_X := Ball_X + Ball_DX;
      Ball_Y := Ball_Y + Ball_DY;

      --  Collision with top wall
      if Ball_Y <= 0 then
         Ball_Y := 0;
         Ball_DY := abs Ball_DY;
      end if;

      --  Collision with bottom wall
      if Ball_Y + Pixels (Ball_Size) >= H_Px then
         Ball_Y := H_Px - Pixels (Ball_Size);
         Ball_DY := -abs Ball_DY;
      end if;

      --  Collision with left paddle
      if Ball_DX < 0
        and then Ball_X <= Left_X + Pixels (Paddle_Width)
        and then Ball_X + Pixels (Ball_Size) >= Left_X
        and then Ball_Y + Pixels (Ball_Size) > Left_Y
        and then Ball_Y < Left_Y + Pixels (Paddle_Height)
      then
         Ball_X := Left_X + Pixels (Paddle_Width);
         Ball_DX := abs Ball_DX;
      end if;

      --  Collision with right paddle
      if Ball_DX > 0
        and then Ball_X + Pixels (Ball_Size) >= Right_X
        and then Ball_X <= Right_X + Pixels (Paddle_Width)
        and then Ball_Y + Pixels (Ball_Size) > Right_Y
        and then Ball_Y < Right_Y + Pixels (Paddle_Height)
      then
         Ball_X := Right_X - Pixels (Ball_Size);
         Ball_DX := -abs Ball_DX;
      end if;

      --  Player 2 scores
      if Ball_X + Pixels (Ball_Size) < 0 then

         Right_Score := Right_Score + 1;
         Put_Line ("Player 2 scores!");
         Update_Title;
         Reset_Ball;

      --  Player 1 scores
      elsif Ball_X >= W_Px then

         Left_Score := Left_Score + 1;
         Put_Line ("Player 1 scores!");
         Update_Title;
         Reset_Ball;

      end if;

   end Update_Ball;

   ------------------------------------------------------------------
   --  Render the entire game
   ------------------------------------------------------------------

   procedure Render is
   begin

      --  Dark background
      Clear (Frame, (20, 20, 30, 255));

      --  Dashed center line
      for I in 0 .. 7 loop
         Fill
            (Frame,
               ((W_Px / 2 - 2, Pixels (I * 60)), (4, 30)),
               (90, 90, 110, 255));
      end loop;

      --  Left paddle (blue)
      Fill
        (Frame,
         ((Left_X, Left_Y), (Paddle_Width, Paddle_Height)),
         (80, 160, 255, 255));

      --  Right paddle (orange)
      Fill
        (Frame,
         ((Right_X, Right_Y), (Paddle_Width, Paddle_Height)),
         (255, 170, 80, 255));

      --  Ball (white)
      Fill
        (Frame,
         ((Ball_X, Ball_Y), (Ball_Size, Ball_Size)),
         (255, 255, 255, 255));

      --  Display framebuffer
      Present (Win, Frame);

   end Render;

   ------------------------------------------------------------------
   --  Main application
   ------------------------------------------------------------------

begin

   Put_Line ("Starting Ada Pong...");

   --  Initialize the platform backend
   Initialize (OK);

   if not OK then
      Put_Line ("Error: Could not initialize display.");
      return;
   end if;

   --  Create the Pong window
   Create_Window
     (Title  => "Ada Pong",
      Size   => (W_Px, H_Px),
      Flags  => (Resizable  => False,
                 Borderless => False,
                 Hidden     => False),
      Window => Win);

   if Win = No_Window then
      Put_Line ("Error: Could not create window.");
      Finalize;
      return;
   end if;

   Put_Line ("Window created successfully!");
   Put_Line ("Player 1: W / S");
   Put_Line ("Player 2: I / K");
   Put_Line ("Escape: Quit");

   Update_Title;

   ------------------------------------------------------------------
   --  Game loop
   ------------------------------------------------------------------

   while Running loop

      loop
         Poll (E);
         exit when E.Kind = None;

         case E.Kind is

            when Quit | Window_Close =>
               Running := False;

            when Key_Down =>
               if E.Key = Key_Escape then
                  Running := False;
               end if;

            when others =>
               null;

         end case;

      end loop;

      exit when not Running;

      --  Update game state
      Update_Paddles;
      Update_Ball;

      --  Draw the game
      Render;

      Sleep (16);

   end loop;

   ------------------------------------------------------------------
   --  Cleanup
   ------------------------------------------------------------------

   Put_Line ("Game over!");
   Put_Line ("Player 1:" & Left_Score'Image);
   Put_Line ("Player 2:" & Right_Score'Image);

   Destroy_Window (Win);
   Finalize;

end Demo;
