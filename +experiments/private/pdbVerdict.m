function v = pdbVerdict(onTime, pqi, label)
%pdbVerdict Does a flow meet its PC5 QoS: the PDB, at the PQI's packet error rate?
%Spec:   TS 23.287 clause 5.4.4: the PDB and the Packet Error Rate are a PAIR -- a packet
%        delivered after the PDB counts as lost against the PER. So the test is one number:
%        the fraction delivered within the PDB must be at least 1 - PER. Values from
%        cfg.pqiTable (Table 5.4.4-1).
%Inputs: onTime  logical vector -- per packet (or per packet-receiver pair), delivered by its PDB
%        pqi     integer -- the flow's PQI
%        label   char -- for the printout
%Outputs: v  struct: .label .pqi .pdbMs .per .target .achieved .n .pass .margin (achieved -
%            target) .verdict ('PASS' | 'FAIL' | 'n/a') .ci95 (Wilson interval on achieved)
%
%The Wilson interval is reported because the targets go down to 1e-5 and a run of a few thousand
%packets cannot demonstrate those: a PASS on fewer than about 3/PER samples is printed as
%'PASS*' (consistent with the target, not proven by the sample).
row = cfg.pqiLookup(cfg.pqiTable(), pqi);
v.label = label; v.pqi = pqi; v.pdbMs = row.PDB_ms; v.per = row.PER;
v.target = 1 - row.PER;
v.n = numel(onTime);
if v.n == 0
    v.achieved = NaN; v.pass = false; v.margin = NaN; v.verdict = 'n/a'; v.ci95 = [NaN NaN];
    return;
end
p = mean(onTime);
v.achieved = p;
z = 1.96;
den = 1 + z^2 / v.n;
c = (p + z^2 / (2 * v.n)) / den;
h = z * sqrt(p * (1 - p) / v.n + z^2 / (4 * v.n^2)) / den;
v.ci95 = [c - h, c + h];
v.pass = p >= v.target;
v.margin = p - v.target;
if v.pass && v.n < 3 / row.PER
    v.verdict = 'PASS*';
elseif v.pass
    v.verdict = 'PASS';
else
    v.verdict = 'FAIL';
end
end
