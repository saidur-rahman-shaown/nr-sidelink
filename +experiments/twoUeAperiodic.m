function out = twoUeAperiodic()
%twoUeAperiodic Two UEs, 2000 packets of PQI 56 (PDB 20 ms) at 10 Hz with NO reservation
%(P_rsvp_TX = 0): every packet triggers its own one-shot selection (C_resel = 1) in
%[n + T1, n + PDB - 3 slots], and nothing is announced ahead. Line, box and CDF of the latency.
%   out = experiments.twoUeAperiodic();
%Spec:   none -- an experiment; see experiments.twoUeLatency for the model.
%Figure: plots/experiments/twoUe/twoUe_latency_pqi56_rsvp0_n2000.png
out = experiments.twoUeLatency(struct('pqi', 56, 'periodMs', 100, 'nPackets', 1000, 'prsvpTxMs', 100));
end
