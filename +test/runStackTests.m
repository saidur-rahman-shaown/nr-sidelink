function runStackTests()
%runStackTests Run the upper access-stratum tests: +pdcp/, +sdap/, the +cfg/ bearer lists, +stack/.
%   Same shape as runRlcTests. runAllTests calls it. test_stack runs the whole chain to IQ and back (about 10 s).

here = fileparts(mfilename('fullpath'));   % .../+test
root = fileparts(here);                    % repo root
addpath(root);

tests = { ...
    @test.unit.pdcp.test_pdcp, ...
    @test.unit.sdap.test_sdap, ...
    @test.unit.cfg.test_slrbConfig, ...
    @test.unit.cfg.test_crLimitTable, ...
    @test.unit.stack.test_stack};

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
    error('runStackTests:failures', '%d test file(s) failed.', nFail);
end
end
