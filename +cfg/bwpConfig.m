function s = bwpConfig(raw)
%bwpConfig Build SL-BWP-ConfigCommon-r16 from its JSON-decoded raw struct.
%Spec:   TS 38.331 clause 6.3.5, IE SL-BWP-ConfigCommon-r16 (Release-16 baseline). This is the
%        preconfiguration-path BWP container (reached from SidelinkPreconfigNR-r16 via
%        SL-FreqConfigCommon-r16.sl-BWP-List-r16); the dedicated/unicast-path variant
%        SL-BWP-Config-r16 (with SL-BWP-PoolConfig-r16, add/release lists) is built by
%        rrcReconfigSl.m instead, since it isn't needed until +pc5s/+mac unicast link
%        procedures exist (B8/B9).
%Inputs: raw  scalar struct from jsondecode(), one SL-BWP-ConfigCommon-r16 JSON object
%Outputs: s  scalar struct: sl_BWP_Generic_r16(_Present), sl_BWP_PoolConfigCommon_r16(_Present).
%            Every OPTIONAL field carries a "<field>_Present" logical alongside its value.

[genRaw, s.sl_BWP_Generic_r16_Present] = getOptional(raw, 'sl_BWP_Generic_r16', struct());
if s.sl_BWP_Generic_r16_Present
    s.sl_BWP_Generic_r16 = buildBwpGeneric(genRaw);
else
    s.sl_BWP_Generic_r16 = defaultBwpGeneric();
end

[poolRaw, s.sl_BWP_PoolConfigCommon_r16_Present] = getOptional(raw, 'sl_BWP_PoolConfigCommon_r16', struct());
if s.sl_BWP_PoolConfigCommon_r16_Present
    s.sl_BWP_PoolConfigCommon_r16 = buildPoolConfigCommon(poolRaw);
else
    s.sl_BWP_PoolConfigCommon_r16 = defaultPoolConfigCommon();
end
end

% ======================================================================
% Local builders. Not callable outside this file.
% ======================================================================

function g = buildBwpGeneric(raw)
% SPEC: TS 38.331, SL-BWP-Generic-r16
[bwpRaw, g.sl_BWP_r16_Present] = getOptional(raw, 'sl_BWP_r16', struct());
if g.sl_BWP_r16_Present, g.sl_BWP_r16 = buildBwp(bwpRaw); else, g.sl_BWP_r16 = defaultBwp(); end

[lbl, g.sl_LengthSymbols_r16_Present] = getOptional(raw, 'sl_LengthSymbols_r16', '');
if g.sl_LengthSymbols_r16_Present, g.sl_LengthSymbols_r16 = resolveEnum('sl-LengthSymbols-r16', lbl); else, g.sl_LengthSymbols_r16 = 14; end

[lbl, g.sl_StartSymbol_r16_Present] = getOptional(raw, 'sl_StartSymbol_r16', '');
if g.sl_StartSymbol_r16_Present, g.sl_StartSymbol_r16 = resolveEnum('sl-StartSymbol-r16', lbl); else, g.sl_StartSymbol_r16 = 0; end

if isfield(raw, 'sl_PSBCH_Config_r16')
    node = raw.sl_PSBCH_Config_r16;
    switch node.case
        case 'release'
            g.sl_PSBCH_Config_r16_Present = false; g.sl_PSBCH_Config_r16 = defaultPsbchConfig();
        case 'setup'
            g.sl_PSBCH_Config_r16_Present = true;  g.sl_PSBCH_Config_r16 = buildPsbchConfig(node.setup);
        otherwise
            error('cfg:bwpConfig:badChoice', 'sl-PSBCH-Config-r16: case must be "release" or "setup", got "%s"', node.case);
    end
else
    g.sl_PSBCH_Config_r16_Present = false; g.sl_PSBCH_Config_r16 = defaultPsbchConfig();
end

[g.sl_TxDirectCurrentLocation_r16, g.sl_TxDirectCurrentLocation_r16_Present] = getOptional(raw, 'sl_TxDirectCurrentLocation_r16', 0);   % INTEGER (0..3301)
end
function g = defaultBwpGeneric()
g = buildBwpGeneric(struct());
end

