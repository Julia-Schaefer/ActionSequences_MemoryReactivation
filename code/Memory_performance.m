%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot behavioural results based on 2nd-order encoding-trained RSA data
%
% Input  (data/behaviour/)            : desc-behaviour_RSA_info.mat, Perf_Image_sorting_task.mat
% Output (results/stats/)             : task-retrieval_desc-behaviour_stats.mat
%        (results/figures/behaviour/) : task-retrieval_desc-headturnByPosition_boxplot.png
%                                       task-retrieval_desc-imagesortingByHeadturn_boxplot.png
%                                       (.fig in the subfolder Matlab_fig/)
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

dir_data          = fullfile(dir_repo, 'data', 'behaviour');              % input
dir_stats         = fullfile(dir_repo, 'results', 'stats');               % output: statistics
dir_figures       = fullfile(dir_repo, 'results', 'figures', 'behaviour'); % output: figures

% create output folders if they don't exist yet
if ~exist(dir_stats, 'dir'),   mkdir(dir_stats);   end
if ~exist(dir_figures, 'dir'), mkdir(dir_figures); end
 
%% settings
task     = 2;         % RSA_info(1) = learning, RSA_info(2) = retrieval
pp_eeg   = 1:40;      % participants
nTrials  = 24;        % head-turn trials per participant (3 runs x 8 trials)
nTurns   = 4;         % head turns per trial
RSA_time = -1:0.1:3;  % RSA time axis [s]
 
% colour palette
darkGrey  = [0.4 0.4 0.4];     % remembered
lightGrey = [0.85 0.85 0.85];  % forgotten
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

%% load behav info
load(fullfile(dir_data, 'desc-behaviour_RSA_info.mat'), 'RSA_info_sum', 'participants');
RSA_data_info = cell(length(pp_eeg), 1);
for i = 1:numel(pp_eeg)
    j = find(participants == pp_eeg(i), 1);
    if isempty(j) || isempty(RSA_info_sum{j}), continue; end   % missing participant -> row stays empty
    RSA_data_info(i) = RSA_info_sum{j}(task);
end
RSA_data_info(all(cellfun(@isempty, RSA_data_info), 2), :) = [];   % drop missing participants
nSub = size(RSA_data_info, 1);
 
%% load image sorting performance (provides perf_im)
load(fullfile(dir_data, 'Perf_Image_sorting_task'))

% safety check: same participants in both files (3rd dimension of perf_im)
assert(size(perf_im{9,1},3) == nSub, ...
    'Number of participants differs: perf_im has %d, RSA_info %d', size(perf_im{9,1},3), nSub);
 
%% head-turn performance by position in the sequence
perf_hd = NaN(nTrials, nTurns, nSub);
trl_hd_info = cell(nSub,1);
 
for i = 1:nSub
    trialinfo = RSA_data_info{i}.info.trialinfo;
    for trl = 1:size(trialinfo, 1)
        ti = trialinfo{trl};
 
        trl_id = ti.trial;
        if ti.run == 2 || ti.run == 3 % trial numbers restart each run -> continuous ID across runs 1-3
            trl_id = trl_id + 8 * (ti.run - 1);
        end
 
        perf = ti.Performance_parts;
        perf_hd(trl_id,:,i)        = perf;
 
    end
    
% keep only segments that have all 4 head turns
trl_hd_info{i} = check_for_four_headturns(RSA_data_info{i}.info);
end
 
%% get performance structure
perf_fin_hd = NaN(nTrials, nTurns, nSub);
perf_fin_im = cell(5,1);
 
for im = 1:5
    perf_fin_im{im} = NaN(nTrials, nTurns, nSub);
end
 
for i = 1:nSub
    trlID    = trl_hd_info{i};
    keep_trl = trlID(~isnan(trlID(:,1)), 1);
    n        = numel(keep_trl);
 
    % head turn performance 
    perf_fin_hd(1:n,:,i)        = perf_hd(keep_trl,:,i);
    % image sorting performance
    for im = 1:5
        perf_fin_im{im}(1:n,:,i) = perf_im{9,im}(keep_trl,:,i);
    end
end
 
%% repeated-measures ANOVA: hd performance across the 4 positions
pos_all    = squeeze(mean(perf_fin_hd, 1, 'omitnan'))';   % subjects x positions
conditions = {'pos_1','pos_2','pos_3','pos_4'};
tbl        = array2table(pos_all, 'VariableNames', conditions);
rm         = fitrm(tbl, 'pos_1-pos_4 ~ 1');   
ranovatbl  = ranova(rm);
disp(ranovatbl);
 
%% test assumptions & non-paramteric equivalent
% normality of residuals 
dataMatrix = pos_all;
resids = dataMatrix - mean(dataMatrix, 2) - mean(dataMatrix, 1) + mean(dataMatrix(:));
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
 
% friedman test 
[pf, frtbl, stats] = friedman(dataMatrix, 1, 'off');  
 
%% post-hoc comparisons, pairwise contrasts
multcompareResults = multcompare(rm, 'Time', 'ComparisonType', 'bonferroni');
 
%% test assumptions & non-paramteric equivalent 
condNames    = tbl.Properties.VariableNames;
pairs        = nchoosek(1:width(tbl), 2);
nComparisons = size(pairs, 1);
 
results = table('Size', [nComparisons, 6], ...
    'VariableTypes', {'string','string','double','double','double','double'}, ...
    'VariableNames', {'Cond1','Cond2','h_norm','p_norm','p_wilcoxon','zval'});
 
