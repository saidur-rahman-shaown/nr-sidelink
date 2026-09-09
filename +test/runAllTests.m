function runAllTests()
%runAllTests Run every unit test in the tree; error out if anything fails.
%   The single entry point to reach for. Delegates to the per-package runners so
%   each package keeps its own list, and reports which package failed rather than
%   only that something did.

here = fileparts(mfilename('fullpath'));   % .../+test
root = fileparts(here);                    % repo root
addpath(root);

runners = {@test.runPhyTests, @test.runMacTests, @test.runSapTests, @test.runHarnessTests};

nFail = 0;
t0 = tic;
for k = 1:numel(runners)
    name = func2str(runners{k});
    fprintf('== %s ==\n', name);
    try
        runners{k}();
    catch e
        nFail = nFail + 1;
        fprintf(2, 'FAIL %s: %s\n', name, e.message);
    end
end
fprintf('===\n%d/%d package runner(s) passed in %.1f s\n', numel(runners) - nFail, numel(runners), toc(t0));
if nFail > 0
    error('runAllTests:failures', '%d package runner(s) failed.', nFail);
end
end
