function tProc0 = procTimeSensing(mu)
%procTimeSensing Sensing processing time T_proc,0^SL, in slots.
%Spec:   TS 38.214 V16.17.0, clause 8.1.4, Table 8.1.4-1
%Inputs: mu  integer, 0..3 -- mu_SL, the SCS configuration of the SL BWP
%Outputs: tProc0  positive integer, slots -- T_proc,0^SL; feeds the sensing window's exclusive
%                 right edge [n-T0, n-T_proc,0)
table = [1 1 2 4];   % Table 8.1.4-1, indexed by mu=0..3
if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('ts38214:procTimeSensing:badMu', 'procTimeSensing: mu must be an integer in 0..3, got %s', num2str(mu));
end
tProc0 = table(mu + 1);
end
