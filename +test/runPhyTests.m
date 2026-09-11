function runPhyTests()
%runPhyTests Run every +phy/ unit test built so far; error out if anything fails.
%   Adds the repo root to the path from this file's own location, then runs
%   each test function and reports a pass/fail summary -- same pattern as
%   nrv2x-matlab/tests/runAllTests.m.

here = fileparts(mfilename('fullpath'));   % .../+test
root = fileparts(here);                    % repo root
addpath(root);

tests = { ...
    @test.unit.phy.lib.test_wrappers, ...
    @test.unit.phy.ts38211.test_syncSignals, ...
    @test.unit.phy.ts38211.test_pscch, ...
    @test.unit.phy.ts38211.test_psbch, ...
    @test.unit.phy.ts38211.test_psfch, ...
    @test.unit.phy.ts38211.test_psschModulation, ...
    @test.unit.phy.ts38211.test_psschMapping, ...
    @test.unit.phy.ts38214.test_procedures, ...
    @test.unit.phy.ts38214.test_poolSlotMap, ...
    @test.unit.phy.ts38215.test_measurements, ...
    @test.unit.phy.rx.policy.test_policy, ...
    @test.unit.phy.chan.test_psbchPsfch};

nFail = 0;
t0 = tic;
for k = 1:numel(tests)
    name = func2str(tests{k});
    try
        tests{k}();
    catch e
        nFail = nFail + 1;
        fprintf(2, 'FAIL %s\n%s\n', name, getReport(e, 'extended', 'hyperlinks', 'off'));
    end
end
fprintf('---\n%d/%d passed in %.1f s\n', numel(tests) - nFail, numel(tests), toc(t0));
if nFail > 0
    error('runPhyTests:failures', '%d test file(s) failed.', nFail);
end
end
