% File: runAllTests.m
import matlab.unittest.TestSuite
import matlab.unittest.TestRunner
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoverageReport

addpath('TestUtilities')
% Create a test suite for all tests in the Tests directory
suite = TestSuite.fromFolder('.', 'IncludingSubfolders', true);

% Create a test runner that displays detailed test results
runner = TestRunner.withTextOutput;

% Optionally add a code coverage plugin or other plugins
% runner.addPlugin(CodeCoveragePlugin.forFolder('Functions'), 'IncludingSubfolders', true, 'Producing', CoverageReport('coverageReport'));

% Run the suite
results = runner.run(suite);
disp(table(results))