function bler = blerInterp(tbl, field, mcs, sinrDb, txAttempt)
%blerInterp Read a measured BLER table: interpolate in SNR, nearest in MCS, clamp at the edges.
%Spec:   none -- table lookup.
%Inputs: tbl        a table from harness.lls.blerSweep or harness.phyabs.blerTable
%        field      char, 'pssch' or 'pscch'
%        mcs        integer, 0..31 -- I_MCS
%        sinrDb     real array, dB
%        txAttempt  integer, >=1 -- 1 for the initial transmission ('pscch' ignores it)
%Outputs: bler  real array in [0,1], same size as sinrDb
%
%THE RULES ARE STATED, NOT IMPLIED
%----------------------------------
%+harness/CLAUDE.md: "State the interpolation rule and the out-of-range behaviour.
%Extrapolating off the end of a BLER table silently is how an SLS produces confident nonsense."
%So, explicitly:
%
%  * SNR: LINEAR interpolation in dB between measured points, on BLER directly rather than on
%    log(BLER). Linear-in-BLER is the conservative choice through a waterfall: it sits above
%    the true curve in the steep region, so a link is never reported as better than it was
%    measured to be.
%  * SNR out of range: CLAMPED, never extrapolated. Below the lowest measured SNR the answer is
%    the lowest point's BLER (which the sweep grid is chosen to make 1.0); above the highest it
%    is the highest point's. A clamp at a point that has not reached 0 or 1 is a table whose
%    grid was too narrow, and it will show up as a floor in the KPI rather than as an error --
%    which is why blerTable's own test asserts the endpoints are saturated.
%  * MCS: NEAREST measured value, not interpolated. BLER between two MCS levels is not a smooth
%    function of the index -- the modulation order changes in steps, so the curve family is
%    piecewise -- and interpolating across a Qm boundary produces a number that describes no
%    real transmission. Nearest is honest about the table's granularity.
%  * txAttempt: clamped to the measured range. Beyond it, the last measured attempt's BLER,
%    which understates the gain of a fourth-and-later attempt rather than inventing one.
%  * NaN SINR (an unheard link) returns BLER 1.

if ~ismember(field, {'pssch', 'pscch'})
    error('phyabs:blerInterp:badField', 'blerInterp: field must be ''pssch'' or ''pscch'', got ''%s''', field);
end
if ~(txAttempt >= 1 && mod(txAttempt, 1) == 0)
    error('phyabs:blerInterp:badAttempt', 'blerInterp: txAttempt must be a positive integer, got %s', num2str(txAttempt));
end

[~, mIdx] = min(abs(tbl.mcs - mcs));

if strcmp(field, 'pscch')
    curve = tbl.pscch(mIdx, :);
else
    a = min(txAttempt, numel(tbl.attempt));
    curve = squeeze(tbl.pssch(mIdx, :, a))';
end
curve = curve(:)';

sz  = size(sinrDb);
x   = sinrDb(:);
out = zeros(numel(x), 1);

below = x <= tbl.snrDb(1);
above = x >= tbl.snrDb(end);
mid   = ~below & ~above & ~isnan(x);

out(below) = curve(1);
out(above) = curve(end);
if any(mid)
    out(mid) = interp1(tbl.snrDb, curve, x(mid), 'linear');
end
out(isnan(x)) = 1;                 % a link that cannot be heard never decodes

bler = reshape(min(max(out, 0), 1), sz);
end
