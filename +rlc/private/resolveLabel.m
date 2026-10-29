function [value, found] = resolveLabel(label, prefix, values, infinityLabel)
%resolveLabel Map an ASN.1 ENUMERATED label such as 'ms45' or 'p16' to its numeric value.
%Spec:   TS 38.331 V16.22.0, clause 6.3.2 field descriptions for t-PollRetransmit, pollPDU,
%        pollByte, maxRetxThreshold, t-Reassembly, t-StatusProhibit: "Value ms5 means 5 ms,
%        value ms10 means 10 ms and so on" (and likewise p4, kB25, t1).
%Inputs: label          char -- the label as it appears in the ASN.1, e.g. 'ms45'
%        prefix         char -- 'ms', 'p', 'kB', 'mB' or 't'
%        values         1 x n numeric row vector -- the legal values, in ENUMERATED order
%        infinityLabel  char -- the label meaning "infinite" for this enumeration, or '' when
%                       the enumeration has none
%Outputs: value  the numeric value (Inf for infinityLabel); 0 when not found
%         found  logical
%
%Only labels that are actually in the enumeration resolve: 'ms7' is not a T-PollRetransmit
%value even though it parses, and spare values are never legal.

value = 0;
found = false;
if ~ischar(label)
    return;
end
if ~isempty(infinityLabel) && strcmp(label, infinityLabel)
    value = Inf;
    found = true;
    return;
end
for k = 1:numel(values)
    if strcmp(label, sprintf('%s%d', prefix, values(k)))
        value = values(k);
        found = true;
        return;
    end
end
end
