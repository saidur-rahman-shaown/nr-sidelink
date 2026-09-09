function runHarnessTests()
%runHarnessTests Run every +harness/ unit test built so far; error out if anything fails.
%   Same shape as runPhyTests and runHarnessTests' siblings: one runner per package, so a
%   failure names the package. +sap/ is the cross-layer SAP vocabulary and belongs to no
%   single protocol layer, which is why it gets its own runner rather than joining one.

here = fileparts(mfilename('fullpath'));   % .../+test
root = fileparts(here);                    % repo root
addpath(root);

tests = { ...
    @test.unit.harness.test_poolAllSlots, ...
    @test.unit.harness.test_sls};

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
    error('runHarnessTests:failures', '%d test file(s) failed.', nFail);
end
end
