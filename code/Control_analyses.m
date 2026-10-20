%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check if decoding accuracy is driven by a class - head direction bias
%
% Input  (data/accuracy/)              : desc-accuracy_results.mat
% Output (results/stats/)              : task-retrieval_desc-biascheck_stats.mat
%        (results/figures/bias_check/) : task-retrieval_desc-biasVsAccuracy_scatter.png
%                                        task-retrieval_desc-meanAccuracyOutlier_1D.png
%                                        task-retrieval_desc-accuracyByBiasRank_boxplot.png
%                                        task-retrieval_desc-accuracyMedianSplit_boxplot.png
%                                        (.fig in the subfolder Matlab_fig/)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clearvars
close all
clc

%% paths: find <repo> = the folder that contains code/functions
this_file = mfilename('fullpath');
if isempty(this_file) || contains(this_file, 'LiveEditorEvaluationHelper')
    start_dir = pwd;                    % running in parts: use the current folder
else
    start_dir = fileparts(this_file);   % running the whole script (F5)
end

dir_repo = start_dir;
while ~isfolder(fullfile(dir_repo, 'code', 'functions'))
    parent = fileparts(dir_repo);
    if strcmp(parent, dir_repo)
        error('Repo not found. Set the current folder to <repo>/code and run again.')
    end
    dir_repo = parent;
end
addpath(fullfile(dir_repo, 'code', 'functions'))
fprintf('Repo: %s\n', dir_repo)

dir_fieldtrip = 'C:\Users\ra98jas\Documents\Julia_GitHub\Toolboxes\fieldtrip';    % set once; ignored if FieldTrip is already on the path
if ~exist('ft_defaults', 'file'), addpath(dir_fieldtrip); end
ft_defaults;

dir_results = fullfile(dir_repo, 'data', 'accuracy');                  % input
dir_stats   = fullfile(dir_repo, 'results', 'stats');                  % output: statistics
dir_figures = fullfile(dir_repo, 'results', 'figures', 'bias_check');  % output: figures

% create output folders if they don't exist yet
if ~exist(dir_stats, 'dir'),   mkdir(dir_stats);   end
if ~exist(dir_figures, 'dir'), mkdir(dir_figures); end

%% settings
win_acc   = [0 1.5];   % time window [s] (test and train time) for the class accuracy
win_1D    = [-1 3];    % training-time window [s] for the 1D accuracy 
Font_size = 26;        
rng(42)                

% colour palette
colorblind = [
    0.0039 0.4510 0.6980;  % 1  blue
    0.8706 0.5608 0.0196;  % 2  orange
    0.0078 0.6196 0.4510;  % 3  green
    0.8353 0.3686 0.0000;  % 4  red / vermillion
    0.8000 0.4745 0.6549;  % 5  purple
    0.7922 0.5686 0.3804;  % 6  brown / tan
    0.9843 0.6863 0.8941;  % 7  pink
    0.5804 0.5804 0.5804;  % 8  gray (original seaborn)
    0.9255 0.8824 0.2000;  % 9  yellow
    0.3373 0.7059 0.9137;  % 10 light blue / cyan
    0.0000 0.0000 0.0000;  % 11 black       (added)
    0.55   0.00   0.35;    % 12 dark purple (added)
];
class_map = colorblind([9 5 4 1 8 11], :);   % classes 1-4, class mean, black

%% load results of the accuracy computation script
load(fullfile(dir_results, 'desc-accuracy_results.mat'))

t_test  = info.seg_time;               % test time of the HD segments (retrieval)
t_train = info.time_train_retrieval;   % training time
nPP     = numel(results.learning.train_class);

% labels, accuracy and velocity: one row per participant, all in the order of info.participants
assert(nPP == numel(info.participants) && nPP == size(results.retrieval.accuracy{1},1) ...
       && nPP == size(results.retrieval.velocity{1},1), ...
    'Training labels, accuracy and velocity do not have the same participants');

%% class x head-direction bias of the training data (learning task)
% per class: max. number of trials at one head direction / expected number
% if the class were spread evenly over the 4 head directions
bias_class = NaN(nPP, 4);
for i = 1:nPP
    label_all = results.learning.train_class{i}(:);   % all bootstraps merged
    hd_all    = results.learning.train_hd{i}(:);

    valid           = ~isnan(label_all) & ~isnan(hd_all);   % trials with both labels (keeps class/HD pairs together)
    hd_all_clean    = hd_all(valid);
    label_all_clean = label_all(valid);

    counts_hd       = crosstab(hd_all_clean, label_all_clean);   % head direction x class
    bias_class(i,:) = max(counts_hd) ./ (sum(counts_hd)/4);
