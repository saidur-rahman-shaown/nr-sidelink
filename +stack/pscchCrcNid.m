function NID = pscchCrcNid(sci1aBits, crcBits, nidMod)
%pscchCrcNid N_ID for PSSCH scrambling and DM-RS, from the CRC on the PSCCH.
%Spec:   TS 38.211 V16.10.0 clause 8.3.1.1 (and 8.4.1.1.1): "N_ID = N_ID^X mod 2^16 and the quantity
%        N_ID^X equals the decimal representation of the CRC on the PSCCH associated with the
%        PSSCH according to clause 8.3.2 of [4, TS 38.212]". The CRC is the clause 7.3.2 CRC24C of
%        the SCI-1A payload, computed here exactly as phy.ts38212.sci1aChainEncode computes it.
%Inputs: sci1aBits  A x 1 -- the SCI-1A payload (sci1aPack output, or the decoded payload)
%        crcBits    integer, 24
%        nidMod     integer, 2^16
%Outputs: NID  integer, 0..65535
%
%Both ends call this: the transmitter on the payload it packs, the receiver on the payload it
%decodes. A decoded payload that passed its CRC reproduces the same CRC, so the receiver needs no
%side channel to learn N_ID.

withCrc = phy.lib.ts38212.dciCrcEncode(logical(sci1aBits(:)), []);
crc = withCrc(end - crcBits + 1:end);
v = 0;
for k = 1:crcBits
    v = v * 2 + double(crc(k));
end
NID = mod(v, nidMod);
end
