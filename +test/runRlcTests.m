function runRlcTests()
%runRlcTests Run every +rlc/ unit test; error out if anything fails.
%   Same shape as runMacTests. runAllTests calls it.

here = fileparts(mfilename('fullpath'));   % .../+test
root = fileparts(here);                    % repo root
addpath(root);

tests = { ...
    @test.unit.rlc.test_rlcFormats, ...
    @test.unit.rlc.test_rlcRxBuf, ...
    @test.unit.rlc.test_rlcUm, ...
    @test.unit.rlc.test_rlcAm, ...
    @test.unit.rlc.test_rlcWorkedExamples, ...
    @test.unit.rlc.test_rlcGate};

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
    error('runRlcTests:failures', '%d test file(s) failed.', nFail);
end
end
