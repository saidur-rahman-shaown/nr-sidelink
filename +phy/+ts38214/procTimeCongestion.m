function N = procTimeCongestion(mu, capability)
%procTimeCongestion Congestion control processing time N, in slots.
%Spec:   TS 38.214 V16.17.0, clause 8.1.6, Table 8.1.6-1 (UE processing timing capability 1)
%        and Table 8.1.6-2 (UE processing timing capability 2)
%Inputs: mu          integer, 0..3 -- clause 8.1.6's own wording: "mu corresponds to the
%                    subcarrier spacing of the sidelink channel with which the PSSCH is to be
%                    transmitted". For a single SL BWP this is the same mu_SL that
%                    candidateSet/procTimeSensing take.
%        capability  integer, 1 or 2 -- the UE processing timing capability selecting Table
%                    8.1.6-1 vs Table 8.1.6-2. Clause 8.1.6: "A UE shall only apply a single
%                    processing time capability in sidelink congestion control" -- so this is a
%                    fixed per-UE property, not a per-call or per-transmission choice, and a
%                    caller that varies it between calls for one UE is violating the clause.
%Outputs: N  positive integer, slots -- the congestion control processing time. Both quantities
%            clause 8.1.6's limit is evaluated on -- CR(i), and the CBR that selects
%            CR_limit(k) -- are measured in slot n-N when the PSSCH is transmitted in slot n.
%            Note this is a LOOKBACK offset, unlike T_proc,0/T_proc,1 which bound windows.
tableCapability1 = [2 2 4 8];    % Table 8.1.6-1, indexed by mu=0..3
tableCapability2 = [2 4 8 16];   % Table 8.1.6-2, indexed by mu=0..3
if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('ts38214:procTimeCongestion:badMu', 'procTimeCongestion: mu must be an integer in 0..3, got %s', num2str(mu));
end
if ~any(capability == [1 2])
    error('ts38214:procTimeCongestion:badCapability', 'procTimeCongestion: capability must be 1 or 2 (UE processing timing capability, Table 8.1.6-1/-2), got %s', num2str(capability));
end
if capability == 1
    N = tableCapability1(mu + 1);
else
    N = tableCapability2(mu + 1);
end
end
