function bler = pscchBler(mcs, sinrDb)
%pscchBler PSCCH block error rate, from the measured link-level table.
%Spec:   none -- PHY abstraction.
%Inputs: mcs     integer, 0..31 -- the I_MCS of the PSSCH this PSCCH accompanies. PSCCH itself
%                has no MCS: clause 8.3.2 fixes it at QPSK with a polar code sized by the
%                allocation. It is a key here only because the table measured control and data
%                in the SAME slots, so each PSCCH row is tied to the PSSCH row it shared a
%                channel realisation with
%        sinrDb  real array, dB -- SINR over the PSCCH's own band. NaN where unheard
%Outputs: bler  real array in [0,1]
%
%WHY THIS EXISTS RATHER THAN A LOW-MCS PSSCH LOOKUP
%----------------------------------------------------
%While the BLER curve was a placeholder, the system-level model approximated PSCCH by reading
%the PSSCH curve at a deliberately low effective MCS -- the reasoning being that control is a
%much lower-rate code, which is true, but the size of the advantage was guessed. It is now
%measured: control decodes between 1.75 and 16 dB earlier than data depending on the data's
%MCS, and the spread is the point. A single low-MCS proxy cannot express an advantage that
%grows with the data rate, so at high MCS it understated control's reach badly.
%
%The advantage is large and grows with MCS because PSCCH's code rate does not move with the
%data's: the same ~32-bit payload over the same allocation regardless of what the PSSCH is
%doing. That is exactly why a receiver at range decodes the SCI and loses the transport block,
%which is the case that yields a NACK rather than a DTX.

bler = harness.phyabs.blerInterp(harness.phyabs.blerTable(), 'pscch', mcs, sinrDb, 1);
end
