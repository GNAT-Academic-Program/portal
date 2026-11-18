with AUnit;
with AUnit.Test_Cases;

--  Base test cases
package Base_Tests is
   --  A subtype of AUnit.Test_Cases.Test_Case is created for each test
   type Base_Test is new AUnit.Test_Cases.Test_Case with null record;

   --  The following proceudre and method must
   --  be implemented for each test case

   --  Registers the test to be run
   overriding procedure Register_Tests (T : in out Base_Test);
   --  Returns the name of the test case, this is used for reporting
   overriding function Name (T : Base_Test) return AUnit.Message_String;

   --  This is the actual test, more can be added here
   procedure Test_Types (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Blend (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Framebuffer (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Events (T : in out AUnit.Test_Cases.Test_Case'Class);
   procedure Test_Backend_Queue (T : in out AUnit.Test_Cases.Test_Case'Class);
end Base_Tests;