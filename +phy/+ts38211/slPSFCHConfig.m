function cfg = slPSFCHConfig(pool, dynamicParams)
%slPSFCHConfig Build a clean-named PSFCH config from pool config + per-Tx parameters.
%Spec:   TS 38.211 V16.10.0, clause 8.3.4.2 (adapts cfg.resourcePool()'s
%        sl_PSFCH_Config_r16 slice, not a spec clause itself)
%Inputs: pool           scalar struct, the sl_PSFCH_Config_r16 field from
%                       cfg.resourcePool()'s output
%        dynamicParams  scalar struct, per-transmission (not pool-static):
%          .m0         integer, 0..11 -- TS 38.213 Table 16.3-1 cyclic shift
%                      pair value. WHICH pair applies is a 38.213
%                      resource-determination procedure (not a 38.211
%                      modulation formula) -- caller supplies it; this
%                      project does not implement Table 16.3-1 selection.
%          .mcs        integer, 0..11 -- TS 38.213 Table 16.3-2/16.3-3
%                      HARQ-ACK cyclic shift (0 NACK, 6 ACK); same
%                      caller-supplied reasoning as m0. Both tables are
%                      reconstructed at Documentations/Notes/07-....md if a
%                      caller wants to implement the lookup.
%          .lp         integer, >=0 -- l', the slot-relative index of the
%                      SECOND (content) PSFCH OFDM symbol
%          .nsf        integer, >=0 -- slot number within a radio frame
%          .NsymbSlot  integer, >0 -- OFDM symbols per slot (14 or 12)
%          .startPRB   integer, >=0 -- the PRB carrying this PSFCH
%                      transmission, per TS 38.213 clause 16.3 (also not
%                      extracted; supplied by the caller)
%          .symbol     integer, >=0 -- same OFDM symbol index as .lp within
%                      the slot (kept as a separate field since
%                      slPSFCHIndices() wants the absolute slot symbol index
%                      and .lp is that same value under clause 6.3.2.2's name)
%Outputs: cfg  scalar struct: nID, u, v, alpha, startPRB, symbol
%
%alpha is now computed via slPSFCHAlpha() (clause 6.3.2.2.2) -- no longer a
%required direct input, now that clauses 4-7 are extracted
%(Documentations/Notes/12-TS38211-Uplink-Support-Procedures.md).
if pool.sl_PSFCH_HopID_r16_Present
    nID = pool.sl_PSFCH_HopID_r16;
    u = mod(nID, 30);
else
    nID = 0;
    u = 0;
end
cfg.nID = nID;
cfg.u = u;
cfg.v = 0;
cfg.alpha = phy.ts38211.slPSFCHAlpha(dynamicParams.m0, dynamicParams.mcs, nID, ...
    dynamicParams.lp, dynamicParams.nsf, dynamicParams.NsymbSlot);
cfg.startPRB = dynamicParams.startPRB;
cfg.symbol = dynamicParams.symbol;
end
