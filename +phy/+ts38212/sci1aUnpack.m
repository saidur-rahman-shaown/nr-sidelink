function dynamicParams = sci1aUnpack(bits, pool)
%sci1aUnpack Unpack SCI format 1-A information bits a0..a(A-1) into named fields.
%Spec:   TS 38.212 V16.15.0, clause 8.3.1.1 (inverse of sci1aPack)
%Inputs: bits  column vector (logical or 0/1), the full A-bit SCI-1A payload
%        pool  scalar struct, cfg.resourcePool()'s output in full -- see sci1aPack's header
%              for exactly which sub-IEs this reads
%Outputs: dynamicParams  scalar struct with the same fields sci1aPack takes, recovered from
%              bits (see sci1aPack's header for each field's type/range)
if ~pool.sl_NumSubchannel_r16_Present
    error('ts38212:sci1aUnpack:missingField', 'sci1aUnpack: pool.sl_NumSubchannel_r16 must be present');
end
if ~pool.sl_UE_SelectedConfigRP_r16_Present
    error('ts38212:sci1aUnpack:missingField', 'sci1aUnpack: pool.sl_UE_SelectedConfigRP_r16 must be present');
end
if ~pool.sl_PSCCH_Config_r16_Present
    error('ts38212:sci1aUnpack:missingField', 'sci1aUnpack: pool.sl_PSCCH_Config_r16 must be present');
end
if ~pool.sl_PSSCH_Config_r16_Present
    error('ts38212:sci1aUnpack:missingField', 'sci1aUnpack: pool.sl_PSSCH_Config_r16 must be present');
end
if ~pool.sl_PSFCH_Config_r16_Present
    error('ts38212:sci1aUnpack:missingField', 'sci1aUnpack: pool.sl_PSFCH_Config_r16 must be present');
end

Nsub       = pool.sl_NumSubchannel_r16;
rp         = pool.sl_UE_SelectedConfigRP_r16;
maxReserve = rp.sl_MaxNumPerReserve_r16;
pscch      = pool.sl_PSCCH_Config_r16;
pssch      = pool.sl_PSSCH_Config_r16;
psfch      = pool.sl_PSFCH_Config_r16;

bits = logical(bits(:));
idx = 1;
[priorityRaw, idx] = phy.ts38212.takeField(bits, idx, 3);
dynamicParams.priority = double(phy.ts38212.uintFromBits(priorityRaw)) + 1;

[frivRaw, idx] = phy.ts38212.takeField(bits, idx, phy.ts38212.frivBitWidth(Nsub, maxReserve));
dynamicParams.friv = phy.ts38212.uintFromBits(frivRaw);

[trivRaw, idx] = phy.ts38212.takeField(bits, idx, phy.ts38212.trivBitWidth(maxReserve));
dynamicParams.triv = phy.ts38212.uintFromBits(trivRaw);

if rp.sl_MultiReserveResource_r16
    nRsv = numel(rp.sl_ResourceReservePeriodList_r16);
    [rsvRaw, idx] = phy.ts38212.takeField(bits, idx, ceil(log2(nRsv)));
    dynamicParams.reservationPeriodIndex = phy.ts38212.uintFromBits(rsvRaw);
else
    dynamicParams.reservationPeriodIndex = 0;
end

nPattern = numel(pssch.sl_PSSCH_DMRS_TimePatternList_r16);
[dmrsRaw, idx] = phy.ts38212.takeField(bits, idx, ceil(log2(nPattern)));
dynamicParams.dmrsPatternIndex = phy.ts38212.uintFromBits(dmrsRaw);

[sci2Raw, idx] = phy.ts38212.takeField(bits, idx, 2);
sci2Val = phy.ts38212.uintFromBits(sci2Raw);
switch sci2Val
    case 0
        dynamicParams.sci2Format = 'A';
    case 1
        dynamicParams.sci2Format = 'B';
    otherwise
        error('ts38212:sci1aUnpack:reservedSci2Format', 'sci1aUnpack: 2nd-stage SCI format value %d is reserved (Table 8.3.1.1-1)', sci2Val);
end

[betaRaw, idx] = phy.ts38212.takeField(bits, idx, 2);
dynamicParams.betaOffsetIndex = phy.ts38212.uintFromBits(betaRaw);

[portRaw, idx] = phy.ts38212.takeField(bits, idx, 1);
dynamicParams.numDmrsPort = phy.ts38212.uintFromBits(portRaw);

[mcsRaw, idx] = phy.ts38212.takeField(bits, idx, 5);
dynamicParams.mcs = phy.ts38212.uintFromBits(mcsRaw);

addMcsWidth = phy.ts38212.additionalMcsTableWidth(pool.sl_Additional_MCS_Table_r16);
if addMcsWidth > 0
    [addRaw, idx] = phy.ts38212.takeField(bits, idx, addMcsWidth);
    dynamicParams.additionalMcsTableIndex = phy.ts38212.uintFromBits(addRaw);
else
    dynamicParams.additionalMcsTableIndex = 0;
end

if psfch.sl_PSFCH_Period_r16 == 2 || psfch.sl_PSFCH_Period_r16 == 4
    [psfchRaw, idx] = phy.ts38212.takeField(bits, idx, 1);
    dynamicParams.psfchOverhead = phy.ts38212.uintFromBits(psfchRaw);
else
    dynamicParams.psfchOverhead = 0;
end

[~, idx] = phy.ts38212.takeField(bits, idx, pscch.sl_NumReservedBits_r16);

if idx - 1 ~= numel(bits)
    error('ts38212:sci1aUnpack:badLength', 'sci1aUnpack: consumed %d bits but input has %d', idx - 1, numel(bits));
end
end
