function numerology = bootFromPreconfig(preconfig, freqIdx, bwpIdx)
%bootFromPreconfig Resolve both numerology sources from a preconfig tree and assert both.
%Spec:   TS 38.331 clause 6.3.5 -- sl-SCS-SpecificCarrierList-r16 (carrier grid numerology)
%        and the subcarrierSpacing inside sl-BWP-Generic-r16.sl-BWP-r16 (slot structure
%        numerology) are two independent resolutions; see +cfg/CLAUDE.md "Two numerology
%        resolutions -- both mandatory at boot."
%Inputs: preconfig  scalar struct as returned by cfg.preconfig()
%        freqIdx    positive integer, index into sl-PreconfigFreqInfoList-r16 (default 1)
%        bwpIdx     positive integer, index into that carrier's sl-BWP-List-r16 (default 1)
%Outputs: numerology  scalar struct:
%           carrierSCS_kHz, muCarrier   -- from sl-SCS-SpecificCarrierList-r16(1)
%           bwpSCS_kHz, muBwp           -- from sl-BWP-Generic-r16.sl-BWP-r16.subcarrierSpacing
%           slotsPerSubframe            -- 2^muBwp (slot structure numerology governs slot rate)
%
%An out-of-coverage UE has no other source for either numerology than this preconfig tree.
%Known trap (+cfg/CLAUDE.md): conflating carrier SCS with BWP SCS -- they are resolved
%independently below and never used to default one another, even when numerically equal.
if nargin < 2, freqIdx = 1; end
if nargin < 3, bwpIdx = 1; end

if freqIdx > numel(preconfig.sl_PreconfigFreqInfoList_r16)
    error('cfg:bootFromPreconfig:noCarrier', ...
        'sl-PreconfigFreqInfoList-r16 has no entry %d (TS 38.331 cl. 6.3.5)', freqIdx);
end
freqCfg = preconfig.sl_PreconfigFreqInfoList_r16(freqIdx);

if isempty(freqCfg.sl_SCS_SpecificCarrierList_r16)
    error('cfg:bootFromPreconfig:noCarrierNumerology', ...
        ['sl-SCS-SpecificCarrierList-r16 is empty: the carrier grid numerology cannot be ' ...
         'resolved (TS 38.331 cl. 6.3.5, SL-FreqConfigCommon-r16). An out-of-coverage UE has ' ...
         'no other source; this is a config error, not a case for a default.']);
end
numerology.carrierSCS_kHz = freqCfg.sl_SCS_SpecificCarrierList_r16(1).subcarrierSpacing;
numerology.muCarrier      = log2(numerology.carrierSCS_kHz / 15);

if ~freqCfg.sl_BWP_List_r16_Present || bwpIdx > numel(freqCfg.sl_BWP_List_r16)
    error('cfg:bootFromPreconfig:noBwp', ...
        'sl-BWP-List-r16 has no entry %d (TS 38.331 cl. 6.3.5, SL-FreqConfigCommon-r16)', bwpIdx);
end
bwp = freqCfg.sl_BWP_List_r16(bwpIdx);
if ~bwp.sl_BWP_Generic_r16_Present || ~bwp.sl_BWP_Generic_r16.sl_BWP_r16_Present
    error('cfg:bootFromPreconfig:noBwpNumerology', ...
        ['sl-BWP-Generic-r16.sl-BWP-r16 is absent: the slot structure numerology cannot be ' ...
         'resolved (TS 38.331 cl. 6.3.5, SL-BWP-Generic-r16). An out-of-coverage UE has no ' ...
         'other source; this is a config error, not a case for a default.']);
end
numerology.bwpSCS_kHz = bwp.sl_BWP_Generic_r16.sl_BWP_r16.subcarrierSpacing;
numerology.muBwp      = log2(numerology.bwpSCS_kHz / 15);

numerology.slotsPerSubframe = 2 ^ numerology.muBwp;
end
