function pl = pathloss(model, dMetres)
%pathloss Evaluate a path loss model. THE EXIT POINT -- the only path loss call in the tree.
%Spec:   none itself; it dispatches to an implementation that cites its own.
%Inputs: model    scalar struct from harness.chanmodel.pathlossModel
%        dMetres  real array, >=0 -- transmitter-receiver separations
%Outputs: pl  real array, dB, same size as dMetres
%
%Every consumer -- harness.chanmodel.slotSinr, the PSFCH link in harness.sls.slotStep, the
%escalation bound in harness.sls.scenarioInit -- calls this and only this. That is what makes
%the channel model swappable by configuration rather than by edit, and it is why
%harness.sls.scenarioInit stores a model descriptor rather than a pile of loose exponent and
%reference-distance fields.

if ~isstruct(model) || ~isfield(model, 'name')
    error('chanmodel:pathloss:badModel', 'pathloss: model must come from harness.chanmodel.pathlossModel');
end
if any(dMetres(:) < 0)
    error('chanmodel:pathloss:negativeDistance', 'pathloss: distance cannot be negative');
end

C_LIGHT = 299792458;
D_MIN_M = 1;                                  % keep log10 finite for co-located UEs
switch model.name
    case 'rma'
        pl = harness.chanmodel.pathlossRma(dMetres, model.fcHz, model.losMode, model.hTxM, model.hRxM);
    case 'freespace'
        pl = 20 * log10(4 * pi * max(dMetres, D_MIN_M) * model.fcHz / C_LIGHT);
    otherwise
        error('chanmodel:pathloss:unknownModel', 'pathloss: no implementation for ''%s''', model.name);
end
if isfield(model, 'antennaGainDb')
    pl = pl - model.antennaGainDb;            % coupling loss: the antennas' gain comes off
end
end
