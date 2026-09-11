function runMacTests()
%runMacTests Run every +mac/ unit test built so far; error out if anything fails.
%   Same shape as runPhyTests, kept as a separate entry point because that one
%   documents itself as covering +phy/ specifically. runAllTests calls both.

here = fileparts(mfilename('fullpath'));   % .../+test
root = fileparts(here);                    % repo root
addpath(root);

tests = { ...
    @test.unit.mac.test_macSidelink, ...
    @test.unit.mac.test_macRx};

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
    error('runMacTests:failures', '%d test file(s) failed.', nFail);
end
end
