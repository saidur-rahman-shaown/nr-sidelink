function ind = slPSSCHIndices(carrier, cfg)
%slPSSCHIndices PSSCH resource element indices, SCI-2 portion then data portion.
%Spec:   TS 38.211 V16.10.0, clause 8.3.1.5 (VRB mapping, two-step), 8.3.1.6
%        (VRB->PRB, non-interleaved so PRB index == VRB index -- cfg.startPRB
%        is used directly as the VRB origin, no separate mapping needed)
%Inputs: carrier  scalar struct, slCarrierConfig -- unused here
%        cfg      scalar struct:
%          .startPRB     integer, >=0 -- first (virtual == physical) resource block
%          .NRB          integer, >0
%          .ld           integer, >0 -- l_d, duration of the PSSCH+PSCCH
%                        allocation in symbols, INCLUDING the duplicated
%                        (AGC) first symbol at relative position 0
%          .dmrsSymbols  row vector, l-bar values from Table 8.4.1.1.2-1
%                        (ascending, never includes 0 -- see
%                        slPSSCHDMRSIndices; mapping starts at
%                        dmrsSymbols(1), never at symbol 0)
%          .Msymb1       integer, >=0 -- SCI-2 symbol count (= M_bit,SCI2/2)
%          .pscchRE      N-by-2 [k l] REs occupied by the associated PSCCH
%                        (data + its DM-RS); empty if none overlap
%          .ptrsRE       N-by-2 [k l] REs occupied by PT-RS, if configured
%                        (empty -- PT-RS RE-mapping isn't built yet, clause
%                        8.4.1.2.2 needs 38.214 L_PT-RS/K_PT-RS parameters)
%          .csirsRE      N-by-2 [k l] REs occupied by CSI-RS, if configured
%                        (empty -- CSI-RS RE-mapping isn't built yet)
%          .dataStartIdx integer, >=0, optional (default 0) -- index into the
%                        step-2 ordered available-RE list where the data
%                        portion begins. TS 38.214 governs the real starting
%                        position; not implemented here, caller may override.
%Outputs: ind  (Msymb1 + numel(avail2)-dataStartIdx)-by-2 [k l], in mapping
%              order: SCI-2 portion first (rows 1..Msymb1, matching
%              slPSSCH()'s d(1:Msymb1)), then the data portion (matching
%              slPSSCH()'s remaining output), both in increasing-k-then-l
%              order (k inner/fast, l outer/slow) starting from
%              dmrsSymbols(1)
if ~isfield(cfg, 'dataStartIdx'), cfg.dataStartIdx = 0; end
if cfg.dataStartIdx < 0 || mod(cfg.dataStartIdx, 1) ~= 0
    error('ts38211:slPSSCHIndices:badDataStartIdx', ...
        'slPSSCHIndices: dataStartIdx must be a nonnegative integer, got %s', mat2str(cfg.dataStartIdx));
end
if cfg.startPRB < 0 || mod(cfg.startPRB, 1) ~= 0
    error('ts38211:slPSSCHIndices:badStartPRB', 'slPSSCHIndices: startPRB must be a nonnegative integer, got %s', mat2str(cfg.startPRB));
end
if cfg.NRB <= 0 || mod(cfg.NRB, 1) ~= 0
    error('ts38211:slPSSCHIndices:badNRB', 'slPSSCHIndices: NRB must be a positive integer, got %s', mat2str(cfg.NRB));
end
if cfg.ld <= 0 || mod(cfg.ld, 1) ~= 0
    error('ts38211:slPSSCHIndices:badLd', 'slPSSCHIndices: ld must be a positive integer, got %s', mat2str(cfg.ld));
end
if isempty(cfg.pscchRE), cfg.pscchRE = zeros(0, 2); end
if isempty(cfg.ptrsRE), cfg.ptrsRE = zeros(0, 2); end
if isempty(cfg.csirsRE), cfg.csirsRE = zeros(0, 2); end

dmrsRE = phy.ts38211.slPSSCHDMRSIndices(cfg.startPRB, cfg.NRB, cfg.dmrsSymbols);

allK = (cfg.startPRB*12 : cfg.startPRB*12 + cfg.NRB*12 - 1)';
symbols = cfg.dmrsSymbols(1):(cfg.ld - 1);
nK = numel(allK);
nSym = numel(symbols);
ordered = [repmat(allK, nSym, 1), repelem(symbols(:), nK)];   % k inner, l outer

excludeStep1 = [dmrsRE; cfg.pscchRE; cfg.ptrsRE];
avail1 = ordered(~ismember(ordered, excludeStep1, 'rows'), :);
if size(avail1, 1) < cfg.Msymb1
    error('ts38211:slPSSCHIndices:notEnoughSCI2REs', ...
        'slPSSCHIndices: only %d REs available for %d SCI-2 symbols', size(avail1, 1), cfg.Msymb1);
end
indSCI2 = avail1(1:cfg.Msymb1, :);

excludeStep2 = [dmrsRE; cfg.pscchRE; cfg.ptrsRE; cfg.csirsRE; indSCI2];
avail2 = ordered(~ismember(ordered, excludeStep2, 'rows'), :);
if cfg.dataStartIdx >= size(avail2, 1)
    error('ts38211:slPSSCHIndices:badDataStart', 'slPSSCHIndices: dataStartIdx exceeds available REs');
end
indData = avail2(cfg.dataStartIdx+1:end, :);

ind = [indSCI2; indData];
end
