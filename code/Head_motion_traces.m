%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Plot exemplary trace of head-motion velocity with detected motion onsets
%
% Input  (data/behaviour/)              : RSA_info_pp-01.mat
% Output (results/figures/head_motion/) : sub-01_task-<learning|retrieval>_desc-headmotionTrial03_plot.png
%                                         (.fig in the subfolder Matlab_fig/)
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
dir_data          = fullfile(dir_repo, 'data', 'example_data');                 % input
dir_figures       = fullfile(dir_repo, 'results', 'figures', 'head_motion'); % output: figures

% create output folder if it doesn't exist yet
if ~exist(dir_figures, 'dir'), mkdir(dir_figures); end
dir_fig_mat = fullfile(dir_figures, 'Matlab_fig');
if ~exist(dir_fig_mat, 'dir'), mkdir(dir_fig_mat); end
 
%% settings
pp_num    = 1;       % example participant
trl       = 3;       % example trial
tasks     = [1 2];   % tasks to plot (one figure per task)
task_name = {'learning', 'retrieval'};   % RSA_info(1) = learning, RSA_info(2) = retrieval (file names)
ds_factor = 100;     % downsampling factor
dt        = 0.1;     % sample interval after downsampling [s]
 
% colourblind-friendly palette
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
    0.0000 0.0000 0.0000;  % 11 black       (added) -> velocity
    0.55   0.00   0.35;    % 12 dark purple (added) -> head angle
    0.8863 0.5765 0.5569;  % 13 rose        (added) -> motion onsets
];
 
%% load info for the example participant
pp_str  = sprintf('pp-%02.0f',  pp_num);
load(sprintf('%s/RSA_info_%s.mat', dir_data, pp_str), 'RSA_info');
 
%% loop over tasks
for task = tasks
 
    % ---------------------------------------------------------------------
    % head angle and absolute angular velocity
    % ---------------------------------------------------------------------
    pol_angle  = downsample(RSA_info{task}.info.trial{trl}(2,:), ds_factor);
    time_angle = downsample(RSA_info{task}.info.time{trl},       ds_factor);
    pol_velo   = abs(diff(pol_angle, 1, 2) / dt);
    time_velo  = time_angle(1:end-1);
 
    % ---------------------------------------------------------------------
    % velocity peaks and motion threshold
    % ---------------------------------------------------------------------
    sd_velo    = std(pol_velo, 'omitnan');
    [~, locs]  = findpeaks(pol_velo, 'MinPeakHeight', sd_velo*0.5);   % adjust as needed
    peak_times = time_angle(locs);
 
    % threshold = mean velocity after excluding peaks (values > 3 SD)
    threshold = mean(pol_velo(pol_velo <= sd_velo*3), 'omitnan');
 
    % ---------------------------------------------------------------------
    % threshold crossings (linear interpolation between neighbouring samples)
    % ---------------------------------------------------------------------
    s         = pol_velo - threshold;
    cross_idx = find(s(1:end-1) .* s(2:end) < 0);   % sign change = crossing
 
    intersections_x = zeros(numel(cross_idx), 1);
    for k = 1:numel(cross_idx)
        c = cross_idx(k);
        intersections_x(k) = interp1(pol_velo([c c+1]), time_velo([c c+1]), threshold);
    end
 
    % ---------------------------------------------------------------------
    % motion on/offset per peak: nearest crossing before / after the peak
    % motion(p,:) = [onset_idx offset_idx] into intersections_x, NaN if
    % either side is missing or ambiguous (tied crossings)
    % ---------------------------------------------------------------------
    motion = NaN(numel(peak_times), 2);
    for p = 1:numel(peak_times)
        d        = peak_times(p) - intersections_x;
        d_before = d(d > 0);
        d_after  = d(d < 0);
        if isempty(d_before) || isempty(d_after)
            continue
        end
        onset  = find(d == min(d_before));
        offset = find(d == max(d_after));
        if isscalar(onset) && isscalar(offset)
            motion(p,:) = [onset offset];
        end
    end
 
    % onset times (offsets are computed above but not plotted)
    valid              = ~isnan(motion(:,1));
    motion_time        = NaN(size(motion,1), 1);
    motion_time(valid) = intersections_x(motion(valid,1));
 
    % ---------------------------------------------------------------------
    % plot
    % ---------------------------------------------------------------------
    maxy   = max([pol_velo pol_angle]);
    miny   = min([pol_velo pol_angle]);
    y_line = miny:maxy;   % y-values for the vertical onset lines
 
    figure(task)
    head_motion = plot(time_velo,  pol_velo,  'LineWidth', 3, 'Color', colorblind(11,:));
    hold on
    head_angle  = plot(time_angle, pol_angle, 'LineWidth', 3, 'Color', colorblind(12,:));
    axis tight
    yline(0, 'LineStyle', '-', 'LineWidth', 1.5, 'Color', 'k');
 
    % detected motion onsets
    motion_line = gobjects(size(motion,1), 1);
    for p = find(valid)'
        motion_line(p,1) = plot(repmat(motion_time(p), numel(y_line), 1), y_line, ...
            'Color', colorblind(13,:), 'LineWidth', 3, 'LineStyle', '--');
    end
 
    legend([head_motion, head_angle], {'head velocity', 'head angle'})
 
    % both y-axes share the same limits
    yRange = range(pol_velo);
    y_lims = [miny - 0.1*yRange, maxy + 0.1*yRange];
 
    ax = gca;
    yyaxis left
    ylabel('Velocity [deg/sec]');
    ylim(y_lims);
 
    yyaxis right
    ylabel('Head Angle [deg]');
    ax.YAxis(2).Color = 'k';
    ylim(y_lims);
 
    xlabel('time test [sec]')
    ax.FontSize = 16;

    % ---------------------------------------------------------------------
    % save figure
    % ---------------------------------------------------------------------
    fig_name = sprintf('sub-%02d_task-%s_desc-headmotionTrial%02d_plot', pp_num, task_name{task}, trl);
    savefig(gcf, fullfile(dir_fig_mat, [fig_name '.fig']));
    print(gcf, fullfile(dir_figures, [fig_name '.png']), '-dpng', '-r600');
end