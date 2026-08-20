function s = rrcReconfigSl(raw)
%rrcReconfigSl Build a unicast per-link sidelink RRC reconfiguration from its JSON-decoded raw
%struct: the dedicated-path pool overrides (SL-BWP-PoolConfig-r16) plus Mode-1 configured
%grants (SL-ConfiguredGrantConfig-r16), keyed by the link they apply to.
%Spec:   TS 38.331 clause 6.3.5, IEs SL-BWP-PoolConfig-r16 and SL-ConfiguredGrantConfig-r16
%        (Release-16 baseline).
%Inputs: raw  scalar struct from jsondecode(), one reconfiguration JSON object: "linkId" plus
%             the two IEs above (see field notes below)
%Outputs: s  scalar struct: linkId, sl_BWP_PoolConfig_r16(_Present),
%            sl_ConfiguredGrantConfigList_r16(_Present)
%
%Deliberately minimal for B0: this is the shape the unicast procedures in +pc5s/ and +mac/
%need once they exist (B8/B9); it may grow once those packages are actually built and their
%real call patterns are known -- see +cfg/CLAUDE.md build-order note and the plan caveat on
%this module.

s.linkId = getMandatory(raw, 'linkId');

[poolRaw, s.sl_BWP_PoolConfig_r16_Present] = getOptional(raw, 'sl_BWP_PoolConfig_r16', struct());
if s.sl_BWP_PoolConfig_r16_Present
    s.sl_BWP_PoolConfig_r16 = buildBwpPoolConfig(poolRaw);
else
    s.sl_BWP_PoolConfig_r16 = defaultBwpPoolConfig();
end

cgItems = getOptList(raw, 'sl_ConfiguredGrantConfigList_r16');
s.sl_ConfiguredGrantConfigList_r16_Present = ~isempty(cgItems);
if s.sl_ConfiguredGrantConfigList_r16_Present
    if numel(cgItems) > 8   % maxNrofCG-SL-1-r16 == 7, indices 0..7 -> up to 8 entries
        error('cfg:rrcReconfigSl:badSize', 'sl-ConfiguredGrantConfigList-r16: up to 8 entries, got %d', numel(cgItems));
    end
    cg = repmat(defaultConfiguredGrantConfig(), 1, numel(cgItems));
    for i = 1:numel(cgItems)
        cg(i) = buildConfiguredGrantConfig(cgItems{i});
    end
    s.sl_ConfiguredGrantConfigList_r16 = cg;
else
    s.sl_ConfiguredGrantConfigList_r16 = repmat(defaultConfiguredGrantConfig(), 1, 0);
end
end

% ======================================================================
% Local builders. Not callable outside this file.
% ======================================================================

function p = buildBwpPoolConfig(raw)
% SPEC: TS 38.331, SL-BWP-PoolConfig-r16 (dedicated/unicast path)
rxItems = getOptList(raw, 'sl_RxPool_r16');
p.sl_RxPool_r16_Present = ~isempty(rxItems);
if p.sl_RxPool_r16_Present
    rx = repmat(cfg.resourcePool(struct()), 1, numel(rxItems));
    for i = 1:numel(rxItems)
        rx(i) = cfg.resourcePool(rxItems{i});
    end
    p.sl_RxPool_r16 = rx;
else
    p.sl_RxPool_r16 = repmat(cfg.resourcePool(struct()), 1, 0);
end

[normRaw, p.sl_TxPoolSelectedNormal_r16_Present] = getOptional(raw, 'sl_TxPoolSelectedNormal_r16', struct());
if p.sl_TxPoolSelectedNormal_r16_Present, p.sl_TxPoolSelectedNormal_r16 = buildTxPoolDedicated(normRaw); else, p.sl_TxPoolSelectedNormal_r16 = defaultTxPoolDedicated(); end

