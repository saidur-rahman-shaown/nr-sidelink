function cfg = slPSBCHConfig(NIDSL, Nsymb)
%slPSBCHConfig Build a clean-named PSBCH config.
%Spec:   TS 38.211 V16.10.0, clause 8.3.3 / 8.4.3 (not a spec clause itself --
%        this only bundles the two values PSBCH's modulation/mapping need)
%Inputs: NIDSL  integer, 0..671 -- N_ID^SL, composed at the caller from
%               NID1/NID2 per the existing interface rule
%        Nsymb  integer, 13 (normal CP) or 11 (extended CP) -- N_symb^S-SSB,
%               from carrier/numerology, not from a resource pool field
%Outputs: cfg  scalar struct: NIDSL, Nsymb
%
%Unlike the other three channels, PSBCH has no slXxxConfig(pool, dynamicParams)
%form here -- cfg.resourcePool()'s sl_PSBCH_Config_r16 slice (dl-P0-PSBCH-r16,
%dl-Alpha-PSBCH-r16) is power control only, not used by modulation or mapping,
%so there is no pool slice to adapt at this layer.
if NIDSL < 0 || NIDSL > 671 || mod(NIDSL, 1) ~= 0
    error('ts38211:slPSBCHConfig:badNIDSL', 'slPSBCHConfig: NIDSL must be an integer in 0..671, got %s', mat2str(NIDSL));
end
if ~ismember(Nsymb, [11 13])
    error('ts38211:slPSBCHConfig:badNsymb', 'slPSBCHConfig: Nsymb must be 11 or 13, got %s', mat2str(Nsymb));
end
cfg.NIDSL = NIDSL;
cfg.Nsymb = Nsymb;
end
