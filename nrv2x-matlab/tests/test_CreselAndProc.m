function test_CreselAndProc()
%test_CreselAndProc Counter draw ranges and processing-time tables.
%SPEC: TS 38.321 5.22.1.1 (checklist items 14, 19); TS 38.214 Tables 8.1.4-1/-2

rs = RandStream('mt19937ar', 'Seed', 7);

% ---- proc time tables -------------------------------------------------
[t0, t1] = procTimeTable(0); assert(t0 == 1 && t1 == 3);
[t0, t1] = procTimeTable(1); assert(t0 == 1 && t1 == 5);
[t0, t1] = procTimeTable(2); assert(t0 == 2 && t1 == 9);
[t0, t1] = procTimeTable(3); assert(t0 == 4 && t1 == 17);

% ---- counter: P >= 100 ms -> [5, 15], boundary INCLUDED at 100 --------
cnts = zeros(1, 400);
for k = 1:400
    [cnts(k), cr] = creselDraw(100, rs);
    assert(cr == 10 * cnts(k), 'item 19: C_resel = 10 * counter');
end
assert(min(cnts) >= 5 && max(cnts) <= 15);
assert(min(cnts) == 5 && max(cnts) == 15, 'range endpoints should be hit in 400 draws');

% ---- counter: P = 20 ms -> k = ceil(100/20) = 5 -> [25, 75] -----------
for k = 1:200
    c = creselDraw(20, rs);
    assert(c >= 25 && c <= 75, 'item 14: <100 ms scaling branch');
end

% ---- counter: P = 99 ms -> k = ceil(100/99) = 2 -> [10, 30] -----------
for k = 1:200
    c = creselDraw(99, rs);
    assert(c >= 10 && c <= 30, 'boundary just under 100 ms');
end

% ---- P = 10 ms: max(20, P) floor -> k = ceil(100/20) = 5 -> [25, 75] --
for k = 1:100
    c = creselDraw(10, rs);
    assert(c >= 25 && c <= 75, 'max(20, P) floor in the scaling branch');
end

% ---- aperiodic --------------------------------------------------------
[c, cr] = creselDraw(0, rs);
assert(c == 0 && cr == 1, 'aperiodic: no counter, C_resel = 1');

fprintf('test_CreselAndProc: PASS\n');
end
