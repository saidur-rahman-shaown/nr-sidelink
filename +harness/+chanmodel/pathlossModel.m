function model = pathlossModel(name, p)
%pathlossModel Build a path loss model descriptor. THE ENTRY POINT for choosing a model.
%Spec:   none itself. Each implementation cites its own source; see the table below.
%Inputs: name  char. Currently one model:
%                'rma' -- TR 38.901 Rural Macro, via harness.chanmodel.pathlossRma
%        p     scalar struct of parameters. Common to every model:
%                .fcHz     real, >0 -- carrier frequency
%              'rma' also takes:
%                .losMode  char, 'los' or 'nlos'
%                .hTxM     real, >0 -- transmitter height, metres
%                .hRxM     real, >0 -- receiver height, metres
%Outputs: model  scalar struct -- pass it to harness.chanmodel.pathloss and nowhere else
%
%THE MODULE BOUNDARY
%-------------------
%Two functions form the whole interface: this one CONSTRUCTS a model and
%harness.chanmodel.pathloss EVALUATES it. Nothing else in the tree calls a path loss
%implementation directly, and no implementation is reachable except through these two. Adding a
%model -- TR 37.885's V2V Urban and Highway are the ones that actually belong in a sidelink
%study -- means adding one implementation file and one case below, and touching no caller.
%
%THE LOG-DISTANCE PLACEHOLDER IS GONE, ON PURPOSE
%--------------------------------------------------
%A hand-rolled `logdistance` model (a free-space anchor plus an exposed exponent) lived here
%while no standards model was available. It was never the default once RMa landed, but it
%remained SELECTABLE -- and a placeholder that can still be chosen is a placeholder that will
%eventually be chosen, most likely by a future scenario copied from an old one. It was removed
%rather than deprecated so that the only path through this function is a 3GPP model.
%
%The dispatcher stays even with one model behind it. Its job is the module boundary, not the
%choice: TR 37.885's V2V Urban and Highway are the models a sidelink study should eventually
%use, and adding one means one implementation file and one case here, with no caller touched.
%
%The descriptor is a plain struct, not an object or a function handle, so a scenario
%serialises and diffs whole. A run that cannot be reproduced from its recorded configuration is
%not a result.

if ~ischar(name)
    error('chanmodel:pathlossModel:badName', 'pathlossModel: name must be a char label');
end
if ~isfield(p, 'fcHz') || ~(p.fcHz > 0)
    error('chanmodel:pathlossModel:badFc', 'pathlossModel: p.fcHz must be present and > 0');
end

model.name = name;
model.fcHz = p.fcHz;

switch name
    case 'rma'
        req = {'losMode', 'hTxM', 'hRxM'};
        for k = 1:numel(req)
            if ~isfield(p, req{k})
                error('chanmodel:pathlossModel:missingParam', 'pathlossModel: ''rma'' needs p.%s', req{k});
            end
        end
        if ~any(strcmp(p.losMode, {'los', 'nlos'}))
            error('chanmodel:pathlossModel:badLosMode', 'pathlossModel: losMode must be ''los'' or ''nlos'', got ''%s''', p.losMode);
        end
        if ~(p.hTxM > 0) || ~(p.hRxM > 0)
            error('chanmodel:pathlossModel:badHeights', 'pathlossModel: hTxM and hRxM must be > 0');
        end
        model.losMode = p.losMode;
        model.hTxM    = p.hTxM;
        model.hRxM    = p.hRxM;

    otherwise
        error('chanmodel:pathlossModel:unknownModel', 'pathlossModel: no model named ''%s''; the only model is ''rma''. The log-distance placeholder was removed deliberately -- see this function''s header', name);
end
end
