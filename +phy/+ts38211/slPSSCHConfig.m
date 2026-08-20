function cfg = slPSSCHConfig(pool, dynamicParams)
%slPSSCHConfig Build a clean-named PSSCH config from pool config + per-Tx parameters.
%Spec:   TS 38.211 V16.10.0, clause 8.3.1 (adapts cfg.resourcePool()'s
%        sl_PSSCH_Config_r16 slice, not a spec clause itself)
%Inputs: pool           scalar struct, the sl_PSSCH_Config_r16 field from
%                       cfg.resourcePool()'s output -- currently unused
%                       (sl_PSSCH_DMRS_TimePatternList_r16 etc. matter once
%                       slPSSCHDMRSIndices exists; see +phy/+ts38211/CLAUDE.md)
%        dynamicParams  scalar struct, per-transmission (not pool-static):
%          .NID        integer, 0..65535 -- N_ID = N_ID^X mod 2^16, the
%                      decimal CRC of the associated PSCCH (TS 38.212 clause
%                      8.3.2 -- not built yet; caller supplies the value)
%          .MbitSCI2   integer, >=0 -- M_bit,SCI2, the 2nd-stage-SCI/data
%                      boundary in the coded bit stream
%          .modScheme  char, one of 'QPSK','16QAM','64QAM','256QAM'
%                      (Table 8.3.1.2-1) -- the DATA portion's scheme; the
%                      SCI-2 portion is always QPSK, not configurable
%          .nsf        integer, >=0 -- slot number within a frame
%          .NsymbSlot  integer, >0 -- OFDM symbols per slot (14 or 12)
%Outputs: cfg  scalar struct: NID, MbitSCI2, modScheme, nsf, NsymbSlot
%#ok<*INUSD>
legalSchemes = {'QPSK', '16QAM', '64QAM', '256QAM'};
if ~ismember(dynamicParams.modScheme, legalSchemes)
    error('ts38211:slPSSCHConfig:badScheme', ...
        'slPSSCHConfig: "%s" is not in Table 8.3.1.2-1 (QPSK/16QAM/64QAM/256QAM)', dynamicParams.modScheme);
end
cfg.NID        = dynamicParams.NID;
cfg.MbitSCI2   = dynamicParams.MbitSCI2;
cfg.modScheme  = dynamicParams.modScheme;
cfg.nsf        = dynamicParams.nsf;
cfg.NsymbSlot  = dynamicParams.NsymbSlot;
end
