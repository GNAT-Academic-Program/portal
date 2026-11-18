with AUnit; use AUnit;
with AUnit.Run;
with AUnit.Reporter.Text;
with Ada.Command_Line;

with Parent_Suite;

--  This is the entry point for the tests
--  Since this project builds an executable,
--  think of this like the main() function in C/C++
procedure Test_Runner is
   --  AUnit.Run.Test_Runner is a generic procedure,
   --  this instantiates it with the Unit_Suite.Suite function,
   --  which contains all of the tests to run
   function Runner is new
      AUnit.Run.Test_Runner_With_Status (Parent_Suite.Suite);

   --  This is what the test suite will use for outputting test results
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Result   : AUnit.Status;
begin
   Result := Runner (Reporter);

   --  Set the exit status based on failure
   if Result = AUnit.Failure then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   else
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
   end if;
end Test_Runner;
