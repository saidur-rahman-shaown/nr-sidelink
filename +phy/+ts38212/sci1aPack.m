function bits = sci1aPack(pool, dynamicParams)
%sci1aPack Pack SCI format 1-A fields into the information bit sequence a0..a(A-1).
%Spec:   TS 38.212 V16.15.0, clause 8.3.1.1
%Inputs: pool  scalar struct, cfg.resourcePool()'s output in full. SCI-1A field widths span
%              sl_NumSubchannel_r16 (top level), sl_MaxNumPerReserve_r16 and
%              sl_ResourceReservePeriodList_r16 (inside sl_UE_SelectedConfigRP_r16),
%              sl_NumReservedBits_r16 (inside sl_PSCCH_Config_r16), the DMRS pattern list and
%              sl_PSFCH_Period_r16 (inside sl_PSSCH_Config_r16 / sl_PSFCH_Config_r16) and
%              sl_Additional_MCS_Table_r16 -- no narrower slice covers all of them.
%        dynamicParams  scalar struct, per-transmission (not pool-static):
%          .priority                 integer, 1..8 -- PPPP priority value (packed as value-1)
%          .friv                     nonnegative integer -- pre-folded via frivEncode
%          .triv                     nonnegative integer -- pre-folded via trivEncode
%          .reservationPeriodIndex   integer, >=0 -- index into
%                                    pool.sl_UE_SelectedConfigRP_r16.sl_ResourceReservePeriodList_r16;
%                                    ignored if sl_MultiReserveResource_r16 is not set
%          .dmrsPatternIndex         integer, >=0 -- index into
%                                    pool.sl_PSSCH_Config_r16.sl_PSSCH_DMRS_TimePatternList_r16
%          .sci2Format               char, 'A' or 'B'
%          .betaOffsetIndex          integer, 0..3 -- index into sl_BetaOffsets2ndSCI_r16
%          .numDmrsPort              integer, 0 or 1 -- Table 8.3.1.1-3
%          .mcs                      integer, 0..31
%          .additionalMcsTableIndex  integer, >=0 -- ignored if that field packs to 0 bits
%          .psfchOverhead            integer, 0 or 1 -- ignored if that field packs to 0 bits
%Outputs: bits  A-by-1 logical column, a0 first
if ~pool.sl_NumSubchannel_r16_Present
    error('ts38212:sci1aPack:missingField', 'sci1aPack: pool.sl_NumSubchannel_r16 must be present');
end
if ~pool.sl_UE_SelectedConfigRP_r16_Present
    error('ts38212:sci1aPack:missingField', 'sci1aPack: pool.sl_UE_SelectedConfigRP_r16 must be present');
end
if ~pool.sl_PSCCH_Config_r16_Present
    error('ts38212:sci1aPack:missingField', 'sci1aPack: pool.sl_PSCCH_Config_r16 must be present');
end
if ~pool.sl_PSSCH_Config_r16_Present
    error('ts38212:sci1aPack:missingField', 'sci1aPack: pool.sl_PSSCH_Config_r16 must be present');
end
if ~pool.sl_PSFCH_Config_r16_Present
    error('ts38212:sci1aPack:missingField', 'sci1aPack: pool.sl_PSFCH_Config_r16 must be present');
end

Nsub       = pool.sl_NumSubchannel_r16;
rp         = pool.sl_UE_SelectedConfigRP_r16;
maxReserve = rp.sl_MaxNumPerReserve_r16;
pscch      = pool.sl_PSCCH_Config_r16;
pssch      = pool.sl_PSSCH_Config_r16;
psfch      = pool.sl_PSFCH_Config_r16;

if dynamicParams.priority < 1 || dynamicParams.priority > 8 || mod(dynamicParams.priority, 1) ~= 0
    error('ts38212:sci1aPack:badPriority', 'sci1aPack: priority must be an integer in 1..8, got %s', num2str(dynamicParams.priority));
end
priorityBits = phy.ts38212.bitsFromUint(dynamicParams.priority - 1, 3);

frivBits = phy.ts38212.bitsFromUint(dynamicParams.friv, phy.ts38212.frivBitWidth(Nsub, maxReserve));
trivBits = phy.ts38212.bitsFromUint(dynamicParams.triv, phy.ts38212.trivBitWidth(maxReserve));

