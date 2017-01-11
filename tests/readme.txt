This directory contains code for unit testing MaSIV.
You *do not* need to add this directory to your path. 

To run all the unit tests:

>> runtests;

or 

>> table(runtests)


To run tests in just one file:

>> runtests('yamlReadingTest')


To run a specific test in a specific file:
>> runtests('yamlReadingTest/correctlyReadZeroNumericOnly')


More info:
https://www.mathworks.com/help/matlab/matlab-unit-test-framework.html
https://www.mathworks.com/help/matlab/matlab_prog/types-of-qualifications.html
https://en.wikipedia.org/wiki/Unit_testing
