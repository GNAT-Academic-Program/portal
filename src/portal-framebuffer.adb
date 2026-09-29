package body Portal.Framebuffer with SPARK_Mode is

   ---------
   -- Put --
   ---------

   procedure Put (B : in out Buffer; P : Point; C : Color) is
   begin
      B.Pixels (Row (P.Y), Column (P.X)) := C;
   end Put;

   -----------
   -- Blend --
   -----------

   function Blend (Src, Dst : Color) return Color is
      --  out = src * a + dst * (1 - a), a in 0 .. 255. Integer math,
      --  rounded, division exact enough for 8 bits. All intermediate
      --  values fit in 17 bits.
      A  : constant Natural := Natural (Src.A);
      NA : constant Natural := 255 - A;

      function Mix (S, D : Channel) return Channel is
        (Channel ((Natural (S) * A + Natural (D) * NA + 127) / 255));
   begin
      if A = 255 then
         return Src;
      elsif A = 0 then
         return Dst;
      else
         return (R => Mix (Src.R, Dst.R),
                 G => Mix (Src.G, Dst.G),
                 B => Mix (Src.B, Dst.B),
                 A => Channel (Natural'Min (255, A + Natural (Dst.A) * NA / 255)));
      end if;
   end Blend;

   -----------
   -- Clear --
   -----------

   procedure Clear (B : in out Buffer; C : Color) is
   begin
      for Y in 0 .. B.Height loop
         pragma Loop_Invariant
           (for all YY in 0 .. Y - 1 =>
              (for all X in 0 .. B.Width => B.Pixels (YY, X) = C));
         for X in 0 .. B.Width loop
            pragma Loop_Invariant
              (for all YY in 0 .. Y - 1 =>
                 (for all XX in 0 .. B.Width => B.Pixels (YY, XX) = C));
            pragma Loop_Invariant
              (for all XX in 0 .. X - 1 => B.Pixels (Y, XX) = C);
            B.Pixels (Y, X) := C;
         end loop;
      end loop;
   end Clear;

   ----------
   -- Clip --
   ----------

   procedure Clip
     (B      : Buffer;
      R      : Rect;
      X0, Y0 : out Extent;
      X1, Y1 : out Extent;
      Empty  : out Boolean)
   is
      --  Far edges, exclusive, in a range that cannot overflow
      --  (Pixels is 16 bit, the sum fits in Integer).
      Right  : constant Integer := Integer (R.Origin.X) + Integer (R.Extent.Width);
      Bottom : constant Integer := Integer (R.Origin.Y) + Integer (R.Extent.Height);
      Left   : constant Integer := Integer'Max (0, Integer (R.Origin.X));
      Top    : constant Integer := Integer'Max (0, Integer (R.Origin.Y));
      RightC : constant Integer := Integer'Min (Integer (B.Width) + 1, Right);
      BotC   : constant Integer := Integer'Min (Integer (B.Height) + 1, Bottom);
   begin
      if Left >= RightC or else Top >= BotC then
         X0 := 0; Y0 := 0; X1 := 0; Y1 := 0;
         Empty := True;
      else
         X0 := Extent (Left);
         Y0 := Extent (Top);
         X1 := Extent (RightC - 1);
         Y1 := Extent (BotC - 1);
         Empty := False;
      end if;
   end Clip;

   ----------
   -- Fill --
   ----------

   procedure Fill (B : in out Buffer; R : Rect; C : Color) is
      X0, Y0, X1, Y1 : Extent;
      Empty : Boolean;
      Opaque : constant Color := (C.R, C.G, C.B, 255);
   begin
      Clip (B, R, X0, Y0, X1, Y1, Empty);
      if Empty then
         return;
      end if;
      for Y in Row range Row (Y0) .. Row (Y1) loop
         pragma Loop_Invariant (B.Width = B.Width'Loop_Entry);
         pragma Loop_Invariant (B.Height = B.Height'Loop_Entry);
         for X in Column range Column (X0) .. Column (X1) loop
            pragma Loop_Invariant (B.Width = B.Width'Loop_Entry);
            pragma Loop_Invariant (B.Height = B.Height'Loop_Entry);
            B.Pixels (Y, X) := Opaque;
         end loop;
      end loop;
   end Fill;

   ----------------
   -- Fill_Blend --
   ----------------

   procedure Fill_Blend (B : in out Buffer; R : Rect; C : Color) is
      X0, Y0, X1, Y1 : Extent;
      Empty : Boolean;
   begin
      Clip (B, R, X0, Y0, X1, Y1, Empty);
      if Empty then
         return;
      end if;
      for Y in Row range Row (Y0) .. Row (Y1) loop
         pragma Loop_Invariant (B.Width = B.Width'Loop_Entry);
         pragma Loop_Invariant (B.Height = B.Height'Loop_Entry);
         for X in Column range Column (X0) .. Column (X1) loop
            pragma Loop_Invariant (B.Width = B.Width'Loop_Entry);
            pragma Loop_Invariant (B.Height = B.Height'Loop_Entry);
            B.Pixels (Y, X) := Blend (C, B.Pixels (Y, X));
         end loop;
      end loop;
   end Fill_Blend;

   ----------
   -- Blit --
   ----------

   procedure Blit
     (Dst    : in out Buffer;
      Src    : Buffer;
      At_Pos : Point)
   is
      X0, Y0, X1, Y1 : Extent;
      Empty : Boolean;
   begin
      Clip (Dst,
            (Origin => At_Pos, Extent => (Width (Src), Height (Src))),
            X0, Y0, X1, Y1, Empty);
      if Empty then
         return;
      end if;
      for Y in Row range Row (Y0) .. Row (Y1) loop
         pragma Loop_Invariant (Dst.Width = Dst.Width'Loop_Entry);
         pragma Loop_Invariant (Dst.Height = Dst.Height'Loop_Entry);
         for X in Column range Column (X0) .. Column (X1) loop
            pragma Loop_Invariant (Dst.Width = Dst.Width'Loop_Entry);
            pragma Loop_Invariant (Dst.Height = Dst.Height'Loop_Entry);
            declare
               --  Clip guarantees X0 >= At_Pos.X and X1 < At_Pos.X + Width (Src),
               --  so these source indices are in range.
               SX : constant Column := Column (Integer (X) - Integer (At_Pos.X));
               SY : constant Row    := Row (Integer (Y) - Integer (At_Pos.Y));
            begin
               Dst.Pixels (Y, X) := Blend (Src.Pixels (SY, SX), Dst.Pixels (Y, X));
            end;
         end loop;
      end loop;
   end Blit;

end Portal.Framebuffer;
