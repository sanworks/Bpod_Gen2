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
% disp(table(results))

% Enhanced results display
displayTestResults(results);

function displayTestResults(results)  
    % Display detailed table
    resultTable = table(results);
    disp(resultTable);
    
     % Display summary statistics
    passed = nnz([results.Passed]);
    failed = nnz([results.Failed]);
    incomplete = nnz([results.Incomplete]);
    total = numel(results);
    fprintf('\n=== TEST SUMMARY ===\n');
    fprintf('Total tests:  %d\n', total);
    fprintf('Passed:       %d (%.1f%%)\n', passed, 100*passed/total);
    fprintf('Failed:       %d (%.1f%%)\n', failed, 100*failed/total);
    fprintf('Incomplete:   %d (%.1f%%)\n\n', incomplete, 100*incomplete/total);
    
    fprintf('Total duration: %.2f seconds\n', sum([results.Duration]));

    % Final verdict
    if failed == 0
        fprintf(2, '\nALL TESTS PASSED SUCCESSFULLY!\n');
    else
        fprintf(1, '\nTHERE WERE FAILURES (%d of %d tests failed)\n', failed, total);
    end
end