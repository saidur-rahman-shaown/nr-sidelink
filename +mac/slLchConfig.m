function lch = slLchConfig(macLchCfg)
%slLchConfig Resolve SL-LogicalChannelConfig-r16 into the numbers clause 5.22.1.4.1 uses.
%Spec:   TS 38.331 V16.22.0, SL-LogicalChannelConfig-r16 (sl-Priority-r16 INTEGER (1..8);
%        sl-PrioritisedBitRate-r16 ENUMERATED {kBps0, kBps8, ..., kBps65536, infinity};
%        sl-BucketSizeDuration-r16 ENUMERATED {ms5, ms10, ms20, ms50, ms100, ms150, ms300, ms500,
%        ms1000, spare7..spare1}; sl-HARQ-FeedbackEnabled-r16 ENUMERATED {enabled, disabled}
%        OPTIONAL). TS 38.321 V16.22.0, clause 5.22.1.4.1.1 (sPBR, sBSD, "sidelink bucket size
%        (i.e. sPBR x sBSD)").
%Inputs: macLchCfg  scalar struct mirroring the ASN.1 leaf, as +cfg/slrbPreconfig stores it:
%                     .sl_Priority_r16                      integer, 1..8
%                     .sl_PrioritisedBitRate_r16            char label
%                     .sl_BucketSizeDuration_r16            char label
%                     .sl_HARQ_FeedbackEnabled_r16_Present  logical
%                     .sl_HARQ_FeedbackEnabled_r16          char, 'enabled' or 'disabled'
%Outputs: lch  scalar struct:
%            .priority             integer, 1..8 (1 is the HIGHEST, see +mac/CLAUDE.md)
%            .pbrBytesPerSec       bytes/s, 0..65536e3, or Inf
%            .bsdSec               seconds, 0.005..1
%            .harqFeedbackEnabled  logical
%
%"kBps" is kilobytes per second and is taken as 1000 bytes, consistent with +rlc/amConfig's
%reading of pollByte's kB; 38.331 does not define the kilo (pending-human, +mac/CLAUDE.md).
%An absent sl-HARQ-FeedbackEnabled is read as disabled: the field is Need R, and a channel with
%no configured feedback cannot ask a receiver for any.

PBR_KBPS = [0 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536];
BSD_MS = [5 10 20 50 100 150 300 500 1000];
BYTES_PER_KB = 1000;
MS_PER_S = 1000;
PRIO_MIN = 1;
PRIO_MAX = 8;

p = macLchCfg.sl_Priority_r16;
if ~(p >= PRIO_MIN && p <= PRIO_MAX && mod(p, 1) == 0)
    error('mac:slLchConfig:badPriority', 'slLchConfig: sl-Priority-r16 must be an integer in 1..8, got %s', num2str(p));
end
lbl = macLchCfg.sl_PrioritisedBitRate_r16;
if strcmp(lbl, 'infinity')
    pbr = Inf;
else
    pbr = [];
    for k = 1:numel(PBR_KBPS)
        if strcmp(lbl, sprintf('kBps%d', PBR_KBPS(k)))
            pbr = PBR_KBPS(k) * BYTES_PER_KB;
        end
    end
    if isempty(pbr)
        error('mac:slLchConfig:badPbr', 'slLchConfig: "%s" is not an sl-PrioritisedBitRate-r16 value', lbl);
    end
end
lbl = macLchCfg.sl_BucketSizeDuration_r16;
bsd = [];
for k = 1:numel(BSD_MS)
    if strcmp(lbl, sprintf('ms%d', BSD_MS(k)))
        bsd = BSD_MS(k) / MS_PER_S;
    end
end
if isempty(bsd)
    error('mac:slLchConfig:badBsd', 'slLchConfig: "%s" is not an sl-BucketSizeDuration-r16 value (spares are not legal)', lbl);
end
fb = false;
if macLchCfg.sl_HARQ_FeedbackEnabled_r16_Present
    switch macLchCfg.sl_HARQ_FeedbackEnabled_r16
        case 'enabled',  fb = true;
        case 'disabled', fb = false;
        otherwise
            error('mac:slLchConfig:badFeedback', 'slLchConfig: sl-HARQ-FeedbackEnabled-r16 must be enabled or disabled');
    end
end
lch = struct('priority', p, 'pbrBytesPerSec', pbr, 'bsdSec', bsd, 'harqFeedbackEnabled', fb);
end
