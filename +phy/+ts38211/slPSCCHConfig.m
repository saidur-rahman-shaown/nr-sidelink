function cfg = slPSCCHConfig(pool, dynamicParams)
%slPSCCHConfig Build a clean-named PSCCH config from pool config + per-Tx parameters.
%Spec:   TS 38.211 V16.10.0, clause 8.3.2 (adapts cfg.resourcePool()'s
%        sl_PSCCH_Config_r16 slice, not a spec clause itself)
%Inputs: pool           scalar struct, the sl_PSCCH_Config_r16 field from
%                       cfg.resourcePool()'s output (present=false is legal;
%                       DMRS_NID then falls back to the documented default 0)
%        dynamicParams  scalar struct, per-transmission (not pool-static):
%          .startPRB  integer, >=0 -- first common resource block of the PSCCH assignment
%          .NRB       integer, >0 -- number of PRBs assigned to PSCCH
%          .symbols   row vector of OFDM symbol indices l, the REAL content
%                     symbols only (not the AGC-duplicated symbol before them
%                     -- that duplication is slAgcSymbol's job on the
%                     assembled grid, per +phy/+ts38211/CLAUDE.md)
%          .nsf       integer, >=0 -- slot number within a frame
%          .NsymbSlot integer, >0 -- OFDM symbols per slot (14 or 12)
%Outputs: cfg  scalar struct: startPRB, NRB, symbols, nsf, NsymbSlot, DMRS_NID
if pool.sl_DMRS_ScrambleID_r16_Present
    cfg.DMRS_NID = pool.sl_DMRS_ScrambleID_r16;
else
    cfg.DMRS_NID = 0;
end
cfg.startPRB  = dynamicParams.startPRB;
cfg.NRB       = dynamicParams.NRB;
cfg.symbols   = dynamicParams.symbols(:)';
cfg.nsf       = dynamicParams.nsf;
cfg.NsymbSlot = dynamicParams.NsymbSlot;
end
