function [Tproc0, Tproc1] = procTimeTable(mu)
%procTimeTable Sensing/selection processing times in slots.
%SPEC: TS 38.214 Tables 8.1.4-1 and 8.1.4-2
%   mu = 0..3 (15/30/60/120 kHz).
%   Values transcribed from Documentations/Notes/07-Reconstructed-Tables.md.

t0 = [1 1 2 4];      % Table 8.1.4-1: T_proc,0
t1 = [3 5 9 17];     % Table 8.1.4-2: T_proc,1  (== T1 policy == T3)

assert(mu >= 0 && mu <= 3, 'procTimeTable:mu', 'mu must be 0..3');
Tproc0 = t0(mu + 1);
Tproc1 = t1(mu + 1);
end
