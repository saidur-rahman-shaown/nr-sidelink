function [prbStart, unusedPrbCount] = subchannelMap(nSubchRBStart, nSubchSize, numSubchannel, NPRB)
%subchannelMap Sub-channel starting PRBs for a sidelink resource pool.
%Spec:   TS 38.214 V16.17.0, clause 8 (sub-channel definition, preamble to clause 8.1)
%Inputs: nSubchRBStart  integer, 0..265 -- sl-StartRB-Subchannel, n_subCH_RB_start
%        nSubchSize     integer, one of {10,12,15,20,25,50,75,100} -- sl-SubchannelSize,
%                       n_subCH_size (PRBs per sub-channel)
%        numSubchannel  integer, 1..27 -- sl-NumSubchannel, number of sub-channels in the pool
%        NPRB           positive integer -- total PRBs in the resource pool (sl-RB-Number)
%Outputs: prbStart        1 x numSubchannel row vector, integer, 0-based -- physical PRB
%                         number of the first PRB of sub-channel m (MATLAB index m, m=1..
%                         numSubchannel corresponds to the spec's m=0..numSubchannel-1)
%         unusedPrbCount  nonnegative integer -- NPRB mod nSubchSize, the count of PRBs at the
%                         top of the resource pool a UE is not expected to use (informational;
%                         independent of nSubchRBStart/numSubchannel, not folded into prbStart)
if nSubchRBStart < 0 || nSubchRBStart > 265 || mod(nSubchRBStart, 1) ~= 0
    error('ts38214:subchannelMap:badStart', 'subchannelMap: nSubchRBStart must be an integer in 0..265, got %s', num2str(nSubchRBStart));
end
if ~any(nSubchSize == [10 12 15 20 25 50 75 100])
    error('ts38214:subchannelMap:badSize', 'subchannelMap: nSubchSize must be one of {10,12,15,20,25,50,75,100} (sl-SubchannelSize), got %s', num2str(nSubchSize));
end
if numSubchannel < 1 || numSubchannel > 27 || mod(numSubchannel, 1) ~= 0
    error('ts38214:subchannelMap:badNumSubchannel', 'subchannelMap: numSubchannel must be an integer in 1..27, got %s', num2str(numSubchannel));
end
if NPRB <= 0 || mod(NPRB, 1) ~= 0
    error('ts38214:subchannelMap:badNPRB', 'subchannelMap: NPRB must be a positive integer, got %s', num2str(NPRB));
end
if nSubchRBStart + numSubchannel * nSubchSize > NPRB
    error('ts38214:subchannelMap:badGeometry', 'subchannelMap: nSubchRBStart(%d) + numSubchannel(%d)*nSubchSize(%d) exceeds NPRB(%d)', nSubchRBStart, numSubchannel, nSubchSize, NPRB);
end
m = 0:(numSubchannel - 1);
prbStart = nSubchRBStart + m * nSubchSize;
unusedPrbCount = mod(NPRB, nSubchSize);
end
