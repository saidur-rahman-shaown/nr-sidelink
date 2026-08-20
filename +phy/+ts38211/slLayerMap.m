function x = slLayerMap(d, nu)
%slLayerMap Layer mapping for a single codeword, nu in {1,2}.
%Spec:   TS 38.211 V16.10.0, clause 7.3.1.3 (as applied via clause 8.3.1.3;
%        extracted into Documentations/Notes/13-TS38211-Downlink-Support-
%        Procedures.md -- sidelink PSSCH always has a single codeword, so
%        only the nu=1 and nu=2 single-codeword cases apply, never the
%        two-codeword nu in {5,6,7,8} cases clause 7.3.1.3 also defines)
%Inputs: d   column vector of complex modulation symbols, d(0)..d(Msymb-1).
%            For nu=2, numel(d) must be even (Msymb split evenly across the
%            two layers).
%        nu  integer, 1 or 2 -- number of layers
%Outputs: x  Msymb^layer-by-nu complex matrix, column j is layer j (0-based
%            layer 0 in column 1, ...). nu=1: x = d, pure pass-through.
%            nu=2: x(:,1) = d(1:2:end), x(:,2) = d(2:2:end) -- even/odd
%            demultiplex, i.e. x^(0)(i)=d(2i), x^(1)(i)=d(2i+1), re-indexed
%            from 0, NOT a first-half/second-half split.
d = d(:);
switch nu
    case 1
        x = d;
    case 2
        if mod(numel(d), 2) ~= 0
            error('ts38211:slLayerMap:oddLength', 'slLayerMap: numel(d) must be even for nu=2, got %d', numel(d));
        end
        x = [d(1:2:end), d(2:2:end)];
    otherwise
        error('ts38211:slLayerMap:badNu', 'slLayerMap: nu must be 1 or 2 for sidelink PSSCH, got %s', mat2str(nu));
end
end
