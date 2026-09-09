function a = toAir(t, ueId, posXY)
%toAir Turn a PHY-SAP transmission request into an on-air transmission.
%Spec:   none. RF is not a 3GPP layer and there is no "RF SAP" in any specification -- this is
%        our own boundary, kept outside +phy/ so the baseband stays separable, as
%        INTEGRATION.md requires.
%Inputs: t      scalar struct -- a validated +sap/txReqInit request
%        ueId   integer, >=1 -- which UE is transmitting
%        posXY  1 x 2 real, metres -- its position at this slot
%Outputs: a  scalar struct: every field of `t`, plus .ueId and .posXY
%
%This is the whole RF transmit stage for now. Power is already decided upstream by
%+phy/+ts38213/slPowerControl (currently a max-power-always policy) and travels in
%t.txPowerDbm; a real RF chain would add PA compression, EVM and filter response here, and this
%function is where they land. Deliberately additive: it does not modify the request, so the
%same descriptor drives both the abstracted and the waveform path unchanged.

if ~(ueId >= 1 && mod(ueId, 1) == 0)
    error('rf:toAir:badUeId', 'toAir: ueId must be a positive integer, got %s', num2str(ueId));
end
if ~isequal(size(posXY), [1 2]) || ~isreal(posXY)
    error('rf:toAir:badPos', 'toAir: posXY must be a 1-by-2 real row vector, got size %s', mat2str(size(posXY)));
end

a       = t;
a.ueId  = ueId;
a.posXY = posXY;
end