end

%% class accuracy (retrieval) in the time window
toi_test  = nearest(t_test,  win_acc(1)):nearest(t_test,  win_acc(2));
toi_train = nearest(t_train, win_acc(1)):nearest(t_train, win_acc(2));
class_acc = squeeze(mean(results.retrieval.accuracy{1}(:,:,toi_test,toi_train), [3 4], 'omitnan'));   % subj x class

% participants with accuracy in all 4 classes (rows of bias_class_all / class_acc_all)
validIdx       = ~any(isnan(class_acc), 2);
bias_class_all = bias_class(validIdx,:);
class_acc_all  = class_acc(validIdx,:);
nValid         = size(class_acc_all, 1);

%% bias vs. accuracy: Spearman correlation per class (Bonferroni-corrected)
r_spear    = NaN(4,1);
pval_spear = NaN(4,1);

fig_scatter = figure;
hold on
for cc = 1:4
    x = bias_class_all(:,cc);
    y = class_acc_all(:,cc);
    scatter(x, y, 35, class_map(cc,:), 'filled');
    [r_spear(cc), pval_spear(cc)] = corr(x, y, 'Type', 'Spearman');
end
pvals_spear_corr = min(pval_spear * numel(pval_spear), 1);   % Bonferroni

% mean +/- 3 SD over all participants and classes (outlier limits)
acc_m = mean(class_acc_all(:));
acc_s = std(class_acc_all(:));
yline(acc_m,           'LineWidth', 1)
yline(acc_m + 3*acc_s, 'black', 'LineWidth', 1, 'LineStyle', '--')
yline(acc_m - 3*acc_s, 'black', 'LineWidth', 1, 'LineStyle', '--')

