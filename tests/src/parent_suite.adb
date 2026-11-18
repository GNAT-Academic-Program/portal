with Base_Suite;

package body Parent_Suite is
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      --  Combine test suites here
      Result.Add_Test (Base_Suite.Suite);
      return Result'Access;
   end Suite;
end Parent_Suite;