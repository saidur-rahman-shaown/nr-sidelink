function [prb, csPairIndex] = psfchResource(prbBase, MsubchSlot, Ntype, NCS, PID, MID)
%psfchResource PSFCH PRB and cyclic-shift-pair index for a PSSCH reception.
%Spec:   TS 38.213 V16.17.0, clause 16.3
%
%Scope limitation: this function handles sl-PSFCH-CandidateResourceType='startSubCH'
%(Ntype=1) exactly as specified -- prbBase is then simply psfchPrbRange's prbStart for the
%PSSCH's single starting sub-channel. For 'allocSubCH' (Ntype=Nsubch^PSSCH>1), the clause
%states the N_type*M_subch,slot indexable PRBs "are associated with the N_subch^PSSCH
%sub-channels of the corresponding PSSCH" -- but psfchPrbRange's own formula places different
%sub-channels' ranges N_PSSCH^PSFCH*M_subch,slot PRBs apart, not contiguously, so how those
%per-sub-channel ranges concatenate into one ascending-PRB-index sequence for the resourceIndex
%decomposition below is not fully worked out here. Flagged rather than guessed at -- do not
%trust this function for 'allocSubCH' without an independent-verifier pass on that specific
%point first; 'startSubCH' is unambiguous and safe to use now.
%
%Inputs: prbBase     nonnegative integer -- the PRB index the N_type*M_subch,slot indexable
%                    range starts at. For startSubCH: psfchPrbRange(i, jStart, ...)'s prbStart.
%                    This indexes into sl-PSFCH-RB-Set's own PRB numbering (the k-th set bit
%                    of that BIT STRING), not a carrier-absolute PRB -- mapping that bitmap to
%                    absolute PRBs is the caller's job, not this function's.
%        MsubchSlot  positive integer -- M_subch,slot^PSFCH, from psfchPrbRange
%        Ntype       integer, 1 for startSubCH (only value this function is verified for)
%        NCS         integer, one of {1,2,3,6} -- N_CS^PSFCH, sl-NumMuxCS-Pair (Table 16.3-1
%                    defines m0 only for these four values)
%        PID         integer, 0..255 -- P_ID, the physical layer source ID (SCI-2's sourceID
%                    field)
%        MID         nonnegative integer -- M_ID, the receiving UE's identity if Cast type
%                    indicator is "01" (groupcast with per-UE ACK/NACK), else 0
%Outputs: prb          nonnegative integer -- the allocated PRB, in sl-PSFCH-RB-Set's own PRB
%                      numbering (see prbBase above)
%         csPairIndex  integer, 0..NCS-1 -- the cyclic-shift pair index; feeds
%                      psfchCyclicShiftM0
%
%independent-verifier caught a real bug here: the PRB offset and cyclic-shift-pair index were
%originally swapped, AND divided by NCS instead of the PRB count (Ntype*MsubchSlot). The
%nominal test case happened to have NCS==Ntype*MsubchSlot (3==3), which made both readings
%agree by coincidence -- masking the bug completely until a case with NCS != the PRB count
%broke the tie. Per clause 16.3, "resources are first indexed... by ascending order of the PRB
%index... and then by ascending order of the cyclic shift pair index" -- PRB is the
%fastest-varying (inner) dimension, matching the identical "first i, then j" phrasing already
%confirmed for psfchPrbRange. So: prbOffset = resourceIndex mod N_PRB, csPairIndex =
%floor(resourceIndex / N_PRB), where N_PRB = Ntype*MsubchSlot -- not the other way around, and
%not divided by NCS.
if Ntype ~= 1
    error('ts38213:psfchResource:allocSubCHNotSupported', 'psfchResource: Ntype~=1 (allocSubCH) is not yet verified -- see this file''s header');
end
if ~any(NCS == [1 2 3 6])
    error('ts38213:psfchResource:badNCS', 'psfchResource: NCS must be one of {1,2,3,6}, got %s', num2str(NCS));
end
NPRB = Ntype * MsubchSlot;
RPrbCs = NPRB * NCS;
resourceIndex = mod(PID + MID, RPrbCs);
prbOffset = mod(resourceIndex, NPRB);
csPairIndex = floor(resourceIndex / NPRB);
prb = prbBase + prbOffset;
end
