function [prbStart, prbEnd, MsubchSlot] = psfchPrbRange(i, j, MPrbSet, Nsubch, NPsschPsfch)
%psfchPrbRange PSFCH PRB range allocated to a (PSSCH-slot, sub-channel) pair.
%Spec:   TS 38.213 V16.17.0, clause 16.3
%Inputs: i            integer, 0..NPsschPsfch-1 -- index of a PSSCH slot among the
%                     N_PSSCH^PSFCH slots sharing a PSFCH occasion
%        j            integer, 0..Nsubch-1 -- sub-channel index
%        MPrbSet      positive integer -- M_PRB,set^PSFCH, size of sl-PSFCH-RB-Set; must be a
%                     multiple of Nsubch*NPsschPsfch
%        Nsubch       positive integer -- sl-NumSubchannel
%        NPsschPsfch  integer, one of {1,2,4} -- sl-PSFCH-Period (ASN.1
%                     ENUMERATED{sl0,sl1,sl2,sl4}; sl0 means PSFCH disabled, never passed here)
%Outputs: prbStart    nonnegative integer -- first PRB (0-based, within sl-PSFCH-RB-Set's own
%                     numbering) of the range allocated to (i,j)
%         prbEnd      nonnegative integer -- last PRB of that range
%         MsubchSlot  positive integer -- M_subch,slot^PSFCH = M_PRB,set/(Nsubch*NPsschPsfch),
%                     the width of the range
%
%independent-verifier confirmed this formula, including that j (sub-channel) is the outer,
%coarser-grained index and i (slot) is the inner, fastest-varying one -- a slot-major
%((j+i*NPsschPsfch)*M) reading would be the transposition to watch for; it is not what this
%function computes.
if ~any(NPsschPsfch == [1 2 4])
    error('ts38213:psfchPrbRange:badPeriod', 'psfchPrbRange: NPsschPsfch must be one of {1,2,4}, got %s', num2str(NPsschPsfch));
end
if mod(MPrbSet, Nsubch * NPsschPsfch) ~= 0
    error('ts38213:psfchPrbRange:badMPrbSet', 'psfchPrbRange: MPrbSet must be a multiple of Nsubch*NPsschPsfch (%d*%d), got %d', Nsubch, NPsschPsfch, MPrbSet);
end
if ~(i >= 0 && i <= NPsschPsfch - 1 && mod(i, 1) == 0)
    error('ts38213:psfchPrbRange:badI', 'psfchPrbRange: i must be an integer in 0..%d, got %s', NPsschPsfch - 1, num2str(i));
end
if ~(j >= 0 && j <= Nsubch - 1 && mod(j, 1) == 0)
    error('ts38213:psfchPrbRange:badJ', 'psfchPrbRange: j must be an integer in 0..%d, got %s', Nsubch - 1, num2str(j));
end
MsubchSlot = MPrbSet / (Nsubch * NPsschPsfch);
prbStart = (i + j * NPsschPsfch) * MsubchSlot;
prbEnd = (i + 1 + j * NPsschPsfch) * MsubchSlot - 1;
end