%% mixed-effects model: accuracy ~ bias + (1|subject) + (1|class)
% long format: subjects x classes stacked column-wise
bias_long  = bias_class_all(:);
acc_long   = class_acc_all(:);
subject_id = repmat((1:nValid)', 4, 1);
class_id   = repelem((1:4)', nValid, 1);

tbl_lme = table(acc_long, bias_long, subject_id, class_id, ...
    'VariableNames', {'decode_all', 'bias_all', 'subject_id', 'class_id'});
lme = fitlme(tbl_lme, 'decode_all ~ bias_all + (1|subject_id) + (1|class_id)');
disp(lme)
[R2_marg, R2_cond] = rsquaredLME(lme);

% normality of the residuals
[h_res, p_res] = lillietest(residuals(lme));

%% outliers: accuracies outside mean +/- 3 SD
no_outlier = acc_long < acc_m + 3*acc_s & acc_long > acc_m - 3*acc_s;
scatter(bias_long(~no_outlier), acc_long(~no_outlier), 80, 'MarkerEdgeColor', 'r', 'Marker', 'd');

%% model fit with and without outliers (fixed-effect regression lines)
x_fit = linspace(min(bias_long), max(bias_long), 100)';

% full model
fe = fixedEffects(lme);   % [intercept; slope]
plot(x_fit, fe(1) + fe(2)*x_fit, 'Color', class_map(5,:), 'LineWidth', 3, 'LineStyle', '--');

% model without outliers
lme_nooutl = fitlme(tbl_lme(no_outlier,:), 'decode_all ~ bias_all + (1|subject_id) + (1|class_id)');
fe = fixedEffects(lme_nooutl);
plot(x_fit, fe(1) + fe(2)*x_fit, 'Color', 'black', 'LineWidth', 3);

ax = gca;
ax.FontSize = 19;
ylabel('Decoding Accuracy', 'FontSize', 19);
xlabel('Class - Head Orientation Bias', 'FontSize', 19);
legend({'animal','house','face','object','mean accuracy','+3 SD','-3 SD','outlier', ...
    sprintf('all classes\n(with outlier)'), sprintf('all classes\n(no outlier)')});

%% 1D: mean accuracy over classes, with vs. without participants with an outlier class

rows_valid    = find(validIdx);
rows_no_outl  = rows_valid(all(reshape(no_outlier, size(class_acc_all)), 2));
rows_sel      = {1:nPP, rows_no_outl};                       % {with outlier, without outlier}
sel_label     = {'with outlier', 'without outlier'};

train_window  = [nearest(t_train, win_1D(1)), nearest(t_train, win_1D(2))];
data1D        = bring2Dto1D_Accuracy(results.retrieval.accuracy{1}, train_window, t_test, t_train, 1);   % class x subj x time
velo          = results.retrieval.velocity{1};               % subj x class x time (absolute)

fig_1D = figure;
set(fig_1D, 'Units', 'normalized', 'Position', [0.1, 0.1, 0.55, 0.8]);
ax1 = subplot('Position', [0.20, 0.36,  0.725, 0.56]);    % accuracy  [left, bottom, width, height]
ax2 = subplot('Position', [0.20, 0.118, 0.725, 0.218]);   % velocity
plot_handles      = [];
plot_handles_velo = [];
stat_out_1D       = cell(1,2);

for out = 1:2
    rows = rows_sel{out};
    if out == 1
        col      = class_map(5,:);
        col_velo = col;
    else
        col      = class_map(5,:)*0.5;
        col_velo = col*0.5;
    end

    % --- upper panel: accuracy + cluster-based permutation test ---
    set(fig_1D, 'CurrentAxes', ax1);
    hold(ax1, 'on');
    acc_mean_1D = squeeze(mean(data1D(1:4,rows,:),1));
    p1 = plot1D(acc_mean_1D, t_test, col, col, col, 1, 0, 3, '-', ['class mean (' sel_label{out} ')']);
    stat_out_1D{out} = ClusBasedPermTest1D(0.05, t_test, acc_mean_1D, 0);
    sigline = nan(1, numel(stat_out_1D{out}.time));
    sigline(stat_out_1D{out}.mask) = -0.0025*out;
    plot(ax1, t_test, sigline, 'color', col, 'linewidth', 6);
    plot_handles = [plot_handles, p1];
    legend(ax1, plot_handles(isgraphics(plot_handles)));

    % --- lower panel: head velocity (mean over classes) ---
    set(fig_1D, 'CurrentAxes', ax2);
    hold(ax2, 'on');
    velo_plot = squeeze(mean(velo(rows,:,:),2,'omitnan'));
    f1 = plot1D(velo_plot, t_test, col_velo, col_velo, col_velo, 1, 0, 3, '-', ['Velocity [deg/sec] (' sel_label{out} ')']);
    plot_handles_velo = [plot_handles_velo, f1];
    legend(ax2, plot_handles_velo(isgraphics(plot_handles_velo)));
end

% formatting
title(ax1, 'Mean Accuracy all Classes', 'FontSize', Font_size);
ylim(ax1, [-0.01 0.08]);
ax1.Title.Units    = 'normalized';
ax1.Title.Position = [0.5, 1.03, 0];   
ylabel(ax1, 'Decoding Accuracy (AOC)', 'FontSize', Font_size);
xline(ax1, 0, 'HandleVisibility', 'off'); yline(ax1, 0, 'HandleVisibility', 'off');
xlim(ax1, [-1 3]);
ax1.FontSize   = Font_size;
ax1.XTickLabel = [];                   % no x tick labels on upper panel

xline(ax2, 0, 'HandleVisibility', 'off'); yline(ax2, 0, 'HandleVisibility', 'off');
xlim(ax2, [-1 3]);
xlabel(ax2, 'Time [sec]', 'FontSize', Font_size);
ax2.FontSize = Font_size;

linkaxes([ax1, ax2], 'x');
ax1.YLabel.Position(1) = -1.55;        % align y-labels of both panels
ax2.YLabel.Position(1) = -1.55;

%% accuracy by bias rank: per participant, classes sorted from lowest to highest bias
[~, sortIdx] = sort(bias_class_all, 2, 'ascend');   % column k = class with the k-th lowest bias
acc_by_rank  = NaN(nValid, 4);
for i = 1:nValid
    acc_by_rank(i,:) = class_acc_all(i, sortIdx(i,:));
end

% repeated-measures ANOVA
conditions = {'Very_Low','Low','High','Very_High'};
tbl_rank   = array2table(acc_by_rank, 'VariableNames', conditions);
rm         = fitrm(tbl_rank, 'Very_Low-Very_High ~ 1');  
ranovatbl  = ranova(rm);
disp(ranovatbl);

% normality of residuals (subject and condition effects removed)
resids = acc_by_rank - mean(acc_by_rank, 2) - mean(acc_by_rank, 1) + mean(acc_by_rank(:));
[h_resid, p_resid] = lillietest(resids(:));
fprintf('Pooled residuals: h=%d, p=%.4f\n', h_resid, p_resid)

% sphericity + Greenhouse-Geisser corrected df
mauchlyTable = mauchly(rm);
disp(mauchlyTable);
epsTable = epsilon(rm);
disp(epsTable)
eps_gg        = epsTable.GreenhouseGeisser;
df1_corrected = ranovatbl.DF(1) * eps_gg;   % effect df
df2_corrected = ranovatbl.DF(2) * eps_gg;   % error df

% Friedman test (non-parametric equivalent)
[p_friedman, tbl_friedman, stats_friedman] = friedman(acc_by_rank, 1, 'off');   % 'off': no table window

% boxplot + t-tests against zero
fig_rank = figure;
[anova_rank, multcomp_rank, posthoc_rank, zero_pvals_corr_rank, zero_tvals_rank] = ...
    plotRepeatedMeasuresBoxplot(acc_by_rank, conditions, 'Bias Level', 'Decoding Accuracy', 1, 2);

% tests against zero per bias level: t-test (Bonferroni, from the boxplot function),
% normality per level (Lilliefors), Wilcoxon signed-rank test (Bonferroni)
zero_tests_rank = zero_tests(acc_by_rank, conditions, zero_tvals_rank, zero_pvals_corr_rank);
disp(zero_tests_rank)

%% median split: low (ranks 1-2) vs. high (ranks 3-4) bias
% average the two classes per participant -> one value per participant and group
median_split = [mean(acc_by_rank(:,1:2), 2), mean(acc_by_rank(:,3:4), 2)];   % subj x [low high]

[~, p_split, ~, stats_split] = ttest(median_split(:,1), median_split(:,2));

% normality of the differences + Wilcoxon signed-rank test
[h_split_norm, p_split_norm] = lillietest(median_split(:,1) - median_split(:,2));
[p_split_wilc, h_split_wilc, stats_split_wilc] = signrank(median_split(:,1), median_split(:,2));

% boxplot + t-tests against zero
fig_split = figure;
[anova_split, multcomp_split, posthoc_split, zero_pvals_corr_split, zero_tvals_split] = ...
    plotRepeatedMeasuresBoxplot(median_split, {'Low','High'}, 'Bias Level', 'Decoding Accuracy', 1, 2);

% tests against zero per group: t-test (Bonferroni, from the boxplot function),
% normality per group (Lilliefors), Wilcoxon signed-rank test (Bonferroni)
zero_tests_split = zero_tests(median_split, {'Low','High'}, zero_tvals_split, zero_pvals_corr_split);
disp(zero_tests_split)

%% save statistics and figures
stats = struct();
stats.info.participants = info.participants(validIdx);   % participants in the analysis (row order)
stats.info.win_acc      = win_acc;
stats.info.win_1D       = win_1D;

stats.bias_vs_accuracy.bias            = bias_class_all;   % subj x class
stats.bias_vs_accuracy.accuracy        = class_acc_all;    % subj x class
stats.bias_vs_accuracy.spearman        = struct('r', r_spear, 'p', pval_spear, 'p_bonf', pvals_spear_corr);
stats.bias_vs_accuracy.lme             = lme;                 % model object
stats.bias_vs_accuracy.lme_tables      = lme_tables(lme);     % coefficients, ANOVA, fit 
stats.bias_vs_accuracy.R2              = struct('marginal', R2_marg, 'conditional', R2_cond);
stats.bias_vs_accuracy.resid_normality = struct('h', h_res, 'p', p_res);
stats.bias_vs_accuracy.outlier_limits  = acc_m + [-3 3]*acc_s;
stats.bias_vs_accuracy.no_outlier      = reshape(no_outlier, size(class_acc_all));   % subj x class
stats.bias_vs_accuracy.lme_no_outlier        = lme_nooutl;
stats.bias_vs_accuracy.lme_no_outlier_tables = lme_tables(lme_nooutl);

stats.mean_1D.participants = {info.participants(rows_sel{1}), info.participants(rows_sel{2})};   % {with, without outlier}
stats.mean_1D.cluster      = stat_out_1D;

stats.bias_rank.data            = acc_by_rank;   % subj x [very low ... very high]
stats.bias_rank.ranova          = ranovatbl;
stats.bias_rank.resid_normality = struct('h', h_resid, 'p', p_resid);
stats.bias_rank.mauchly         = mauchlyTable;
stats.bias_rank.epsilon         = epsTable;
stats.bias_rank.df_gg           = [df1_corrected, df2_corrected];
stats.bias_rank.friedman        = struct('p', p_friedman, 'table', {tbl_friedman}, 'stats', stats_friedman);
stats.bias_rank.boxplot         = struct('anova', anova_rank, 'multcomp', multcomp_rank, 'posthoc', posthoc_rank, ...
                                         'zero_p_corr', zero_pvals_corr_rank, 'zero_t', zero_tvals_rank);
stats.bias_rank.zero_tests      = zero_tests_rank;   % per level: t-test, Lilliefors, Wilcoxon (Bonferroni)

stats.median_split.data           = median_split;   % subj x [low high]
stats.median_split.ttest          = struct('p', p_split, 'stats', stats_split);
stats.median_split.diff_normality = struct('h', h_split_norm, 'p', p_split_norm);
stats.median_split.wilcoxon       = struct('p', p_split_wilc, 'h', h_split_wilc, 'stats', stats_split_wilc);
stats.median_split.boxplot        = struct('anova', anova_split, 'multcomp', multcomp_split, 'posthoc', posthoc_split, ...
                                           'zero_p_corr', zero_pvals_corr_split, 'zero_t', zero_tvals_split);
stats.median_split.zero_tests     = zero_tests_split;   % per group: t-test, Lilliefors, Wilcoxon (Bonferroni)

save(fullfile(dir_stats, 'task-retrieval_desc-biascheck_stats.mat'), 'stats');

% figures: .fig in Matlab_fig/, .png in the figure folder
figs      = [fig_scatter, fig_1D, fig_rank, fig_split];
fig_names = {'task-retrieval_desc-biasVsAccuracy_scatter', 'task-retrieval_desc-meanAccuracyOutlier_1D', ...
             'task-retrieval_desc-accuracyByBiasRank_boxplot', 'task-retrieval_desc-accuracyMedianSplit_boxplot'};

dir_fig_mat = fullfile(dir_figures, 'Matlab_fig');
if ~exist(dir_fig_mat, 'dir'), mkdir(dir_fig_mat); end
fig_w = 29;  fig_h = 22;                                  % cm

for k = 1:numel(figs)
    set(figs(k), 'Units', 'centimeters', 'Position', [2 2 fig_w fig_h])
    set(figs(k), 'PaperUnits', 'centimeters', 'PaperSize', [fig_w fig_h], 'PaperPosition', [0 0 fig_w fig_h])

    keep_line_alpha(figs(k));
    savefig(figs(k), fullfile(dir_fig_mat, [fig_names{k} '.fig']));
    print(figs(k), fullfile(dir_figures, [fig_names{k} '.png']), '-dpng', '-r300');
end 

%% ========================= local functions =========================

function T = zero_tests(data, levels, t_vals, p_ttest_bonf)
% Tests against zero for every column (level) of data (subjects x levels):
%   1. t-test against 0, Bonferroni-corrected (t and p from plotRepeatedMeasuresBoxplot;
%      df = number of non-NaN values - 1, as in its ttest)
%   2. normality of the distribution per level (Lilliefors)
%   3. Wilcoxon signed-rank test against 0, Bonferroni-corrected
    n          = size(data, 2);
    df         = (sum(~isnan(data), 1) - 1)';   % degrees of freedom of the one-sample t-test
    lillie_h   = NaN(n,1);
    lillie_p   = NaN(n,1);
    p_wilc     = NaN(n,1);
    signedrank = NaN(n,1);
    zval       = NaN(n,1);   % only for the large-sample approximation
    for k = 1:n
        [lillie_h(k), lillie_p(k)] = lillietest(data(:,k));
        [p_wilc(k), ~, st]         = signrank(data(:,k), 0);
        signedrank(k)              = st.signedrank;
        if isfield(st, 'zval'), zval(k) = st.zval; end
    end
    T = table(levels(:), df, t_vals(:), p_ttest_bonf(:), lillie_h, lillie_p, p_wilc, min(p_wilc * n, 1), signedrank, zval, ...
        'VariableNames', {'level', 'df', 't', 'p_ttest_bonf', 'lillie_h', 'lillie_p', ...
                          'p_wilcoxon', 'p_wilcoxon_bonf', 'signedrank', 'zval'});
end

function out = lme_tables(m)
    c = m.Coefficients;
    out.coefficients = table(c.Name, c.Estimate, c.SE, c.tStat, c.DF, c.pValue, c.Lower, c.Upper, ...
        'VariableNames', {'Name', 'Estimate', 'SE', 'tStat', 'DF', 'pValue', 'Lower', 'Upper'});
    a = anova(m);
    out.anova = table(a.Term, a.FStat, a.DF1, a.DF2, a.pValue, ...
        'VariableNames', {'Term', 'FStat', 'DF1', 'DF2', 'pValue'});
    f = m.ModelCriterion;
    out.fit = table(f.AIC, f.BIC, f.LogLikelihood, f.Deviance, ...
        'VariableNames', {'AIC', 'BIC', 'LogLikelihood', 'Deviance'});
end