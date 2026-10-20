
function [anova_result,mul_comp_result,posthoc_ttest_result,zero_pvals_corr, zero_tvals] = plotRepeatedMeasuresBoxplot(data, condLabels, xLabelStr, yLabelStr, doZeroTest, colorFlag)

% plotRepeatedMeasuresBoxplot(data, condLabels, xLabelStr, yLabelStr, doZeroTest)
% data: matrix of size [subjects x conditions]
% condLabels: cell array of condition labels (e.g. {'Cond1','Cond2','Cond3','Cond4'})
% xLabelStr, yLabelStr: strings for axis labels
% doZeroTest: boolean flag (true/false) whether to test each condition vs. 0
% colorFlag: 0 = no fill, 1 = greyscale fill, 2 = purple fill
if nargin < 6
    colorFlag = 1;  % default to grey fill
end

Font = 19;
nConds = length(condLabels);
nSubs = size(data, 1);
col = [0.3 0.3 0.3];  % consistent gray color

% Fill based on colorFlag
if colorFlag == 1  % Grey
    if nConds == 2
    fillColors(1,:) = [0.85 0.85 0.85];
    fillColors(2,:) = [0.4 0.4 0.4];
    else
    shadeVals = linspace(0.85, 0.3, nConds)';
    fillColors = repmat(shadeVals, 1, 3);  % RGB greys
    end
elseif colorFlag == 2  % Purple shades   
    shadeVals = linspace(0.4, 0.8, nConds)';
    fillColors = [shadeVals * 0.6, shadeVals * 0.3, shadeVals];  % RGB purples
    
elseif colorFlag == 3
    
    colorblind = [
    0.0039 0.4510 0.6980;  % blue
    0.8706 0.5608 0.0196;  % orange
    0.0078 0.6196 0.4510;  % green
    0.8353 0.3686 0.0000;  % red / vermillion
    0.8000 0.4745 0.6549;  % purple
    0.7922 0.5686 0.3804;  % brown / tan
    0.9843 0.6863 0.8941;  % pink
    0.5804 0.5804 0.5804;  % gray (original seaborn)
    0.9255 0.8824 0.2000;  % yellow
    0.3373 0.7059 0.9137;  % light blue / cyan
    0.0000 0.0000 0.0000;  % black (added)
    0.55 0.00 0.35;  % dark purple (added)
];
    
fillColors = [colorblind(9,:); colorblind(5,:); colorblind(4,:);colorblind(1,:);colorblind(8,:);colorblind(11,:)];

elseif colorFlag == 4
    fillColors(2,:)   = [0.0078 0.6196 0.4510]; % green
    fillColors(1,:) = [0.7922 0.5686 0.3804]; % brown / tan
else
    error('select color scheme')
end

% Build table with proper variable names
T = array2table(data, 'VariableNames', condLabels);
within = table(condLabels(:), 'VariableNames', {'Condition'});

% Build model formula (e.g., 'Cond1-Cond4 ~ 1')
modelStr = [condLabels{1} '-' condLabels{end} ' ~ 1'];

% Run repeated-measures ANOVA
rm = fitrm(T, modelStr, 'WithinDesign', within);
anova_result = ranova(rm);

% Post-hoc pairwise comparisons (Bonferroni (only with more than 2 conditions))
cmp = multcompare(rm, 'Condition', 'ComparisonType', 'bonferroni');

M       = table2array(T);
comp_oi = size(M,2);
pairs   = nchoosek(1:comp_oi, 2);
stats   = cell(size(pairs,1),1);
p_cont  = NaN(size(pairs,1),1);

% do multiple ttests
for t = 1:size(pairs,1)
[~,p_cont(t),~,stats{t}] = ttest(M(:,pairs(t,1)),M(:,pairs(t,2)));
end

% create Table content
t_cont      = NaN(size(pairs,1),1);
df_cont     = NaN(size(pairs,1),1);
sd_cont     = NaN(size(pairs,1),1);
contrast    = cell(size(pairs,1),1);

for t = 1:size(pairs,1)
   contrast{t}  = [T.Properties.VariableNames{pairs(t,1)} ' vs ' T.Properties.VariableNames{pairs(t,2)}];
   t_cont(t)    = stats{t}.tstat;
   df_cont(t)   = stats{t}.df;
   sd_cont(t)   = stats{t}.sd;
end

% Bonferroni corrected p-values
p_bonf = NaN(size(pairs,1),1);
nTests = length(p_cont); 
p_bonf = min(p_cont * nTests, 1);    

posthoc_ttest_result = table(contrast,df_cont,sd_cont,p_cont,p_bonf,t_cont);

% --- Remove duplicate comparisons like AB vs BA ---
p1 = cellstr(cmp.Condition_1);
p2 = cellstr(cmp.Condition_2);
pairs = strcat(p1, p2);
for p = 1:length(pairs)
    pair_norm{p} = sort(pairs{p});
end
[~, ~, grp] = unique(pair_norm);
uniq_idx = arrayfun(@(i) find(grp == i, 1), 1:max(grp));
mul_comp_result = cmp(uniq_idx, :);


% compute t-values for each pairwise comparison
% Estimate standard error from confidence interval width (assuming 95% CI),
% upper-lower CI
% se = (mul_comp_result.Upper-mul_comp_result.Lower) / (2 * 1.96);  % 1.96 â‰ˆ z(0.975) for 95% CI
% % Compute t-values
% mul_comp_result.tvals = mul_comp_result.Difference ./ se;

Estimate = (mul_comp_result.Upper + mul_comp_result.Lower) / 2;
t_critical = (Estimate - mul_comp_result.Lower) / mul_comp_result.StdErr;
mul_comp_result.tvals = Estimate ./ mul_comp_result.StdErr;

