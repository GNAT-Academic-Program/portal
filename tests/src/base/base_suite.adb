with AUnit.Test_Cases;
with Base_Tests;

--  This is the body of a test suite
package body Base_Suite is

   --  The result is resturned by pointer so it must be aliased
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      --  Tests get added to the test suite here,
      --  this is how you would add your own tests
      Result.Add_Test
         (AUnit.Test_Cases.Test_Case_Access'(new Base_Tests.Base_Test));

      --  Return a pointer to the test suite
      --  so it can be used by the test runner
      return Result'Access;
   end Suite;

end Base_Suite;
