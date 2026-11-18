# AUnit Tests
## Description
This directory contains a package for building and running an AUnit test suite for Portal.  

## Running
- Run `alr run` to run the tests  

Running the tests will automatically use the latest version of Portal, including modifications.  

## Adding Tests  
There are three main components to the tests: Runner, Suite, and Tests.  
- There is only one runner, it is what executes each of the test suites.
- Suites are series of tests that are related by category or structure.
- Tests are the actual test code  

To add a test to an existing suite, add the Ada source files with the name `*_tests` to the corresponding suite directory. The test must subtype `AUnit.Test_Cases.Test_Case` and override `Register_Tests` and `Name`. `Register_Tests` registers the test functions and procedures, `Name` returns the name of the test.  

To add a test suite, create the corresponding Ada `*_suite` source files in a dedicated directory in `src`. This package should provide a `Suite` function that returns access to a `AUnit.Test_Suites.Test_Suite`, which will refer to tests as described above. This suite will need to be added to `parent_suite.adb`.  