if rp.sl_MultiReserveResource_r16
    nRsv = numel(rp.sl_ResourceReservePeriodList_r16);
    rsvWidth = ceil(log2(nRsv));
    if dynamicParams.reservationPeriodIndex < 0 || dynamicParams.reservationPeriodIndex >= nRsv
        error('ts38212:sci1aPack:badRsvIndex', 'sci1aPack: reservationPeriodIndex must be in 0..%d, got %s', nRsv - 1, num2str(dynamicParams.reservationPeriodIndex));
    end
    rsvBits = phy.ts38212.bitsFromUint(dynamicParams.reservationPeriodIndex, rsvWidth);
else
    rsvBits = phy.ts38212.bitsFromUint(0, 0);
end

nPattern = numel(pssch.sl_PSSCH_DMRS_TimePatternList_r16);
dmrsWidth = ceil(log2(nPattern));
if dynamicParams.dmrsPatternIndex < 0 || dynamicParams.dmrsPatternIndex >= nPattern
    error('ts38212:sci1aPack:badDmrsIndex', 'sci1aPack: dmrsPatternIndex must be in 0..%d, got %s', nPattern - 1, num2str(dynamicParams.dmrsPatternIndex));
end
dmrsBits = phy.ts38212.bitsFromUint(dynamicParams.dmrsPatternIndex, dmrsWidth);

switch dynamicParams.sci2Format
    case 'A'
        sci2FormatBits = phy.ts38212.bitsFromUint(0, 2);
    case 'B'
        sci2FormatBits = phy.ts38212.bitsFromUint(1, 2);
    otherwise
        error('ts38212:sci1aPack:badSci2Format', 'sci1aPack: sci2Format must be ''A'' or ''B'', got ''%s''', dynamicParams.sci2Format);
end

if dynamicParams.betaOffsetIndex < 0 || dynamicParams.betaOffsetIndex > 3 || mod(dynamicParams.betaOffsetIndex, 1) ~= 0
    error('ts38212:sci1aPack:badBetaOffsetIndex', 'sci1aPack: betaOffsetIndex must be an integer in 0..3, got %s', num2str(dynamicParams.betaOffsetIndex));
end
betaOffsetBits = phy.ts38212.bitsFromUint(dynamicParams.betaOffsetIndex, 2);

if ~(dynamicParams.numDmrsPort == 0 || dynamicParams.numDmrsPort == 1)
    error('ts38212:sci1aPack:badNumDmrsPort', 'sci1aPack: numDmrsPort must be 0 or 1, got %s', num2str(dynamicParams.numDmrsPort));
end
numDmrsPortBits = phy.ts38212.bitsFromUint(dynamicParams.numDmrsPort, 1);

if dynamicParams.mcs < 0 || dynamicParams.mcs > 31 || mod(dynamicParams.mcs, 1) ~= 0
    error('ts38212:sci1aPack:badMcs', 'sci1aPack: mcs must be an integer in 0..31, got %s', num2str(dynamicParams.mcs));
end
mcsBits = phy.ts38212.bitsFromUint(dynamicParams.mcs, 5);

addMcsWidth = phy.ts38212.additionalMcsTableWidth(pool.sl_Additional_MCS_Table_r16);
if addMcsWidth > 0
    if dynamicParams.additionalMcsTableIndex < 0 || dynamicParams.additionalMcsTableIndex >= 2^addMcsWidth
        error('ts38212:sci1aPack:badAddMcsIndex', 'sci1aPack: additionalMcsTableIndex must fit in %d bits, got %s', addMcsWidth, num2str(dynamicParams.additionalMcsTableIndex));
    end
    addMcsBits = phy.ts38212.bitsFromUint(dynamicParams.additionalMcsTableIndex, addMcsWidth);
else
    addMcsBits = phy.ts38212.bitsFromUint(0, 0);
end

if psfch.sl_PSFCH_Period_r16 == 2 || psfch.sl_PSFCH_Period_r16 == 4
    if ~(dynamicParams.psfchOverhead == 0 || dynamicParams.psfchOverhead == 1)
        error('ts38212:sci1aPack:badPsfchOverhead', 'sci1aPack: psfchOverhead must be 0 or 1, got %s', num2str(dynamicParams.psfchOverhead));
    end
    psfchBits = phy.ts38212.bitsFromUint(dynamicParams.psfchOverhead, 1);
else
    psfchBits = phy.ts38212.bitsFromUint(0, 0);
end

reservedBits = phy.ts38212.bitsFromUint(0, pscch.sl_NumReservedBits_r16);

bits = [priorityBits; frivBits; trivBits; rsvBits; dmrsBits; sci2FormatBits; betaOffsetBits; ...
        numDmrsPortBits; mcsBits; addMcsBits; psfchBits; reservedBits];
end