[schedRaw, p.sl_TxPoolScheduling_r16_Present] = getOptional(raw, 'sl_TxPoolScheduling_r16', struct());
if p.sl_TxPoolScheduling_r16_Present, p.sl_TxPoolScheduling_r16 = buildTxPoolDedicated(schedRaw); else, p.sl_TxPoolScheduling_r16 = defaultTxPoolDedicated(); end

[excRaw, p.sl_TxPoolExceptional_r16_Present] = getOptional(raw, 'sl_TxPoolExceptional_r16', struct());
if p.sl_TxPoolExceptional_r16_Present, p.sl_TxPoolExceptional_r16 = buildResourcePoolConfigLocal(excRaw); else, p.sl_TxPoolExceptional_r16 = defaultResourcePoolConfigLocal(); end
end
function p = defaultBwpPoolConfig()
p = buildBwpPoolConfig(struct());
end

function d = buildTxPoolDedicated(raw)
% SPEC: TS 38.331, SL-TxPoolDedicated-r16
[relList, d.sl_PoolToReleaseList_r16_Present] = getOptional(raw, 'sl_PoolToReleaseList_r16', zeros(1, 0));   % SIZE(1..16), SL-ResourcePoolID-r16
d.sl_PoolToReleaseList_r16 = relList(:)';

addItems = getOptList(raw, 'sl_PoolToAddModList_r16');
d.sl_PoolToAddModList_r16_Present = ~isempty(addItems);
if d.sl_PoolToAddModList_r16_Present
    a = repmat(defaultResourcePoolConfigLocal(), 1, numel(addItems));
    for i = 1:numel(addItems)
        a(i) = buildResourcePoolConfigLocal(addItems{i});
    end
    d.sl_PoolToAddModList_r16 = a;
else
    d.sl_PoolToAddModList_r16 = repmat(defaultResourcePoolConfigLocal(), 1, 0);
end
end
function d = defaultTxPoolDedicated()
d = buildTxPoolDedicated(struct());
end

function c = buildResourcePoolConfigLocal(raw)
% SPEC: TS 38.331, SL-ResourcePoolConfig-r16 (duplicated from bwpConfig.m's local copy --
% same rationale as preconfig.m's local TDD-UL-DL-ConfigCommon copy: a small generic IE
% needed in more than one non-exported location).
c.sl_ResourcePoolID_r16 = getMandatory(raw, 'sl_ResourcePoolID_r16');
[poolRaw, c.sl_ResourcePool_r16_Present] = getOptional(raw, 'sl_ResourcePool_r16', struct());
if c.sl_ResourcePool_r16_Present, c.sl_ResourcePool_r16 = cfg.resourcePool(poolRaw); else, c.sl_ResourcePool_r16 = cfg.resourcePool(struct()); end
end
function c = defaultResourcePoolConfigLocal()
c = buildResourcePoolConfigLocal(struct('sl_ResourcePoolID_r16', 1));
end

function g = buildConfiguredGrantConfig(raw)
% SPEC: TS 38.331, SL-ConfiguredGrantConfig-r16
g.sl_ConfigIndexCG_r16 = getMandatory(raw, 'sl_ConfigIndexCG_r16');   % INTEGER (0..7)

if isfield(raw, 'sl_PeriodCG_r16')
    node = raw.sl_PeriodCG_r16;
    caseTag = getMandatory(node, 'case');
    g.sl_PeriodCG_r16_Present = true;
    g.sl_PeriodCG_r16.case = caseTag;
    switch caseTag
        case 'sl-PeriodCG1-r16'
            g.sl_PeriodCG_r16.period_ms = resolveEnum('sl-PeriodCG1-r16', getMandatory(node, 'sl_PeriodCG1_r16'));
        case 'sl-PeriodCG2-r16'
            g.sl_PeriodCG_r16.period_ms = getMandatory(node, 'sl_PeriodCG2_r16');   % INTEGER (1..99)
        otherwise
            error('cfg:rrcReconfigSl:badChoice', 'sl-PeriodCG-r16: unknown case "%s"', caseTag);
    end
