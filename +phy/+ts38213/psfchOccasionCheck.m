function isOccasion = psfchOccasionCheck(k, NPsschPsfch)
%psfchOccasionCheck Whether logical PSSCH slot k has a PSFCH transmission occasion.
%Spec:   TS 38.213 V16.17.0, clause 16.3
%Inputs: k            nonnegative integer -- logical slot index t'_k^SL within the resource
%                     pool (TS 38.214's slot numbering, not resolved here -- caller-supplied)
%        NPsschPsfch  integer, one of {1,2,4} -- N_PSSCH^PSFCH, higher-layer parameter
%                     sl-PSFCH-Period (ASN.1 ENUMERATED{sl0,sl1,sl2,sl4}; sl0=0 means PSFCH
%                     transmissions are disabled entirely -- callers must check that before
%                     calling this function, not pass 0 here)
%Outputs: isOccasion  logical scalar -- true if slot k has a PSFCH transmission occasion
if ~(k >= 0 && mod(k, 1) == 0)
    error('ts38213:psfchOccasionCheck:badK', 'psfchOccasionCheck: k must be a nonnegative integer, got %s', num2str(k));
end
if ~any(NPsschPsfch == [1 2 4])
    error('ts38213:psfchOccasionCheck:badPeriod', 'psfchOccasionCheck: NPsschPsfch must be one of {1,2,4}, got %s', num2str(NPsschPsfch));
end
isOccasion = mod(k, NPsschPsfch) == 0;
end