% plot data point scatterplot with lines on top
hold on
jit    = 0.08;

for i = 1:size(data, 1)
    xj = (1:nConds) + (rand(1, nConds) - 0.5) * 2 * jit;
    l = plot(xj, data(i,:), 'k-', 'LineWidth', 0.5);
    l.Color(4) = 0.2;  % alpha: 0 = invisible, 1 = solid
    for cc = 1:nConds
        scatter(xj(cc), data(i,cc), 40, fillColors(cc,:), 'filled');
    end   
end

% --- Plot boxplot and conditionally fill ---
boxplot(data, 'Colors', col, 'Symbol', 'k+', 'Widths', 0.5);
labels = strrep(condLabels, '_', ' ');
if strcmp(xLabelStr, 'Screen at angle [degree]')
    labels = {'-60°', '-30°', '30°', '60°'};
elseif strcmp(condLabels{2}, 'remembered_head_turns')
    labels = {sprintf('forgotten\nhead turns'), sprintf('remembered\nhead turns')};
end

% Get box handles
hBox = findobj(gca, 'Tag', 'Box');
hBox = flipud(hBox);  % Left to right order

    % Re-draw median lines on top
    hMedians = findobj(gca, 'Tag', 'Median');
    hMedians = flipud(hMedians);
    for i = 1:nConds
        x = get(hMedians(i), 'XData');
        y = get(hMedians(i), 'YData');
        line(x, y, 'Color', 'k', 'LineWidth', 1);
    end

yline(0, '--', 'Color', [0.5 0.5 0.5]);

% --- Brackets and pairwise significance ---
hold on;
flatData = data(:); flatData = flatData(~isnan(flatData));
yMax = max(flatData); yRange = range(flatData);
baseY = yMax + 0.04 * yRange;
stepY = 0.08 * yRange;

if nargin < 4 || doZeroTest ~= 1
count = 0;

for i = 1:height(mul_comp_result)
%       p = mul_comp_result.pValue(i)*2;
       p = mul_comp_result.pValue(i);
    if p < 0.05 %&& count == 1 % to regulate if p is plotted
        count = count + 1;
        idx1 = find(strcmp(condLabels, mul_comp_result.Condition_1{i}));
        idx2 = find(strcmp(condLabels, mul_comp_result.Condition_2{i}));
        if isempty(idx1) || isempty(idx2), continue; end

        x1 = min(idx1, idx2);
        x2 = max(idx1, idx2);
        yPos = baseY + count * stepY - 0.015;

        % Horizontal bracket line
        plot([x1, x2], [yPos, yPos], '-', 'Color', col, 'LineWidth', 1);

        % Add small star below bracket
       
%         text(mean([x1, x2]), yPos - 0.003 * yRange, '*', ...
            text(mean([x1, x2]), yPos, '*', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', Font-2, 'Color', col);

        % Add p-value text above bracket
        if p < 0.001
            pText = 'p < 0.001';
        else
            pText = sprintf('p = %.3f', p);
        end
        text(mean([x1, x2]), yPos + 0.03 * yRange, pText, ...
            'HorizontalAlignment', 'center', 'FontSize', Font-3, 'Color', col);
    end
end
end

% --- Optional: t-test vs. 0 and star + p-value ---
if nargin > 4 && doZeroTest
    zero_pvals = nan(1, nConds);
    zero_tvals = nan(1, nConds);
    alpha = 0.05;  
    for pos = 1:nConds
           [~, p,~,stats] = ttest(data(:, pos), 0); % two sided ttest per default
          zero_tvals(pos) = stats.tstat;
          zero_pvals(pos) = p;
%          non-paramteric wilcoxon rank test, if assumptions are violated
%           [p,~,stats] = signrank(data(:, pos), 0);
%           zero_tvals(pos) = stats.zval;
%           zero_pvals(pos) = p;
    end
    

    % Bonferroni correction
     zero_pvals_corr = min(zero_pvals * nConds, 1);
%     [~, ~, ~, zero_pvals_corr] = fdr_bh(zero_pvals, 0.05);
    
    for pos = 1:nConds
        if zero_pvals_corr(pos) < alpha
            yStar = max(data(:, pos)) + 0.01 * yRange;
            % Plot black star
            text(pos, 0.13, '*', 'HorizontalAlignment', 'center', ...
                'FontSize', Font + 2, 'Color', 'k');
%             text(pos, yStar, '*', 'HorizontalAlignment', 'center', ...
%                 'FontSize', Font + 2, 'Color', 'k');
            % Plot p-value text
            if zero_pvals_corr(pos) < 0.001
                pText = 'p < 0.001';
            else
                pText = sprintf('p = %.3f', zero_pvals_corr(pos));
            end
            text(pos, 0.15, pText, ...
                 'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', 'k');
%              text(pos, yStar + 0.04 * yRange, pText, ...
%                  'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', 'k');
        end
    end
end

% Extend y-limits to fit all annotations
ylim([min(flatData) - 0.1 * yRange, baseY + (sum(mul_comp_result.pValue < 0.05)) * stepY]);
% ylim([-0.15, baseY + (sum(cmp_clean.pValue < 0.05)) * stepY]);

% label ticks
ax = gca;
set(ax, 'FontSize', Font, 'Box', 'off', 'Color', 'w');
ax.XTickLabel = {};   % Standard-Labels ausblenden

yl = ylim(ax);
offset = 0.005 * diff(yl);   % Abstand unter der x-Achse, ggf. anpassen

for i = 1:numel(labels)
    text(ax, i, yl(1) - offset, labels{i}, ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'top', ...
        'Interpreter', 'none', ...
        'FontSize', Font);
end
ylabel(yLabelStr);
xlabel(xLabelStr);

hold off;

end