for i = 1:nComparisons
    x = tbl.(condNames{pairs(i,1)});
    y = tbl.(condNames{pairs(i,2)});
    
    % normality of differences
    [h, p_norm]     = lillietest(x - y);
    % wilcoxon signed rank test
    [p_w, ~, stats] = signrank(x, y);
 
    results.Cond1(i)      = condNames{pairs(i,1)};
    results.Cond2(i)      = condNames{pairs(i,2)};
    results.h_norm(i)     = h;
    results.p_norm(i)     = p_norm;
    results.p_wilcoxon(i) = p_w;
    results.zval(i)      = stats.zval;
end
 
results.p_wilcoxon_bonf = min(results.p_wilcoxon * nComparisons, 1);   % Bonferroni
disp(results)
 
%% plot Fig.1 c: head direction performance by sequential position
fig_hd = figure;   % new figure, free number
[anova_result_hd, mul_comp_result_hd] = plotRepeatedMeasuresBoxplot(pos_all, ...
    {'Position1','Position2','Position3','Position4'}, 'Position in Sequence', 'Ratio of correct Head Turns', 0, 1);
 
 
%% image sorting performance for forgotten vs. remembered head turns
 
perf_sel = NaN(size(perf_fin_hd, 3), 2);   
    for i = 1:size(perf_fin_hd, 3)
        hd  = perf_fin_hd(:,:,i);
        % Ratio of correct image position
        img = perf_fin_im{2}(:,:,i);
        % [forgotten remembered]
        perf_sel(i,:) = [mean(img(hd == 0), 'omitnan'), mean(img(hd == 1), 'omitnan')];
    end
    
%% plot Fig.1 d: image sorting performance by head direction performance    
fig_im = figure;   
% drop pp who do not have any forgotten head turns
perf_sel = perf_sel(~isnan(perf_sel(:,1)),:);
[anova_result_im, mul_comp_result_im] = plotRepeatedMeasuresBoxplot(perf_sel, ...
    {'forgotten_head_turns','remembered_head_turns'}, ' ', 'Ratio of correct image position', 0, 4);
 
%% test assumptions & non-paramteric equivalent
% forgotten vs. remembered: normality of difference scores 
diffScores = perf_sel(:,1) - perf_sel(:,2);
diffScores = diffScores(~isnan(diffScores));
[h_diff, p_diff] = lillietest(diffScores);
 
% wilcoxon signed rank test
[p2, h2, stats2] = signrank(perf_sel(:,1), perf_sel(:,2));

%% save statistics and figures
% statistics: one struct per analysis
behaviour_stats.headturn_by_position.data            = pos_all;              % subjects x positions
behaviour_stats.headturn_by_position.ranova          = ranovatbl;
behaviour_stats.headturn_by_position.resid_normality = struct('h', h_resid, 'p', p_resid);
behaviour_stats.headturn_by_position.mauchly         = mauchlyTable;
behaviour_stats.headturn_by_position.epsilon         = epsTable;
behaviour_stats.headturn_by_position.df_gg           = [df1_corrected, df2_corrected];
behaviour_stats.headturn_by_position.friedman        = struct('p', pf, 'table', {frtbl});
behaviour_stats.headturn_by_position.posthoc         = multcompareResults;   % Bonferroni
behaviour_stats.headturn_by_position.wilcoxon        = results;              % pairwise, Bonferroni-corrected
behaviour_stats.headturn_by_position.plot_anova      = anova_result_hd;
behaviour_stats.headturn_by_position.plot_multcomp   = mul_comp_result_hd;

behaviour_stats.imagesorting_by_headturn.data            = perf_sel;         % subjects x [forgotten remembered]
behaviour_stats.imagesorting_by_headturn.diff_normality  = struct('h', h_diff, 'p', p_diff);
behaviour_stats.imagesorting_by_headturn.wilcoxon        = struct('p', p2, 'h', h2, 'stats', stats2);
behaviour_stats.imagesorting_by_headturn.plot_anova      = anova_result_im;
behaviour_stats.imagesorting_by_headturn.plot_multcomp   = mul_comp_result_im;

behaviour_stats.info.n_participants = nSub;
behaviour_stats.info.task           = 'retrieval';

save(fullfile(dir_stats, 'task-retrieval_desc-behaviour_stats.mat'), 'behaviour_stats');

% figures: .fig in Matlab_fig/, .png in the figure folder
dir_fig_mat = fullfile(dir_figures, 'Matlab_fig');
if ~exist(dir_fig_mat, 'dir'), mkdir(dir_fig_mat); end
figs      = [fig_hd, fig_im];
fig_names = {'task-retrieval_desc-headturnByPosition_boxplot', 'task-retrieval_desc-imagesortingByHeadturn_boxplot'};

fig_w = 22;  fig_h = 16;                                  % cm

for k = 1:numel(figs)
    set(figs(k), 'Units', 'centimeters', 'Position', [2 2 fig_w fig_h])
    set(figs(k), 'PaperUnits', 'centimeters', 'PaperSize', [fig_w fig_h], 'PaperPosition', [0 0 fig_w fig_h])

    keep_line_alpha(figs(k));
    savefig(figs(k), fullfile(dir_fig_mat, [fig_names{k} '.fig']));
    print(figs(k), fullfile(dir_figures, [fig_names{k} '.png']), '-dpng', '-r300');
end