function b = buildBwp(raw)
% SPEC: TS 38.331, generic IE BWP. locationAndBandwidth is the raw RIV-encoded integer;
% decoding it to (offset, length) in PRB is a 38.213 clause 5.1.2.2.2 formula and is
% +phy/+ts38213/'s job, not +cfg/'s -- kept verbatim here.
b.locationAndBandwidth = getMandatory(raw, 'locationAndBandwidth');   % INTEGER (0..37949)
b.subcarrierSpacing    = resolveEnum('subcarrierSpacing', getMandatory(raw, 'subcarrierSpacing'));
[lbl, b.cyclicPrefix_Present] = getOptional(raw, 'cyclicPrefix', '');
if b.cyclicPrefix_Present, b.cyclicPrefix = resolveEnum('cyclicPrefix', lbl); else, b.cyclicPrefix = 'normal'; end
end
function b = defaultBwp()
b = buildBwp(struct('locationAndBandwidth', 0, 'subcarrierSpacing', 'kHz30'));
end

function c = buildPsbchConfig(raw)
% SPEC: TS 38.331, SL-PSBCH-Config-r16
[c.dl_P0_PSBCH_r16, c.dl_P0_PSBCH_r16_Present] = getOptional(raw, 'dl_P0_PSBCH_r16', 0);   % INTEGER (-16..15)
[lbl, c.dl_Alpha_PSBCH_r16_Present] = getOptional(raw, 'dl_Alpha_PSBCH_r16', '');
if c.dl_Alpha_PSBCH_r16_Present, c.dl_Alpha_PSBCH_r16 = resolveEnum('sl-Alpha-r16', lbl); else, c.dl_Alpha_PSBCH_r16 = 1; end
end
function c = defaultPsbchConfig()
c = buildPsbchConfig(struct());
end

function p = buildPoolConfigCommon(raw)
% SPEC: TS 38.331, SL-BWP-PoolConfigCommon-r16
rxItems = getOptList(raw, 'sl_RxPool_r16');
p.sl_RxPool_r16_Present = ~isempty(rxItems);
if p.sl_RxPool_r16_Present
    if numel(rxItems) < 1 || numel(rxItems) > 16   % maxNrofRXPool-r16 == 16
        error('cfg:bwpConfig:badSize', 'sl-RxPool-r16: SIZE(1..16), got %d entries', numel(rxItems));
    end
    rx = repmat(cfg.resourcePool(struct()), 1, numel(rxItems));
    for i = 1:numel(rxItems)
        rx(i) = cfg.resourcePool(rxItems{i});
    end
    p.sl_RxPool_r16 = rx;
else
    p.sl_RxPool_r16 = repmat(cfg.resourcePool(struct()), 1, 0);
end

txItems = getOptList(raw, 'sl_TxPoolSelectedNormal_r16');
p.sl_TxPoolSelectedNormal_r16_Present = ~isempty(txItems);
if p.sl_TxPoolSelectedNormal_r16_Present
    if numel(txItems) < 1 || numel(txItems) > 16   % maxNrofTXPool-r16 == 16
        error('cfg:bwpConfig:badSize', 'sl-TxPoolSelectedNormal-r16: SIZE(1..16), got %d entries', numel(txItems));
    end
    tx = repmat(defaultResourcePoolConfig(), 1, numel(txItems));
    for i = 1:numel(txItems)
        tx(i) = buildResourcePoolConfig(txItems{i});
    end
    p.sl_TxPoolSelectedNormal_r16 = tx;
else
    p.sl_TxPoolSelectedNormal_r16 = repmat(defaultResourcePoolConfig(), 1, 0);
end

[excRaw, p.sl_TxPoolExceptional_r16_Present] = getOptional(raw, 'sl_TxPoolExceptional_r16', struct());
if p.sl_TxPoolExceptional_r16_Present
    p.sl_TxPoolExceptional_r16 = buildResourcePoolConfig(excRaw);
else
    p.sl_TxPoolExceptional_r16 = defaultResourcePoolConfig();
end
end
function p = defaultPoolConfigCommon()
p = buildPoolConfigCommon(struct());
end

function c = buildResourcePoolConfig(raw)
% SPEC: TS 38.331, SL-ResourcePoolConfig-r16
c.sl_ResourcePoolID_r16 = getMandatory(raw, 'sl_ResourcePoolID_r16');   % INTEGER (1..16)
[poolRaw, c.sl_ResourcePool_r16_Present] = getOptional(raw, 'sl_ResourcePool_r16', struct());
if c.sl_ResourcePool_r16_Present, c.sl_ResourcePool_r16 = cfg.resourcePool(poolRaw); else, c.sl_ResourcePool_r16 = cfg.resourcePool(struct()); end
end
function c = defaultResourcePoolConfig()
c = buildResourcePoolConfig(struct('sl_ResourcePoolID_r16', 1));
end
