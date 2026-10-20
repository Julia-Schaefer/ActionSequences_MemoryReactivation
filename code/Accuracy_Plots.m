%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% All accuracy plots
%
% Loads the results saved by the accuracy computation script:
%   results : accuracy + matching head velocity for learning, retrieval, memory
%   info    : time axes and labels
%
% Structure
%   1. without HD control : 1D and 2D plots (learning + retrieval)
%   2. with HD control    : drawn into the noHD 1D figures (learning + retrieval):                         
%   3. remembered vs. forgotten (without HD control)
%
% Stats (saved as results/stats/desc-accuracy_stats.mat):
%   stats.noHD.acc2D.<task>{cl}      without HD control, 2D
%   stats.noHD.acc1D.<task>{cl}      without HD control, 1D 
%   stats.withHD.acc1D.<task>{cl}    with HD control, 1D 
%   stats.contrast.acc1D.<task>{cl}  contrast noHD - withHD (paired, subjects
%                                    with valid data in both conditions)
%   stats.memory.acc2D.forgotten / .remembered
%   stats.memory.acc1D.forgotten / .remembered / .contrast (remembered - forgotten)
%   stats.memory.velocity_contrast   head velocity remembered - forgotten
%   <task> = learning | retrieval

% Figures: results/figures/accuracy/*.png (.fig in the subfolder Matlab_fig/)
%
% Class indices {cl}:
%   learning  noHD  : {1}-{4} classes, {5} mean
%   learning  withHD: {1}-{4} classes, {5} fixation cross, {6} mean
%   retrieval       : {1}-{4} classes, {5} mean
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

dir_results = fullfile(dir_repo, 'data', 'accuracy');                % input
dir_figures = fullfile(dir_repo, 'results', 'figures', 'accuracy');  % output: figures
dir_stats   = fullfile(dir_repo, 'results', 'stats');                % output: statistics


if ~exist(dir_figures, 'dir'), mkdir(dir_figures); end
if ~exist(dir_stats, 'dir'),   mkdir(dir_stats);   end

%% load results of the accuracy computation script
load(fullfile(dir_results, 'desc-accuracy_results.mat'))

%% settings
n_class    = 4;                     % classes plotted individually (+ class mean)
Font_size  = 26;
fig_pos    = [0.1, 0.1, 0.55, 0.8];
hd_tag     = {'noHD', 'withHD'};    % HD condition names (figures + stats)
class_name = {'animal','house','face','object','fixcross'};

% fixation cross exists only in the with-HD learning data (no noHD figure to
% draw it into): true = own 1D figure, false = not plotted
plot_fixcross_withHD = true;

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
class_map = colorblind([9 5 4 1 8 11], :);   % classes 1-4, class mean, fixation cross / velocity

% y-positions of the significance lines (1D)
sig_y_noHD    = -0.0025;
sig_y_withHD  = -0.005;
sig_y_contr   = -0.0075;
contr_color   = [0.3 0.3 0.3];
velo_color_HD = colorblind(8,:);   % velocity with HD control (gray; noHD velocity is black)

% time axes
time_test_learn  = info.time_test_learning;
time_train_learn = info.time_train_learning;
time_train_retr  = info.time_train_retrieval;
seg_time         = info.seg_time;   % test time of the HD segments

% settings per task (used by the 2D and the 1D plots)
cfg.learning  = struct('t_test', time_test_learn, 't_train', time_train_learn, 't_velo', time_test_learn(1:end-1), ...
                       'cvals', [-0.03 0.03], 'cbar_x', 4.5, 'title_y', 1.02, 'win', [-1.1 3], ...
                       'ylim_class', [-0.01 0.04], 'ylim_fix', [-0.01 0.065], 'ylim_mean', [-0.01 0.03], ...
                       'fig_offset', 0);
cfg.retrieval = struct('t_test', seg_time, 't_train', time_train_retr, 't_velo', seg_time, ...
                       'cvals', [-0.05 0.05], 'cbar_x', 3.5, 'title_y', 1.03, 'win', [-1 3], ...
                       'ylim_class', [-0.01 0.08], 'ylim_fix', [-0.01 0.08], 'ylim_mean', [-0.01 0.08], ...
                       'fig_offset', 100);
task_tags = {'learning', 'retrieval'};

stats = struct();

% noHD 1D figures (handles + data), reused for the overlay in the withHD run
fig1D = containers.Map('KeyType', 'char', 'ValueType', 'any');

%% ============ 1 + 2: without HD control (2D + 1D), with HD control (overlay in 1D) ============
for Hd_acc = 1:2
    cond = hd_tag{Hd_acc};

    % ---------------------------------------------------------------------
    % 2D plots: accuracy (test x train time) per class + class mean
    % (without HD control only)
    % ---------------------------------------------------------------------
    if Hd_acc == 1
        for t = 1:numel(task_tags)
            tag      = task_tags{t};
            c        = cfg.(tag);
            nPlot    = n_class + 1;
            acc      = results.(tag).accuracy{Hd_acc};
            velo_all = results.(tag).velocity{Hd_acc};
            stat_2D  = cell(nPlot, 1);

            for cl = 1:nPlot
                is_mean = (cl == nPlot);

                % accuracy per subject (bootstraps averaged)
                if is_mean
                    acc_subj = reshape(mean(acc(:,1:4,:,:),2), size(acc,1), size(acc,3), size(acc,4)); % mean over classes 1-4
                    plot_title = 'Mean Accuracy all Classes';
                    plot_tag   = 'mean';
                else
                    acc_subj = reshape(acc(:,cl,:,:), size(acc,1), size(acc,3), size(acc,4));   % single class, subj x test x train
                    plot_title = ['Accuracy ' class_name{cl}];
                    plot_tag   = class_name{cl};
                end
                velo = get_velocity(velo_all, cl, is_mean);

                figure(Hd_acc*1000 + c.fig_offset + cl);
                set(gcf, 'Name', sprintf('%s_%s_2D_%s', cond, tag, plot_tag), ...
                    'Units', 'normalized', 'Position', fig_pos);

                o = struct('cvals', c.cvals, 'title', plot_title, 'title_pos', [0.5, 1.02, 0], ...
                           'velo_col', repmat(colorblind(11,:), 3, 1), 'cbar_x', c.cbar_x, ...
                           'xlim_on', true, 'Font_size', Font_size);
                stat_2D{cl} = plot_acc_2D(acc_subj, c.t_test, c.t_train, velo, c.t_velo, o);
            end
            stats.noHD.acc2D.(tag) = stat_2D;
        end

        % save and close the 2D figures
        figs2D = findall(0, 'Type', 'figure', '-regexp', 'Name', '_2D_');
        save_figs(figs2D, dir_figures);
        close(figs2D);
    end

    % ---------------------------------------------------------------------
    % 1D plots: accuracy around the diagonal per class + class mean,
    % head velocity below
    % ---------------------------------------------------------------------
    for t = 1:numel(task_tags)
        tag = task_tags{t};
        c   = cfg.(tag);

        acc = results.(tag).accuracy{Hd_acc};
        train_window = [nearest(c.t_train, c.win(1)), nearest(c.t_train, c.win(2))];
        data1D       = bring2Dto1D_Accuracy(acc, train_window, c.t_test, c.t_train, 1);

        nPlot         = size(data1D,1) + 1;   % classes (+ fixation cross with HD, learning) + mean
        stat_1D       = cell(nPlot, 1);
        stat_1D_contr = cell(nPlot, 1);
        velo_all      = results.(tag).velocity{Hd_acc};

        for cl = 1:nPlot
            is_mean = (cl == nPlot);

            % accuracy, colour, labels, y-limits
            if is_mean
                data_to_plot = squeeze(mean(data1D(1:4,:,:),1));
                class_label  = 'class mean';
                plot_title   = 'Mean Accuracy all Classes';
                plot_tag     = 'mean';
            else
                data_to_plot = squeeze(mean(data1D(cl,:,:),1));
                class_label  = class_name{cl};
                plot_title   = ['Accuracy ' class_name{cl}];
                plot_tag     = class_name{cl};
            end
            if is_mean,     plot_ylim = c.ylim_mean;  col = class_map(5,:);
            elseif cl == 5, plot_ylim = c.ylim_fix;   col = class_map(6,:);   % fixation cross
            else,           plot_ylim = c.ylim_class; col = class_map(cl,:);
            end
            velo = get_velocity(velo_all, cl, is_mean);

            % with HD control 
            key     = sprintf('%s_%s', tag, plot_tag);
            overlay = (Hd_acc == 2 && isKey(fig1D, key));
            if Hd_acc == 2 && ~overlay && ~plot_fixcross_withHD
                continue   % only exists with HD control (fixation cross): nothing to compare with
            end

            if overlay
                col         = col * 0.5;                       % darker colour for HD control
                class_label = [class_label ' control'];
                sig_y       = sig_y_withHD;
                F = fig1D(key);
                set(F.fig, 'Name', sprintf('noHD_vs_withHD_%s_1D_%s', tag, plot_tag));
            else
                sig_y = sig_y_noHD;
                fig   = figure;                               
                set(fig, 'Name', sprintf('%s_%s_1D_%s', cond, tag, plot_tag), ...
                    'Units', 'normalized', 'Position', fig_pos);
                ax1 = subplot('Position', [0.20, 0.36,  0.725, 0.56]);    % [left, bottom, width, height]
                ax2 = subplot('Position', [0.20, 0.118, 0.725, 0.218]);
                F   = struct('fig', fig, 'ax1', ax1, 'ax2', ax2, 'p1', [], 'f1', [], 'data', []);
            end

            % --- upper panel: accuracy ---
            set(0, 'CurrentFigure', F.fig);  
            set(F.fig, 'CurrentAxes', F.ax1);
            hold(F.ax1, 'on');
            p1 = plot1D(data_to_plot, c.t_test, col, col, col, 1, 0, 3, '-', class_label);

            % cluster-based permutation test against zero
            stat_1D{cl} = ClusBasedPermTest1D(0.05, c.t_test, data_to_plot, 0);
            add_sigline(F.ax1, c.t_test, stat_1D{cl}.mask, sig_y, col);

            % contrast noHD - withHD (paired)
            if overlay
                % same subjects in the same order in both conditions?
                assert(size(F.data,1) == size(data_to_plot,1), ...
                    'Different number of subjects with and without HD control (%s)', key);

                % only subjects with valid data in BOTH conditions
                valid = ~any(isnan(F.data), 2) & ~any(isnan(data_to_plot), 2);
                fprintf('%s %s: %d of %d participants in contrast noHD - withHD\n', ...
                    tag, plot_tag, sum(valid), numel(valid));

                stat_1D_contr{cl}         = ClusBasedPermTest1D(0.05, c.t_test, F.data(valid,:) - data_to_plot(valid,:), 0);
                stat_1D_contr{cl}.valid   = valid;          % which subjects entered the contrast
                stat_1D_contr{cl}.n_valid = sum(valid);
                add_sigline(F.ax1, c.t_test, stat_1D_contr{cl}.mask, sig_y_contr, contr_color);
            end

            F.p1 = [F.p1, p1];
            legend(F.ax1, F.p1);   % overlay: noHD + HD control in one legend

            % formatting + velocity panel
            if ~overlay
                title(F.ax1, plot_title, 'FontSize', Font_size);
                ylim(F.ax1, plot_ylim);
                F.ax1.Title.Units    = 'normalized';
                F.ax1.Title.Position = [0.5, c.title_y, 0];
                ylabel(F.ax1, 'Decoding Accuracy (AOC)', 'FontSize', Font_size);
                xline(F.ax1, 0, 'HandleVisibility', 'off'); yline(F.ax1, 0, 'HandleVisibility', 'off');
                xlim(F.ax1, [-1 3]);
                F.ax1.FontSize   = Font_size;
                F.ax1.XTickLabel = [];   % no x tick labels on upper panel

                % --- lower panel: head velocity ---
                set(F.fig, 'CurrentAxes', F.ax2);
                hold(F.ax2, 'on');
                f1 = plot1D(velo, c.t_velo, class_map(6,:), class_map(6,:), class_map(6,:), 1, 0, 3, '-', 'Velocity [deg/sec]');
                xline(F.ax2, 0, 'HandleVisibility', 'off'); yline(F.ax2, 0, 'HandleVisibility', 'off');
                xlim(F.ax2, [-1 3]);
                xlabel(F.ax2, 'Time [sec]', 'FontSize', Font_size);
                F.ax2.FontSize = Font_size;
                F.f1 = f1;
                legend(F.ax2, F.f1);

                linkaxes([F.ax1, F.ax2], 'x');
                F.ax1.YLabel.Position(1) = -1.55;   % align y-labels of both panels
                F.ax2.YLabel.Position(1) = -1.55;
            else
                % --- lower panel: head velocity with HD control (gray) ---
                set(F.fig, 'CurrentAxes', F.ax2);
                hold(F.ax2, 'on');
                f1 = plot1D(velo, c.t_velo, velo_color_HD, velo_color_HD, velo_color_HD, 1, 0, 3, '-', 'Velocity control [deg/sec]');
                F.f1 = [F.f1, f1];
                legend(F.ax2, F.f1);   % velocity noHD + HD control in one legend
            end

            % keep the noHD figures + data for the overlay in the withHD run
            if Hd_acc == 1
                F.data     = data_to_plot;
                fig1D(key) = F;
            end
        end

        stats.(cond).acc1D.(tag) = stat_1D;
        if Hd_acc == 2
            stats.contrast.acc1D.(tag) = stat_1D_contr;
        end
    end

    % save all 1D figures of this run
    figs1D = findall(0, 'Type', 'figure', '-regexp', 'Name', '_1D_');
    save_figs(figs1D, dir_figures);
    if Hd_acc == 2
        close(figs1D);
    end
end

%% ============ 3: remembered vs. forgotten -> 2D plots, then 1D contrast ============
start_train    = nearest(time_train_retr, seg_time(1));
stop_train     = nearest(time_train_retr, seg_time(end));
hit_miss_color = [colorblind(6,:); colorblind(3,:)];   % forgotten (miss), remembered (hit)
perf_name      = {'Forgotten', 'Remembered'};
perf_field     = {'forgotten', 'remembered'};
velo_col_mem   = {colorblind([8 8 11],:), colorblind([11 11 11],:)};   % velocity colours in the 2D plots

% exclude the same subjects in both conditions if they don't meet the
% trial threshold in one of them
valid_pp = ~isnan(mean(results.memory.accuracy{1}(:,:,start_train:stop_train),[2 3])) ...
         & ~isnan(mean(results.memory.accuracy{2}(:,:,start_train:stop_train),[2 3]));

% ---------------------------------------------------------------------
% 2D plots: forgotten (1), remembered (2)
% ---------------------------------------------------------------------
for perf = 1:2
    acc_perf = results.memory.accuracy{perf}(valid_pp,:,:);
    velo     = squeeze(results.memory.velocity{perf}(valid_pp,:));

    figure(3000 + 100 + perf);
    set(gcf, 'Name', sprintf('memory_2D_%s', perf_field{perf}), ...
        'Units', 'normalized', 'Position', fig_pos);

    o = struct('cvals', [-0.05 0.05], 'title', ['Mean Accuracy ' perf_name{perf} ' Segments'], 'title_pos', [], ...
               'velo_col', velo_col_mem{perf}, 'cbar_x', 3.5, 'xlim_on', false, 'Font_size', Font_size);
    stats.memory.acc2D.(perf_field{perf}) = plot_acc_2D(acc_perf, seg_time, time_train_retr, velo, seg_time, o);
end

% ---------------------------------------------------------------------
% 1D: forgotten, remembered and their contrast, head velocity below
% ---------------------------------------------------------------------
figure(3000 + 100 + 3);
set(gcf, 'Name', 'memory_1D_contrast', 'Units', 'normalized', 'Position', fig_pos);
ax1 = subplot('Position', [0.20, 0.36, 0.725, 0.56]);   % [left, bottom, width, height]
ylims        = [-0.04 0.08];
plot_handles = [];   % legend entries

% average +/- 2 training time points around each diagonal entry
v = cell(4);
for perf = 1:2
    v{perf} = NaN(size(results.memory.accuracy{perf},1), size(seg_time,2));
    for s = 1:size(results.memory.accuracy{perf},1)
        A = squeeze(results.memory.accuracy{perf}(s,:,start_train:stop_train))';   % flip test and train time
        for t = 1:size(seg_time,2)
            row_start = max(1, t - 2);
            row_end   = min(length(start_train:stop_train), t + 2);
            v{perf}(s,t) = mean(A(row_start:row_end, t));
        end
    end
end

for perf = 1:2

    v{perf} = v{perf}(valid_pp,:);
    stat1D  = ClusBasedPermTest1D(0.05, seg_time, v{perf}, 0);
    p1 = plot1D_simple(v{perf}, seg_time, hit_miss_color(perf,:), ylims);
    plot_handles = [plot_handles, p1];
    stats.memory.acc1D.(perf_field{perf}) = stat1D;

    % accuracy against zero: mark significant clusters, label with the actual p-value
    if any(stat1D.mask)
        sig_y = -0.013 + perf*0.001;
        add_sigline(gca, seg_time, stat1D.mask, sig_y, hit_miss_color(perf,:));
        mid_sig_idx = round(mean(find(stat1D.mask)));
        if ~isempty(mid_sig_idx)
            text(seg_time(mid_sig_idx), sig_y + 0.005, p_label(cluster_p(stat1D)), ...
                'HorizontalAlignment', 'center', 'Color', 'black', 'FontSize', Font_size);
        end
    end

    % contrast remembered - forgotten
    if perf == 2
        hold on
        stat1D = ClusBasedPermTest1D(0.05, seg_time, v{2}-v{1}, 0);
        stats.memory.acc1D.contrast = stat1D;
        if any(stat1D.mask)
            p_val = stat1D.posclusters.prob;
            add_sigline(gca, seg_time, stat1D.mask, -0.025, colorblind(12,:));
            mid_sig_idx = round(mean(find(stat1D.mask)));
            if ~isempty(mid_sig_idx)
                text(seg_time(mid_sig_idx), -0.020, p_label(p_val), ...
                    'HorizontalAlignment', 'center', 'Color', 'black', 'FontSize', Font_size);
            end
        end
    end

    hold on
    xlim([seg_time(1) seg_time(end)])
end

title('Memory Contrast: Accuracy across all Classes', 'FontSize', Font_size);
ylabel('Decoding Accuracy (AOC)', 'FontSize', Font_size);
ax1 = gca;
ax1.FontSize       = Font_size;
ax1.Title.Position = [0.5, 1.02, 0];
ax1.XTickLabel     = [];
h_yline = yline(0); set(h_yline, 'HandleVisibility', 'off');
h_xline = xline(0); set(h_xline, 'HandleVisibility', 'off');

% --- lower panel: head velocity remembered vs. forgotten ---
ax2 = subplot('Position', [0.20, 0.118, 0.725, 0.218]);
stat1D = ClusBasedPermTest1D(0.05, seg_time, results.memory.velocity{2}(valid_pp,:) - results.memory.velocity{1}(valid_pp,:), 0);   % same subjects as plotted
stats.memory.velocity_contrast = stat1D;

f1_1 = plot1D(squeeze(results.memory.velocity{2}(valid_pp,:)), seg_time, ...
    colorblind(11,:), colorblind(11,:), colorblind(11,:), 1, 0, 3, '-', 'Velocity remembered [deg/sec]');
hold on
f1_2 = plot1D(squeeze(results.memory.velocity{1}(valid_pp,:)), seg_time, ...
    colorblind(8,:), colorblind(8,:), colorblind(8,:), 1, 0, 3, '-', 'Velocity forgotten [deg/sec]');
hold on
set(f1_2, 'HandleVisibility', 'off');   % exclude velocity from legend
set(f1_1, 'HandleVisibility', 'off');
xlim([-1 3]);
ylim([-10 100]);
xlabel('Time [sec]', 'FontSize', Font_size);
ax2.FontSize = Font_size;
legend([f1_1, f1_2]);

if any(stat1D.mask)
    p_val = stat1D.posclusters.prob;
    add_sigline(gca, seg_time, stat1D.mask, -5, colorblind(12,:));
    mid_sig_idx = round(mean(find(stat1D.mask)));
    if ~isempty(mid_sig_idx)
        text(seg_time(mid_sig_idx), 6, p_label(p_val), ...
            'HorizontalAlignment', 'center', 'Color', 'black', 'FontSize', Font_size);
    end
end

linkaxes([ax1, ax2], 'x');
ax1.YLabel.Position(1) = -1.55;   % align y-labels of both panels
ax2.YLabel.Position(1) = -1.55;
h_yline = yline(0); set(h_yline, 'HandleVisibility', 'off');
h_xline = xline(0); set(h_xline, 'HandleVisibility', 'off');

% legend with forgotten and remembered only
legend(plot_handles, perf_name, 'Location', 'best', 'FontSize', Font_size)

%% save all figures (file name = figure name) 
figs = findall(0, 'Type', 'figure');
save_figs(figs, dir_figures);
close all            
                  
%% slim the stats and save
keep  = {'mask','stat','freq','time','posclusters','negclusters','valid','n_valid'};
paths = {};
for t = {'learning','retrieval'}
    paths(end+1:end+4) = {{'noHD','acc2D',t{1}}, {'noHD','acc1D',t{1}}, {'withHD','acc1D',t{1}}, {'contrast','acc1D',t{1}}};
end
paths(end+1:end+6) = {{'memory','acc2D','forgotten'}, {'memory','acc2D','remembered'}, ...
                      {'memory','acc1D','forgotten'}, {'memory','acc1D','remembered'}, ...
                      {'memory','acc1D','contrast'},  {'memory','velocity_contrast'}};

for p = 1:numel(paths)
    node = getfield(stats, paths{p}{:});
    if iscell(node)                                   % one entry per class (empty ones are skipped)
        for i = 1:numel(node)
            if isstruct(node{i})
                node{i} = rmfield(node{i}, setdiff(fieldnames(node{i}), keep));
                if isfield(node{i}, 'mask'), node{i}.mask = logical(node{i}.mask); end
                if isfield(node{i}, 'stat'), node{i}.stat = single(node{i}.stat);  end
            end
        end
    elseif isstruct(node)                             % single struct (memory)
        node = rmfield(node, setdiff(fieldnames(node), keep));
        if isfield(node, 'mask'), node.mask = logical(node.mask); end
        if isfield(node, 'stat'), node.stat = single(node.stat);  end  
    end
    stats = setfield(stats, paths{p}{:}, node);
end

save(fullfile(dir_stats, 'desc-accuracy_stats.mat'), 'stats', '-v7');

%% ========================= local functions =========================

function stat = plot_acc_2D(acc_subj, t_test, t_train, velo, t_velo, o)
% 2D accuracy map (mean over subjects) + head velocity + cluster contour
%   acc_subj : subjects x test time x train time
%   o        : cvals, title, title_pos ([] = default position), velo_col (3 x 3),
%              cbar_x, xlim_on, Font_size
    plot2D_RSA(t_test, t_train, squeeze(mean(acc_subj,1,'omitnan'))', o.cvals, ...
        'Time [sec] (test)', 'Time [sec] (train)', 'Accuracy');
    if isempty(o.title_pos)
        title(o.title, 'FontSize', o.Font_size)
    else
        title(o.title, 'FontSize', o.Font_size, 'Units', 'normalized', 'Position', o.title_pos)
    end
    hold on
    f1 = plot1D(velo, t_velo, o.velo_col(1,:), o.velo_col(2,:), o.velo_col(3,:), 0.025, 0, 3, '-', 'Velocity [deg/sec]');
    yline(0, 'LineStyle', '-', 'Color', 'black', 'LineWidth', 1);

    ax = gca;
    ax.FontSize = o.Font_size;
    h = colorbar;
    h.Label.String      = 'Decoding Accuracy (AOC)';
    h.Label.FontSize    = o.Font_size;
    h.Label.Position(1) = o.cbar_x;
    if o.xlim_on
        xlim([-1 3]);
    end
    ylim([-1 3]);

    % cluster-based permutation test, significant area as contour
    stat = ClusBasedPermTest2D(0.05, t_test, t_train, acc_subj, 0);
    hold on
    sigmap = squeeze(sum(stat.mask,1));
    if sum(sigmap,[1 2]) > 0
        plot_contour(stat.freq, stat.time, sigmap');
    end
    hold on
    xline(0, 'HandleVisibility', 'off'); yline(0, 'HandleVisibility', 'off');
    legend(f1);
end

function velo = get_velocity(velo_all, cl, is_mean)
% head velocity for one class (or the mean over classes 1-4)
%   velo_all = subjects x class x time
    if is_mean, velo = squeeze(mean(velo_all(:,1:4,:),2,'omitnan'));
    else,       velo = squeeze(velo_all(:,cl,:));
    end
end

function add_sigline(ax, t, mask, y, col)
% draw a significance line at height y where mask is true (nothing if no cluster)
    mask = squeeze(mask);
    if ~any(mask), return; end
    sig       = nan(1, numel(t));
    sig(mask) = y;
    plot(ax, t, sig, 'Color', col, 'LineWidth', 6, 'HandleVisibility', 'off');
end

function p = cluster_p(stat)
% smallest cluster p-value (positive and negative clusters); NaN if no cluster
    p = NaN;
    if isfield(stat, 'posclusters') && ~isempty(stat.posclusters)
        p = min([p, stat.posclusters.prob]);   % min ignores NaN
    end
    if isfield(stat, 'negclusters') && ~isempty(stat.negclusters)
        p = min([p, stat.negclusters.prob]);
    end
end

function s = p_label(p)
% p-value as text for the figures ('p<0.001' instead of 'p=0.000')
    if p < 0.001
        s = 'p<0.001';
    else
        s = sprintf('p=%.3f', p);
    end
end

function save_figs(figs, dir_out)
% save figures: .fig in <dir_out>/Matlab_fig, .png in <dir_out>; file name = figure name
    dir_mat = fullfile(dir_out, 'Matlab_fig');
    if ~exist(dir_mat, 'dir'), mkdir(dir_mat); end
    for f = figs(:)'
        keep_line_alpha(f);   % line transparency survives in the .fig
        savefig(f, fullfile(dir_mat, [f.Name '.fig']));
        print(f, fullfile(dir_out, [f.Name '.png']), '-dpng', '-r600');
    end
end
