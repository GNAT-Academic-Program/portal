with AUnit.Test_Suites;

--  This is the typical structure of a test suite
--  It contains a function Suite that returns
--  an AUnit.Test_Suites.Access_Test_Suite
package Base_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Base_Suite;