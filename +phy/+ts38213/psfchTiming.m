function psfchSlot = psfchTiming(lastPsschSlot, minTimeGap, NPsschPsfch)
%psfchTiming First PSFCH-bearing logical slot at or after sl-MinTimeGapPSFCH following a PSSCH.
%Spec:   TS 38.213 V16.17.0, clause 16.3
%Inputs: lastPsschSlot  nonnegative integer -- logical slot index (TS 38.214 numbering) of the
%                       last slot of the PSSCH reception
%        minTimeGap     positive integer -- higher-layer parameter sl-MinTimeGapPSFCH, minimum
%                       number of resource-pool slots after lastPsschSlot before PSFCH may be
%                       transmitted
%        NPsschPsfch    positive integer -- N_PSSCH^PSFCH, higher-layer parameter
%                       sl-PSFCH-Period
%Outputs: psfchSlot  nonnegative integer -- the first logical slot at or after
%                    lastPsschSlot+minTimeGap that has a PSFCH transmission occasion (per
%                    psfchOccasionCheck) -- "at or after the minimum gap," not the minimum gap
%                    itself
k = lastPsschSlot + minTimeGap;
while ~phy.ts38213.psfchOccasionCheck(k, NPsschPsfch)
    k = k + 1;
end
psfchSlot = k;
end
