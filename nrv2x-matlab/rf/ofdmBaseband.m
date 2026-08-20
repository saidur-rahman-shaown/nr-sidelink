function [bb, prm] = ofdmBaseband(rs, cfg)
%ofdmBaseband One CP-OFDM sidelink slot of baseband IQ — 5G Toolbox chain.
%
%   Uses nrCarrierConfig / nrResourceGrid / nrSymbolModulate /
%   nrOFDMModulate / nrOFDMInfo at the pool numerology (30 kHz SCS,
%   20 MHz -> 51 PRB), so the numerology, FFT size, per-symbol CP lengths
%   and sample rate are the toolbox's, not hand-rolled.
%
%   The full sidelink PHY (SL-SCH LDPC, SCI polar, DM-RS, AGC/guard) is
%   the Version 3 SidelinkPHYEntity, preferred by SidelinkUE.getWaveform
%   when on the path; this function fills the grid with QPSK for RF-module
%   tests and demos. Falls back to base MATLAB only if the toolbox is
%   absent.
%
%   [BB, PRM] = ofdmBaseband(RS)       default 51-PRB carrier
%   [BB, PRM] = ofdmBaseband(RS, CFG)  carrier sized from CFG pool fields

if nargin < 2, cfg = []; end

if exist('nrOFDMModulate', 'file') == 2
    % ---- 5G Toolbox path ---------------------------------------------
    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = 30;
    if ~isempty(cfg)
        carrier.SubcarrierSpacing = cfg.scs_kHz;
        carrier.NSizeGrid = max(11, cfg.sl_StartRB_Subchannel_r16 + ...
            cfg.sl_RB_Number_r16 + 1);
    else
        carrier.NSizeGrid = 51;               % 20 MHz @ 30 kHz
    end

    grid = nrResourceGrid(carrier);           % NSizeGrid*12 x 14
    nRE  = numel(grid);
    bits = randi(rs, [0 1], 2 * nRE, 1);
    grid(:) = nrSymbolModulate(bits, 'QPSK');

    bb   = nrOFDMModulate(carrier, grid, 'Windowing', 0);
    info = nrOFDMInfo(carrier);

    prm = struct('SampleRate', info.SampleRate, 'Nfft', info.Nfft, ...
        'CyclicPrefixLengths', info.CyclicPrefixLengths, ...
        'SymbolsPerSlot', info.SymbolsPerSlot, ...
        'SlotDur_s', 1e-3 / (carrier.SubcarrierSpacing / 15), ...
        'NSizeGrid', carrier.NSizeGrid, 'Toolbox', true);
else
    % ---- base-MATLAB fallback (no 5G Toolbox) ------------------------
    nFFT = 1024;  nUsed = 600;  cpLen = 72;  nSym = 14;
    bb = complex(zeros((nFFT + cpLen) * nSym, 1));
    half = nUsed / 2;
    scIdx = [nFFT - half + 1 : nFFT, 2 : half + 1];
    ptr = 0;
    for s = 1:nSym
        qpsk = exp(1j * (pi/4 + pi/2 * randi(rs, [0 3], nUsed, 1)));
        X = complex(zeros(nFFT, 1));
        X(scIdx) = qpsk;
        x = ifft(X) * sqrt(nFFT);
        x = [x(end - cpLen + 1:end); x];
        bb(ptr + 1 : ptr + numel(x)) = x;
        ptr = ptr + numel(x);
    end
    prm = struct('SampleRate', 30.72e6, 'Nfft', nFFT, ...
        'CyclicPrefixLengths', repmat(cpLen, 1, nSym), ...
        'SymbolsPerSlot', nSym, 'SlotDur_s', numel(bb) / 30.72e6, ...
        'NSizeGrid', 50, 'Toolbox', false);
end
end
