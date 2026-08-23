function slotIdx = sSsbSlotIndex(Noffset, Ninterval, iSSSB, Nperiod)
%sSsbSlotIndex S-SS/PSBCH block slot index within a 16-frame period.
%Spec:   TS 38.213 V16.17.0, clause 16.1
%Inputs: Noffset    nonnegative integer -- N_offset^S-SSB, slot offset from the start of the
%                   period to the first slot including an S-SS/PSBCH block, higher-layer
%                   parameter sl-TimeOffsetSSB
%        Ninterval  nonnegative integer -- N_interval^S-SSB, slot interval between S-SS/PSBCH
%                   blocks, higher-layer parameter sl-TimeInterval
%        iSSSB      integer, 0..Nperiod-1 -- i_S-SSB, the S-SS/PSBCH block index within the
%                   period
%        Nperiod    positive integer -- N_period^S-SSB, number of S-SS/PSBCH blocks in a
%                   16-frame period, higher-layer parameter sl-NumSSB-WithinPeriod
%Outputs: slotIdx  nonnegative integer -- slot index relative to the first slot of the
%                  16-frame period (index 0 = first slot where (SFN mod 16)==0 or
%                  (DFN mod 16)==0)
if ~(iSSSB >= 0 && iSSSB <= Nperiod - 1 && mod(iSSSB, 1) == 0)
    error('ts38213:sSsbSlotIndex:badISSSB', 'sSsbSlotIndex: iSSSB must be an integer in 0..%d, got %s', Nperiod - 1, num2str(iSSSB));
end
slotIdx = Noffset + (Ninterval + 1) * iSSSB;
end
