function tProc1 = procTimeSelection(mu)
%procTimeSelection Selection processing time T_proc,1^SL, in slots.
%Spec:   TS 38.214 V16.17.0, clause 8.1.4, Table 8.1.4-2
%Inputs: mu  integer, 0..3 -- mu_SL, the SCS configuration of the SL BWP
%Outputs: tProc1  positive integer, slots -- T_proc,1^SL; the floor for T1 (0<=T1<=T_proc,1)
%                 and the re-evaluation/pre-emption lead time T3 (owned by +mac/, not here)
table = [3 5 9 17];   % Table 8.1.4-2, indexed by mu=0..3
if ~(mu >= 0 && mu <= 3 && mod(mu, 1) == 0)
    error('ts38214:procTimeSelection:badMu', 'procTimeSelection: mu must be an integer in 0..3, got %s', num2str(mu));
end
tProc1 = table(mu + 1);
end
