function p = positions(d, tSec, sizeM)
%positions Every UE's position at time tSec: constant velocity, reflected at the field edge.
%Reflection (not wrap-around) keeps a vehicle's path continuous, so no link's path loss jumps.
%Inputs: d      from harness.deploy.drop;  tSec  real, s;  sizeM  [Lx Ly], metres
%Outputs: p  N x 2, metres
raw = d.xy0 + d.vel * tSec;
p = raw;
for a = 1:2
    L = sizeM(a);
    q = mod(raw(:, a), 2 * L);
    p(:, a) = L - abs(L - q);
end
end