else
    g.sl_PeriodCG_r16_Present = false;
    g.sl_PeriodCG_r16 = struct('case', 'sl-PeriodCG1-r16', 'period_ms', 0);
end

[g.sl_NrOfHARQ_Processes_r16, g.sl_NrOfHARQ_Processes_r16_Present] = getOptional(raw, 'sl_NrOfHARQ_Processes_r16', 1);     % INTEGER (1..16)
[g.sl_HARQ_ProcID_offset_r16, g.sl_HARQ_ProcID_offset_r16_Present] = getOptional(raw, 'sl_HARQ_ProcID_offset_r16', 0);     % INTEGER (0..15)

mtItems = getOptList(raw, 'sl_CG_MaxTransNumList_r16');
g.sl_CG_MaxTransNumList_r16_Present = ~isempty(mtItems);
if g.sl_CG_MaxTransNumList_r16_Present
    m = repmat(struct('sl_Priority_r16', 0, 'sl_MaxTransNum_r16', 0), 1, numel(mtItems));
    for i = 1:numel(mtItems)
        m(i).sl_Priority_r16    = getMandatory(mtItems{i}, 'sl_Priority_r16');      % INTEGER (1..8)
        m(i).sl_MaxTransNum_r16 = getMandatory(mtItems{i}, 'sl_MaxTransNum_r16');   % INTEGER (1..32)
    end
    g.sl_CG_MaxTransNumList_r16 = m;
else
    g.sl_CG_MaxTransNumList_r16 = repmat(struct('sl_Priority_r16', 0, 'sl_MaxTransNum_r16', 0), 1, 0);
end

grantRaw = getMandatory(raw, 'rrc_ConfiguredSidelinkGrant_r16');
r = struct();
[r.sl_TimeResourceCG_Type1_r16, r.sl_TimeResourceCG_Type1_r16_Present]       = getOptional(grantRaw, 'sl_TimeResourceCG_Type1_r16', 0);       % INTEGER (0..496)
[r.sl_StartSubchannelCG_Type1_r16, r.sl_StartSubchannelCG_Type1_r16_Present] = getOptional(grantRaw, 'sl_StartSubchannelCG_Type1_r16', 0);    % INTEGER (0..26)
[r.sl_FreqResourceCG_Type1_r16, r.sl_FreqResourceCG_Type1_r16_Present]       = getOptional(grantRaw, 'sl_FreqResourceCG_Type1_r16', 0);       % INTEGER (0..6929)
[r.sl_TimeOffsetCG_Type1_r16, r.sl_TimeOffsetCG_Type1_r16_Present]           = getOptional(grantRaw, 'sl_TimeOffsetCG_Type1_r16', 0);         % INTEGER (0..7999)
[r.sl_N1PUCCH_AN_r16, r.sl_N1PUCCH_AN_r16_Present]                           = getOptional(grantRaw, 'sl_N1PUCCH_AN_r16', 0);                 % PUCCH-ResourceId, INTEGER(0..127)
[r.sl_PSFCH_ToPUCCH_CG_Type1_r16, r.sl_PSFCH_ToPUCCH_CG_Type1_r16_Present]   = getOptional(grantRaw, 'sl_PSFCH_ToPUCCH_CG_Type1_r16', 0);     % INTEGER (0..15)
[r.sl_ResourcePoolID_r16, r.sl_ResourcePoolID_r16_Present]                   = getOptional(grantRaw, 'sl_ResourcePoolID_r16', 1);             % INTEGER (1..16)
r.sl_TimeReferenceSFN_Type1_r16 = getFlag(grantRaw, 'sl_TimeReferenceSFN_Type1_r16', 'sfn512');
g.rrc_ConfiguredSidelinkGrant_r16 = r;
end
function g = defaultConfiguredGrantConfig()
g = buildConfiguredGrantConfig(struct('sl_ConfigIndexCG_r16', 0, 'rrc_ConfiguredSidelinkGrant_r16', struct()));
end
