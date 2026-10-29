function test_slotHelpers()
%test_slotHelpers The slot-assembly helpers the access-stratum stack added to +phy/.
%SPEC: TS 38.211 V16.10.0 8.2.1 / 8.3.1.5 / 8.4.1.1.2 Table 8.4.1.1.2-1 (slAgcSymbol,
%      slPSSCHDMRSTimePattern); TS 38.212 Table 8.3.1.1-2 + TS 38.213 Table 9.3-2 (betaOffsetSci2);
%      TS 38.214 8.1.5 (frivLsubch).
%Level 1 here (exhaustive round trip of frivLsubch against frivEncode, structural AGC checks);
%the level-2 values from the independent-verifier pass are the asserted table entries below.

%% ---- FRIV -> L_subCH: exhaustive against frivEncode, both sl-MaxNumPerReserve ----------
for maxRes = [2 3]
    for Nsub = [1 2 5 10 27]
        for L = 1:Nsub
            for s1 = 0:Nsub - L
                s2list = 0;
                if maxRes == 3, s2list = 0:Nsub - L; end
                for s2 = s2list
                    f = phy.ts38212.frivEncode(s1, s2, L, Nsub, maxRes);
                    assert(phy.ts38212.frivLsubch(f, Nsub, maxRes) == L, ...
                        'FRIV %d (Nsub %d, maxRes %d) must decode to L=%d', f, Nsub, maxRes, L);
                end
            end
        end
    end
end

% Level 2 (independent-verifier, from the rendered TS 38.214 page 163): N = 5 bands and the case
% that separates the squared-term reading from the (sum)^2 misreading (48, not 88).
assert(phy.ts38212.frivEncode(3, 0, 2, 5, 2) == 8 && phy.ts38212.frivEncode(0, 0, 5, 5, 2) == 14, 'N=5, maxRes 2');
assert(phy.ts38212.frivEncode(1, 3, 2, 5, 3) == 38 && phy.ts38212.frivEncode(1, 2, 3, 5, 3) == 48 && ...
    phy.ts38212.frivEncode(4, 4, 1, 5, 3) == 24, 'N=5, maxRes 3, incl. the discriminating L=3 case');
bandsL = arrayfun(@(f) phy.ts38212.frivLsubch(f, 5, 3), 0:54);
assert(isequal(find(diff(bandsL)) + 1, [25 41 50 54] + 1), 'maxRes 3 band edges 25, 41, 50, 54');

%% ---- DM-RS time pattern, TS 38.211 Table 8.4.1.1.2-1 ----------------------------
T = @phy.ts38211.slPSSCHDMRSTimePattern;
assert(isequal(T(13, 2, 2), [3 10]) && isequal(T(13, 2, 3), [1 6 11]) && isequal(T(13, 2, 4), [1 4 7 10]), 'l_d 13, PSCCH 2');
assert(isequal(T(13, 3, 2), [4 10]) && isequal(T(12, 2, 3), [1 5 9]), 'PSCCH 3 shifts only the 2-DM-RS row');
assert(isequal(T(10, 2, 2), [3 8]) && isequal(T(10, 3, 2), [4 8]) && isequal(T(9, 2, 3), [1 4 7]), 'l_d 9..10');
assert(isequal(T(8, 2, 2), [1 5]) && isequal(T(6, 3, 2), [1 5]), 'l_d 6..8 has only the 2-DM-RS pattern');
mustError(@() T(8, 2, 3), 'ts38211:slPSSCHDMRSTimePattern:notInTable', '3 DM-RS at l_d 8');
mustError(@() T(10, 2, 4), 'ts38211:slPSSCHDMRSTimePattern:notInTable', '4 DM-RS at l_d 10');

%% ---- beta offset ------------------------------------------------------------------
B = @phy.ts38213.betaOffsetSci2;
assert(B([0 2 4 6], 0) == 1.125 && B([0 2 4 6], 1) == 1.375 && B([0 2 4 6], 2) == 1.750 && B([0 2 4 6], 3) == 2.250, ...
    'indicator selects the list entry, which indexes Table 9.3-2');
assert(B([15 18 0 0], 0) == 10 && B([15 18 0 0], 1) == 20, 'Table 9.3-2 indices 15 and 18');
mustError(@() B([19 0 0 0], 0), 'ts38213:betaOffsetSci2:reserved', 'index 19 (reserved)');

%% ---- AGC duplication on the allocation only -----------------------------------------
grid = complex(zeros(60, 14));
grid(:, 2) = (1:60)';
grid = phy.ts38211.slAgcSymbol(grid, 1, 12:23);
assert(isequal(grid(13:24, 1), (13:24)') && nnz(grid(:, 1)) == 12, 'only the allocation''s subcarriers are copied');
end

function mustError(f, id, what)
try
    f();
catch e
    assert(strcmp(e.identifier, id), 'expected %s for %s, got %s: %s', id, what, e.identifier, e.message);
    return;
end
error('test:noError', 'expected an error (%s) for %s', id, what);
end
