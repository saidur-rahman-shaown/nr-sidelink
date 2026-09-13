function nPhys = slotToPhysical(scen, nLog)
%slotToPhysical Logical pool slot to physical slot, ACROSS DFN wraps. Inverse of slotToLogical.
%Spec:   as slotToLogical -- the mapping is clause 8's, the wrap is this layer's.
%Inputs: scen  the scenario, for .physOfLogical and .TmaxPrime
%        nLog  integer, >=0 -- logical pool slot, unbounded and monotone
%Outputs: nPhys  integer -- physical slot
%
%The exact inverse of harness.sls.slotToLogical, and it must stay so: the two are used on
%opposite sides of every deadline computation -- a PDB measured in physical slots turned into a
%selection window in logical ones and back. A mismatch of one DFN period between them is 10.24 s
%of latency error appearing on a fraction of packets, which no aggregate statistic would make
%obvious.

if any(nLog < 0 | mod(nLog, 1) ~= 0)
    error('sls:slotToPhysical:badSlot', 'slotToPhysical: nLog must be a nonnegative integer');
end
nDfn   = numel(scen.logicalOfPhys);
period = floor(nLog / scen.TmaxPrime);
within = mod(nLog, scen.TmaxPrime);
nPhys  = period * nDfn + scen.physOfLogical(within + 1);
end
