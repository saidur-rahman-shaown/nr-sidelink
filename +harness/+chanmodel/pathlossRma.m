function pl = pathlossRma(dMetres, fcHz, losMode, hTxM, hRxM)
%pathlossRma TR 38.901 Rural Macro path loss. Toolbox body: nrPathLoss with Scenario 'RMa'.
%Spec:   3GPP TR 38.901, clause 7.4.1, Table 7.4.1-1 (RMa LOS and NLOS). **There is no local
%        PDF for TR 38.901** -- Documentations/ carries the 38.2xx/38.3xx series only. Rather
%        than transcribe the model's breakpoint formula from recall and let it look
%        authoritative, the body is the 5G Toolbox's own implementation, whose documentation
%        states it implements TR 38.901 Table 7.4.1-1. Same reasoning +cfg/pqiTable.m applies
%        to its TS 23.287 rows, but resolved the other way: there a toolbox function did not
%        exist and the rows had to be recalled and flagged; here one does.
%Inputs: dMetres  real array, >=0 -- 2-D separations. Clamped at the model's 10 m validity
%                 floor; see below
%        fcHz     real, >0 -- carrier frequency
%        losMode  char, 'los' or 'nlos'
%        hTxM     real, >0 -- transmitter height, metres
%        hRxM     real, >0 -- receiver height, metres
%Outputs: pl  real array, dB, same size as dMetres
%
%RMa IS A CELLULAR MODEL AND THIS IS A SIDELINK STUDY
%------------------------------------------------------
%TR 38.901's Rural Macro describes a base station to a UE: its stated validity is roughly
%hBS 10-150 m and hUT 1-10 m. A V2V link is two vehicles at about 1.5 m, which is **outside
%that range on the transmitter side**. The toolbox accepts the geometry and the result is
%well behaved -- path loss at 300 m differs by only 0.5 dB between a 1.5 m and a 35 m
%transmitter, because the LOS branch's height dependence is weak -- but "well behaved" is not
%"validated for this geometry", and the difference between those two is exactly the kind of
%thing that gets lost once a number is in a plot.
%
%The NLOS branch in particular does not survive the transplant. Measured end to end at 50 UEs
%on a 1 km line: RMa LOS gives a link PRR of 0.907 and still 0.94 at 400-600 m, the log-distance
%placeholder gives 0.545 and 0.04, and **RMa NLOS gives 0.060 and exactly 0.00 beyond 50 m** --
%no communication at all past the nearest neighbour. That is not a pessimistic-but-usable
%bracket, it is a model being evaluated far outside the geometry it was fitted for: NLOS RMa at
%a 1.5 m transmitter reaches 175 dB by 1 km. Use `losMode` 'los' here; 'nlos' is retained
%because the mode is part of the model, not because that number means anything for V2V.
%
%**The model 3GPP actually specifies for this study is TR 37.885's V2V Urban and Highway.**
%That document has no local PDF either (+cfg/specVersions.json lists TS37885 among the
%unverified placeholders) and the toolbox does not implement it, which is why it is not here.
%RMa is a real, documented, standards-based model and a large improvement on a hand-rolled
%log-distance curve; it is not the right model. Both things are true and the second is the one
%that gets forgotten.
%
%THE 10 m FLOOR
%--------------
%TR 38.901's RMa expressions start at 10 m. Below that the formula is not defined, and a
%co-located pair would otherwise produce unbounded gain. Distances are clamped rather than
%extrapolated -- the same rule harness.phyabs.blerInterp applies at the edges of its table, and
%for the same reason: a silent extrapolation off the end of a model is indistinguishable from a
%measurement.

if ~any(strcmp(losMode, {'los', 'nlos'}))
    error('chanmodel:pathlossRma:badLosMode', 'pathlossRma: losMode must be ''los'' or ''nlos'', got ''%s''', losMode);
end
if ~(fcHz > 0), error('chanmodel:pathlossRma:badFc', 'pathlossRma: fcHz must be > 0'); end
if ~(hTxM > 0) || ~(hRxM > 0)
    error('chanmodel:pathlossRma:badHeights', 'pathlossRma: heights must be > 0');
end
if any(dMetres(:) < 0)
    error('chanmodel:pathlossRma:negativeDistance', 'pathlossRma: distance cannot be negative');
end

rmaValidityFloorM = 10;
d = max(double(dMetres(:))', rmaValidityFloorM);

cfg = nrPathLossConfig;
cfg.Scenario = 'RMa';

txPos = [0; 0; hTxM];
rxPos = [d; zeros(1, numel(d)); repmat(hRxM, 1, numel(d))];

pl = nrPathLoss(cfg, fcHz, strcmp(losMode, 'los'), txPos, rxPos);
pl = reshape(pl, size(dMetres));
end
