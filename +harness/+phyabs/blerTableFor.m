function tbl = blerTableFor(channelModel, speedKmh)
%blerTableFor The measured BLER table for one (channel model, speed) key.
%Spec:   none -- the PHY-abstraction table registry. harness.phyabs.blerTable is the shipped,
%        generated table (TDL-D, 120 km/h). Further tables, measured over the same link-level chain
%        at other speeds (experiments.linkCurves -> experiments.private.exportBlerTable), live as
%        .mat files in +harness/+phyabs/tables/, one per key, each with the same fields as
%        blerTable (.mcs .snrDb .attempt .pssch .pscch .meta).
%Inputs: channelModel  char, e.g. 'tdld';  speedKmh  real >= 0 (compared to 0.1 km/h)
%Outputs: tbl  the table measured at exactly that key
%A key that was never measured RAISES (phyabs:blerLookup:unknownModel / :unknownSpeed) -- reading
%a table off-key is indistinguishable from having measured the right one.
persistent cache
if isempty(cache), cache = containers.Map(); end
key = sprintf('%s_%04d', channelModel, round(10 * speedKmh));
if isKey(cache, key), tbl = cache(key); return; end
shipped = harness.phyabs.blerTable();
if strcmp(shipped.meta.channelModel, channelModel) && round(10 * shipped.meta.speedKmh) == round(10 * speedKmh)
    tbl = shipped;
else
    dirT = fullfile(fileparts(mfilename('fullpath')), 'tables');
    fn = fullfile(dirT, ['blerTable_' key '.mat']);
    if ~isfile(fn)
        have = dir(fullfile(dirT, ['blerTable_' channelModel '_*.mat']));
        if isempty(have) && ~strcmp(shipped.meta.channelModel, channelModel)
            error('phyabs:blerLookup:unknownModel', ['blerLookup: no table was measured over ''%s'' -- measure ' ...
                'a new table rather than reading another one off-key'], channelModel);
        end
        error('phyabs:blerLookup:unknownSpeed', 'blerLookup: no %s table was measured at %g km/h', channelModel, speedKmh);
    end
    x = load(fn, 'tbl');
    tbl = x.tbl;
end
cache(key) = tbl;
end
