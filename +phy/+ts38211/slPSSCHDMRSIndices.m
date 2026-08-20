function ind = slPSSCHDMRSIndices(startPRB, NRB, dmrsSymbols)
%slPSSCHDMRSIndices PSSCH DM-RS resource element indices (locations only, shared by both antenna ports).
%Spec:   TS 38.211 V16.10.0, clause 8.4.1.1.2 + Table 8.4.1.1.2-2, applying
%        the generic DM-RS RE-mapping template clause 6.4.1.1.3
%        (Documentations/Notes/12-TS38211-Uplink-Support-Procedures.md):
%        k = 4n + 2k', k' in {0,1}, Delta=0.
%Inputs: startPRB     integer, >=0 -- first common resource block of the
%                     PSSCH assignment
%        NRB          integer, >0 -- number of PRBs assigned to PSSCH
%        dmrsSymbols  row vector of OFDM symbol indices l-bar (relative to
%                     the start of the scheduled PSSCH+PSCCH duration,
%                     including the duplicated first symbol) where DM-RS is
%                     transmitted -- resolved by the caller from Table
%                     8.4.1.1.2-1 given the SCI-signalled DM-RS pattern index;
%                     not derived here (existing interface rule: "psschDmrs
%                     takes the pattern index as an input, never derives it")
%Outputs: ind  (6*NRB*numel(dmrsSymbols))-by-2 integer matrix, columns [k l],
%              k absolute (common-resource-block-0-relative), ascending
%              within each symbol
%
%Both antenna ports p=1000 and p=1001 (Table 8.4.1.1.2-2) share these exact
%locations (CDM group 0, Delta=0 for both) -- they differ only in the w_f(k')
%weight applied at each shared RE, a value, not a location, so one index list
%serves both ports.
if startPRB < 0 || mod(startPRB,1) ~= 0
    error('ts38211:slPSSCHDMRSIndices:badStartPRB', 'slPSSCHDMRSIndices: startPRB must be a nonnegative integer, got %s', mat2str(startPRB));
end
if NRB <= 0 || mod(NRB,1) ~= 0
    error('ts38211:slPSSCHDMRSIndices:badNRB', 'slPSSCHDMRSIndices: NRB must be a positive integer, got %s', mat2str(NRB));
end
if any(dmrsSymbols <= 0) || any(mod(dmrsSymbols,1) ~= 0) || ~issorted(dmrsSymbols, 'strictascend')
    error('ts38211:slPSSCHDMRSIndices:badDmrsSymbols', ...
        'slPSSCHDMRSIndices: dmrsSymbols must be strictly ascending positive integers (never 0), got [%s]', num2str(dmrsSymbols));
end

kPrime = 0:1;
n = (0:3*NRB-1)';
k = 4*n + 2*kPrime;              % (3*NRB)-by-2, columns k'=0 and k'=1
k = sort(k(:)) + startPRB*12;    % (6*NRB)-by-1, ascending, absolute

nSym = numel(dmrsSymbols);
nK = numel(k);
ind = zeros(nK*nSym, 2);
for si = 1:nSym
    rows = (si-1)*nK + (1:nK);
    ind(rows, :) = [k, repmat(dmrsSymbols(si), nK, 1)];
end
end
