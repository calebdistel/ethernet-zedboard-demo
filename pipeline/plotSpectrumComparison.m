function plotSpectrumComparison(bins, mags, names, ttl, outFile)
%PLOTSPECTRUMCOMPARISON Compare FFT magnitude frames that should overlap.
%   DISCLAIMER: AI GENERATED plotting helper
%   plotSpectrumComparison(bins, mags, names, ttl, outFile)
%     bins  - Nx1 bin indices
%     mags  - cell array of Nx1 magnitudes, in pipeline order (first = baseline), max 4
%     names - cellstr of series names
%
%   The series are expected to coincide, so each gets a distinct line
%   weight/marker to keep the overlap visible:
%     row 1: full spectrum in dB (normalized to each series' peak)
%     row 2: zoom on the two spectral peaks (linear)
%     row 3: difference between consecutive series (% of peak, plus LSB
%            when both series are raw fixed-point integers)

n = numel(mags);
assert(n >= 2 && n <= 4, 'Expected 2 to 4 series.');
bins = bins(:);
nrm  = cellfun(@(m) m(:) ./ max(abs(m)), mags, 'UniformOutput', false);

colors = {[0.70 0.70 0.70], [0.00 0.45 0.74], [0.85 0.33 0.10], [0.49 0.18 0.56]};
lines  = { {'LineWidth', 5}, {'LineWidth', 1.8}, {'LineWidth', 1.2, 'LineStyle', '--'}, {'LineWidth', 1.4, 'LineStyle', ':'} };
marks  = { {'LineWidth', 5}, ...
           {'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 8, 'LineWidth', 1.2}, ...
           {'LineStyle', 'none', 'Marker', 'x', 'MarkerSize', 9, 'LineWidth', 1.5}, ...
           {'LineStyle', 'none', 'Marker', '+', 'MarkerSize', 11, 'LineWidth', 1.2} };

% Two strongest distinct peaks of the baseline series
[~, p1] = max(nrm{1});
masked = nrm{1};
masked(max(1, p1-10):min(end, p1+10)) = 0;
[~, p2] = max(masked);
peaks = sort(bins([p1 p2]));
halfWidth = 8;

fig = figure('Color', 'w', 'Position', [100 100 1100 800]);
tl = tiledlayout(fig, 3, 6, 'TileSpacing', 'compact', 'Padding', 'compact');   % 6 columns: rows split 1, 2 or n-1 ways
title(tl, ttl, 'FontWeight', 'bold');

%% Row 1: full spectrum (dB)
ax = nexttile(tl, [1 6]);
hold(ax, 'on');
h = gobjects(n, 1);
for i = 1:n
    h(i) = plot(ax, bins, 20*log10(max(nrm{i}, 1e-6)), 'Color', colors{i}, ...
        lines{i}{:}, 'DisplayName', names{i});
end
grid(ax, 'on');
xlim(ax, [bins(1) bins(end)]);
ylim(ax, [-80 5]);
xlabel(ax, 'Bin');
ylabel(ax, 'Magnitude (dB re peak)');
title(ax, 'Full spectrum');
lgd = legend(ax, h, 'Orientation', 'horizontal');
lgd.Layout.Tile = 'north';

%% Row 2: peak zooms (linear)
for p = peaks(:)'
    ax = nexttile(tl, [1 3]);
    hold(ax, 'on');
    w = abs(bins - p) <= halfWidth;
    for i = 1:n
        plot(ax, bins(w), nrm{i}(w), 'Color', colors{i}, marks{i}{:});
    end
    grid(ax, 'on');
    xlim(ax, [p-halfWidth p+halfWidth]);
    ylim(ax, [0 1.05]);
    xlabel(ax, 'Bin');
    ylabel(ax, 'Normalized magnitude');
    title(ax, sprintf('Peak at bin %d', p));
end

%% Row 3: consecutive differences
for i = 2:n
    ax = nexttile(tl, [1 6/(n-1)]);
    d = 100 * (nrm{i} - nrm{i-1});
    plot(ax, bins, d, 'Color', colors{i}, 'LineWidth', 1);
    yline(ax, 0, 'k:');
    grid(ax, 'on');
    xlim(ax, [bins(1) bins(end)]);
    if all(d == 0), ylim(ax, [-1 1]); end
    xlabel(ax, 'Bin');
    ylabel(ax, '\Delta (% of peak)');

    t = sprintf('max |\\Delta| = %.3g%% of peak', max(abs(d)));
    a = mags{i-1}(:); b = mags{i}(:);
    if all(a == round(a)) && all(b == round(b))
        lsb = max(abs(b - a));
        t = sprintf('%s (%g LSB)', t, lsb);
        if lsb == 0, t = [t ', bit-exact']; end
    end
    title(ax, {sprintf('%s - %s', names{i}, names{i-1}), t});
end

exportgraphics(fig, outFile, 'Resolution', 150);
end
