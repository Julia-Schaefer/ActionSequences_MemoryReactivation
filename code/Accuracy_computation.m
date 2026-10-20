%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Compute accuracy for the action-sequence learning task, the action-sequence
% retrieval task, remembered and forgotten segments, and training with HD
% training data, based on 2nd-order encoding-trained RSA data
%
% Input  : 2nd-order RSA per participant 
% Output (data/accuracy/): desc-accuracy_results.mat  (results + info)
%                          desc-accuracy_results.json (BIDS sidecar: content, dimensions, units)
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

dir_fieldtrip = 'C:\Users\ra98jas\Documents\Julia_GitHub\Toolboxes\fieldtrip';   % set once; ignored if FieldTrip is already on the path
if ~exist('ft_defaults', 'file'), addpath(dir_fieldtrip); end
ft_defaults;

% example run
dir_rsa           = fullfile(dir_repo, 'data', 'example_data'); % input raw eeg                       
dir_results       = fullfile(dir_repo, 'data', 'example_data');   % output

if ~exist(dir_results, 'dir'), mkdir(dir_results); end
 
%% settings
% full run
% pp_eeg = 1:40;

% example run
pp_eeg = 1:2;
 
% 2-D Gaussian kernel used to smooth all accuracy maps
kernelSize = 2;
sigma      = 1;
[x, y]     = meshgrid(-floor(kernelSize/2):floor(kernelSize/2));
gKernel    = exp(-(x.^2 + y.^2) / (2*sigma^2));
gKernel    = gKernel / sum(gKernel(:));   % normalise
 
%% compute accuracy without (Hd_acc = 1) and with (Hd_acc = 2) HD control
 
% preallocate: rows = task, columns = without / with HD
acc_2D          = cell(20,2);
head_velocity = cell(20,2);
file_tag          = {'EncCheck', 'EncCheckHD'};   % file name part: without / with HD control
participants      = cell(1,2);                    % included participants per HD condition (sub-XX)
train_class       = {};                          % training labels (learning, without HD control only): class per trial
train_hd          = {};                          % training labels (learning, without HD control only): head direction per trial
 
for Hd_acc = 1:2
 
    %% load 2nd-order RSA
    rsa_data = cell(length(pp_eeg), 20);
    for i = 1:numel(pp_eeg) 
        try
            pp_num = pp_eeg(i);
            fprintf('load data pp %d', pp_num);
            load(sprintf('%s/pp-%02.0f_RSA_data_%s_train_chan_2nd_order_RSA_400.mat', ...
                dir_rsa, pp_num, file_tag{Hd_acc}), 'second_RSA_data');
%             load(sprintf('%s/sub-%02.0f/pp-%02.0f_RSA_data_%s_train_chan_2nd_order_RSA_400.mat', ...
%                 dir_rsa, pp_num, pp_num, file_tag{Hd_acc}), 'second_RSA_data');
        catch
            continue   % missing participant -> row stays empty
        end
        rsa_data(i, [9 20]) = second_RSA_data([9 20]);   % keep only the tasks used here (retrieval, learning)
        clear second_RSA_data                             % free the memory of all other tasks
    end
    loaded = ~all(cellfun(@isempty, rsa_data), 2);                 % participants with data
    participants{Hd_acc} = arrayfun(@(p) sprintf('sub-%02d', p), pp_eeg(loaded), 'UniformOutput', false);
    rsa_data(~loaded, :) = [];                                     % drop missing participants
    pp_loaded = pp_eeg(loaded);   % participant numbers in the row order of rsa_data
    nSub = size(rsa_data, 1);

    % training labels of the learning task (for the class x head-direction bias check);
    % only the data without HD control contain these labels
    if Hd_acc == 1
        train_class = cell(nSub, 1);
        train_hd    = cell(nSub, 1);
        for i = 1:nSub
            train_class{i} = rsa_data{i,20}.train_label_1st;   % as stored (incl. bootstrap structure)
            train_hd{i}    = rsa_data{i,20}.train_HD_1st;
        end
    end
 
    %% accuracy action sequence learning task (bootstrapped)
    task    = 20; % learning
    n_class = size(rsa_data{1,task}.R_val, 1);
    vec     = 1:n_class;
 
    % array sizes from the first participant
    R1    = rsa_data{1,task};
    nT1   = size(R1.R_val, 3);
    nT2   = size(R1.R_val, 4);
    nBoot = size(R1.R_val, 5);
 
    acc_2D{task,Hd_acc}          = NaN(nSub, n_class, nT1, nT2, nBoot);
    head_velocity{task,Hd_acc} = NaN(nSub, n_class, size(R1.motion_data_velocity, 3), nBoot);
    conf_mat_tXt                   = NaN(nSub, n_class, n_class, nT1, nT2, nBoot);
    accuracy_tXt                   = NaN(nSub, n_class, nT1, nT2, nBoot);
 
    for i = 1:nSub
        D = rsa_data{i,task};
 
        for boot = 1:size(D.R_val, 5)
            labels = D.test_label_2nd(boot,:);
 
            % decoded class = training class with the maximum correlation, per trial
            [maxval, decoded_class] = max(squeeze(D.R_val(:,:,:,:,boot)), [], 1, 'omitnan');
 
            % remove NaN trials (bootstraps with fewer trials): NaN at all time points
            nan_trls = squeeze(mean(isnan(maxval), [3 4]) == 1);
            decoded_class(:,nan_trls,:,:,:) = [];
            decoded_class = squeeze(decoded_class);
 
            for cl = 1:n_class
                is_cl = labels == cl; % trials with true cl class
                % decoded class of cl trials
                temp = decoded_class(is_cl,:,:);
                % confusion matrix: N trials of test class cl predicted as
                % class conf, per time point (test class x predicted class x time)
                for conf = 1:n_class
                    conf_mat_tXt(i,cl,conf,:,:,boot) = squeeze(sum(temp == conf));
                end
            end
 
            for cl = 1:n_class
                % ratio of class cl correctly predicted on class-cl trials minus
                % ratio of cl being predicted on all other trials
                accuracy_tXt(i,cl,:,:,boot) = squeeze(conf_mat_tXt(i,cl,cl,:,:,boot)/sum(labels==cl) ...
                    - sum(conf_mat_tXt(i,vec~=cl,cl,:,:,boot),2)/sum(labels~=cl));
 
                % mean absolute velocity over trials of class cl
                head_velocity{task,Hd_acc}(i,cl,:,boot) = mean(abs(squeeze(D.motion_data_velocity(boot, D.test_label_1st(boot,:)==cl, :))));
            end
 
            % smooth 2-D accuracy
            for cl = 1:n_class
                acc_2D{task,Hd_acc}(i,cl,:,:,boot) = conv2(squeeze(accuracy_tXt(i,cl,:,:,boot)), gKernel, 'same');
            end
        end
    end
 
    %% accuracy action sequence retrieval task
    
    segment_info = cell(nSub, 20);
    task         = 9; % retrieval
    seg_time     = -1:0.1:3;
    n_class      = size(rsa_data{1,task}.R_val, 1);
    nTrainT      = size(rsa_data{1,task}.R_val, 4);
 
    % subj x trl x pos x train class x test time x train time
    RSA_atHD = NaN(nSub, 24, 4, n_class, length(seg_time), nTrainT);
    % subj x trl x pos x test time 
    velocity = NaN(nSub, 24, 4, length(seg_time));
    for i = 1:nSub
        [RSA_atHD(i,:,:,:,:,:), velocity(i,:,:,:), segment_info{i,task}] = ...
            HD_segment_data(seg_time, 1, rsa_data{i,task});
    end
  
    % head velocity per class (subj x class x time)
    head_velocity{task,Hd_acc} = NaN(nSub, n_class, length(seg_time));
    for i = 1:nSub
        v   = reshape(abs(velocity(i,:,:,:)), 24*4, []);   % segments x time
        cls = segment_info{i,task}.class(:);          % class of each segment
        for cl = 1:n_class
            head_velocity{task,Hd_acc}(i,cl,:) = mean(v(cls == cl,:), 1, 'omitnan');
        end
    end 
    
    % compute confusion matrix
    conf_mat               = NaN(nSub, 4, n_class, n_class, length(seg_time), nTrainT);
    class_freq             = NaN(nSub, 4, n_class);
    size_acc               = size(RSA_atHD);
    accuracy_all_pos       = NaN([nSub, size_acc(4:6)]);
    acc_2D{task,Hd_acc}  = [];
 
    for i = 1:nSub
        for pos = 1:4
            % decoded class = training class with the maximum correlation, per trial
            [maxval, decoded_class] = max(RSA_atHD(i,:,pos,:,:,:), [], 4, 'omitnan');
 
            % remove NaN trials (fewer segments)
            nan_trls = mean(isnan(maxval), [1 3 4 5 6]) == 1;
            decoded_class(:,nan_trls,:,:,:,:) = [];
            decoded_class = squeeze(decoded_class);
 
            % true class after segmentation, NaNs removed
            true_class = segment_info{i,task}.class(:,pos);
            true_class(isnan(true_class),:) = [];
 
            try
                class_freq(i,pos,1:4) = histcounts(true_class);
            catch
                continue
            end
 
            vec = 1:n_class;
            for cl = 1:n_class
                % confusion matrix: N trials of test class cl predicted as class conf
                % (test class x predicted class x test time x train time)
                temp = decoded_class(true_class==cl,:,:);
                for conf = 1:n_class
                    conf_mat(i,pos,cl,conf,:,:) = sum(temp == conf, 1);
                end
            end
        end
 
        % accuracy per class across all positions: correct predictions minus
        % false positives of that class. Requires >= 5 segments of each class;
        for cl = 1:n_class
            if ~(sum(class_freq(i,:,cl),2) < 5)
                accuracy_all_pos(i,cl,:,:) = squeeze(sum(conf_mat(i,:,cl,cl,:,:),2,'omitnan')/sum(class_freq(i,:,cl),2,'omitnan') ...
                    - sum(conf_mat(i,:,vec~=cl,cl,:,:),[2 3],'omitnan')/sum(class_freq(i,:,vec~=cl),[2 3],'omitnan'));
            end
        end
 
        % smooth 2-D accuracy
        for cl = 1:n_class
            acc_2D{task,Hd_acc}(i,cl,:,:) = conv2(squeeze(accuracy_all_pos(i,cl,:,:)), gKernel, 'same');
        end
    end
 
%% accuracy HD segments separately for remembered and forgotten (bootstrap)
 
if Hd_acc == 1
    
seg_time           = -1:0.1:3;
task               = 9; % retrieval
n_class            = 4;
boot_count         = 0;
n_valid_boots       = 20000;   % valid bootstraps per participant
pp_nan_boots       = cell(length(n_valid_boots));
acc_memory = cell(length(n_valid_boots), 4, 20);
seed = 42; 
 
for boot_lim = n_valid_boots
 
    boot_count      = boot_count + 1;
    n_boot          = boot_lim*3;   % max. attempts (bootstraps with a missing class are skipped)
 
    % RSA_atHD (subj x trl x pos x class x test time x train time) and
    % segment_info come from the retrieval section above: same data, same seg_time
    assert(isequal(size(RSA_atHD), [nSub, 24, 4, n_class, length(seg_time), size(rsa_data{1,task}.R_val,4)]), ...
        'RSA_atHD from the retrieval section does not match the bootstrap settings');
    
    pp_nan_boots{boot_count} = NaN(2, 9, size(RSA_atHD,1));
 
    count_perf_boot        = NaN(nSub, n_boot, 2, 4);
    size_acc               = size(RSA_atHD);
    accuracy_all_pos       = NaN([nSub, size_acc(5:6)]);
 
    % performance per subject and position (same for both conditions)
    performance_all = NaN(nSub, 4, 24);
    for i = 1:nSub
        for pos = 1:4
            performance_all(i,pos,:) = segment_info{i,task}.perform(:,pos);
        end
    end
 
    %% remembered vs. forgotten
    for perf = 1:2   % 1 = forgotten (performance 0), 2 = remembered (performance 1)
 
        acc_memory{boot_count,perf,task} = NaN([nSub, size_acc(5:6)]);
        TPR         = NaN(nSub, size(RSA_atHD,3), size(RSA_atHD,5), size(RSA_atHD,6));
        FPR         = NaN(nSub, size(RSA_atHD,3), size(RSA_atHD,5), size(RSA_atHD,6));
        class_count = NaN(nSub, 4);
 
        for i = 1:nSub
 
            conf_mat = NaN(n_class, n_class, size(RSA_atHD,5), size(RSA_atHD,6));
 
            % stack trials and positions:
            % subj x trl x pos x class x test time x train time
            %   -> class x test time x train time x (trials & positions)
            Acc_all_pos        = squeeze(reshape(permute(RSA_atHD(i,:,:,:,:,:), [1 4 5 6 2 3]), 1,4,41,48,[]));
            Perf_all_pos       = squeeze(reshape(permute(performance_all(i,:,:), [1 3 2]), 1,[]));
            true_class_all_pos = segment_info{i,task}.class(:);
 
            % decoded class = training class with the maximum correlation, per segment
            [maxval, decoded_class] = max(Acc_all_pos, [], 1, 'omitnan');
 
            % remove NaN segments
            nan_trls = mean(isnan(maxval), [1 2 3]) == 1;
            decoded_class(:,:,:,nan_trls) = [];
            decoded_class = squeeze(decoded_class);
            Perf_all_pos(nan_trls) = [];
            true_class_all_pos(isnan(true_class_all_pos),:) = [];
 
            % sanity check
            if length(true_class_all_pos) ~= length(Perf_all_pos)
                error('trial No does not match')
            end
 
            idx_hit  = find(Perf_all_pos == 1);
            idx_miss = find(Perf_all_pos == 0);
            [trl_min, perf_idx] = min([length(idx_miss), length(idx_hit)]);   % perf_idx = condition with fewer trials
 
            idx_oi_all = find(Perf_all_pos == perf-1);
 
            count   = 0;
            acc_sum = zeros(length(seg_time), size(rsa_data{1,task}.R_val,4));   % running sum over valid bootstraps

            % smaller condition: every bootstrap uses all trials (no random draw),
            % so all bootstraps are identical -> compute once
            deterministic = (perf == perf_idx);
            n_iter        = n_boot;
            if deterministic, n_iter = 1; end

            % own random stream per participant and condition -> independent of which other participants run
            rng(seed + 1000*pp_loaded(i) + perf)
            for boot = 1:n_iter
 
                if perf ~= perf_idx
                    % larger condition: subsample to the trial number of the smaller one
                    shuffle_idx_oi = idx_oi_all(randperm(length(idx_oi_all)));
                    idx_oi   = shuffle_idx_oi(1:trl_min);
                    pred_sub = decoded_class(:,:,idx_oi);
                    true_sub = true_class_all_pos(idx_oi);
                else
                    pred_sub = decoded_class(:,:,idx_oi_all);
                    true_sub = true_class_all_pos(idx_oi_all);
                end
 
                % confusion matrix: true class x predicted class x test time x train time
                for cl = 1:n_class
                    class_count(i,cl) = sum(true_sub == cl);
                    trials_cl = pred_sub(:,:,true_sub == cl);
                    for pred_cl = 1:n_class
                        conf_mat(cl,pred_cl,:,:) = sum(trials_cl == pred_cl, 3);   % sum over trials
                    end
                end
                count_perf_boot(i,boot,perf,:) = class_count(i,:);
 
                % skip this bootstrap if any class has no trial
                if any(class_count(i,:) < 1)
                    continue
                end
 
                % TPR = true positives / N trials of the class
                % FPR = false positives / N trials of all other classes
                for cl = 1:n_class
                    other_cl      = setdiff(1:n_class, cl);
                    TPR(i,cl,:,:) = squeeze(conf_mat(cl,cl,:,:)) ./ class_count(i,cl);
                    FPR(i,cl,:,:) = squeeze(sum(conf_mat(other_cl,cl,:,:),1)) ./ sum(class_count(i,other_cl),2);
                end
 
                acc_sum = acc_sum + squeeze(mean(TPR(i,:,:,:),2,'omitnan') - mean(FPR(i,:,:,:),2,'omitnan'));
 
                % stop once boot_lim valid bootstraps are reached (same number for all participants)
                count = count + 1;
                if count == boot_lim
                    break
                end
            end
 
            n_summed = count;   % number of bootstraps added up in acc_sum

            % smaller condition: bookkeeping as if all identical bootstraps had been run
            if deterministic
                n_rep = boot_lim;                   % valid: boot_lim identical bootstraps
                if count == 0, n_rep = n_boot; end  % a class is missing: every bootstrap skipped
                count_perf_boot(i,1:n_rep,perf,:) = repmat(count_perf_boot(i,1,perf,:), 1, n_rep);
                if count == 1, count = boot_lim; end
            end

            pp_nan_boots{boot_count}(perf,task,i) = count;
            if count == n_boot
                error('check No of boots')
            end

            % accuracy of this participant and condition:
            % fewer than boot_lim valid bootstraps -> NaN (no mean over fewer bootstraps),
            % otherwise the mean over the valid bootstraps
            if count < boot_lim
                accuracy_all_pos(i,:,:) = NaN;
            else
                accuracy_all_pos(i,:,:) = acc_sum / n_summed;
            end
 
            % smooth 2-D accuracy
            acc_memory{boot_count,perf,task}(i,:,:) = conv2(squeeze(accuracy_all_pos(i,:,:)), gKernel, 'same');
        end
    end
end
 
%% head velocity for remembered vs. forgotten segments
head_velocity_rem  = cell(1,9);
head_velocity_forg = cell(1,9);
    for i = 1:nSub
        % velocity + segment_info from the retrieval section (same data, same seg_time)
        velocity_flat        = reshape(abs(velocity(i,:,:,:)), [], length(seg_time));   % segments x time
        perform_flat         = segment_info{i,task}.perform(:);
        head_velocity_rem{task}(i,:)  = mean(velocity_flat(perform_flat==1,:), 1, 'omitnan');
        head_velocity_forg{task}(i,:) = mean(velocity_flat(perform_flat==0,:), 1, 'omitnan');
    end
 
end
end

%% collect results: accuracy + matching head velocity per data set
% learning / retrieval: {1} without HD control, {2} with HD control
results.learning.accuracy  = acc_2D(20,:);          % subj x class x test time x train time x boot
results.learning.velocity  = head_velocity(20,:);   % subj x class x time x boot
results.retrieval.accuracy = acc_2D(9,:);           % subj x class x test time x train time
results.retrieval.velocity = head_velocity(9,:);    % subj x class x time
% memory (without HD control): accuracy{b,1} forgotten, accuracy{b,2} remembered
% (b = entry of n_valid_boots); velocity{1} forgotten, velocity{2} remembered
results.memory.accuracy    = reshape(acc_memory(:,1:2,9), [], 2);            % subj x test time x train time
results.memory.velocity    = {head_velocity_forg{9}, head_velocity_rem{9}};   % subj x time
% training labels of the learning task (without HD control only; the HD-control
% data contain no training labels): one cell per participant (order of info.participants)
results.learning.train_class = train_class;
results.learning.train_hd    = train_hd;

%% info: bootstraps, time axes and labels
info.n_valid_boots        = n_valid_boots;               % valid bootstraps per participant (memory)
info.n_boot_learning      = nBoot;                       % bootstraps of the learning data
info.seg_time             = seg_time;                    % test time of the HD segments (retrieval, memory) [s]
info.time_test_learning   = rsa_data{1,20}.time_test;    % [s]
info.time_train_learning  = rsa_data{1,20}.time_train;   % [s]
info.time_train_retrieval = rsa_data{1,9}.time_train;    % [s]
info.hd_condition         = {'without HD control', 'with HD control'};
info.memory_condition     = {'forgotten', 'remembered'};
info.rng_seed             = seed;                        % seed of the memory bootstrap

% participants: row order of all subject dimensions (must be identical with/without HD control)
assert(isequal(participants{1}, participants{2}), ...
    'Different participants with and without HD control - noHD/withHD contrast would be unpaired');
info.participants         = participants{1};

%% save results for the plot script

% save(fullfile(dir_results, 'desc-accuracy_results.mat'), 'results', 'info', '-v7.3');   % full, stays local

% mean over bootstraps where applicable
res_full = results;
for h = 1:2
    assert(~any(any(isnan(res_full.learning.accuracy{h}),5) & ~all(isnan(res_full.learning.accuracy{h}),5), 'all'), 'HD cond %d: some bootstraps are NaN in accuracy, a plain mean would differ from omitnan', h);
    results.learning.accuracy{h} = mean(res_full.learning.accuracy{h}, 5, 'omitnan');              
    results.learning.velocity{h} = mean(res_full.learning.velocity{h}, 4, 'omitnan');
end
info.summary = 'learning accuracy and velocity averaged over bootstraps';
fname = 'desc-accuracy_results';
save(fullfile(dir_results, [fname '.mat']), 'results', 'info', '-v7');

%% BIDS JSON sidecar

sidecar.Description  = ['Decoding accuracy and head velocity (learning, retrieval, memory), with and without HD control. ' ...
    'Learning data averaged over bootstraps'];
sidecar.Sources      = {'2nd-order RSA, encoding-check training (EncCheck / EncCheckHD)'};
sidecar.GeneratedBy  = struct('Name', 'Accuracy_computation.m', 'Date', datestr(now, 'yyyy-mm-dd'));
sidecar.Dimensions   = struct( ...
    'learning_accuracy',  'subject x class x test time x train time (mean over bootstraps)', ...
    'learning_velocity',  'subject x class x time (mean over bootstraps)', ...
    'retrieval_accuracy', 'subject x class x test time x train time', ...
    'retrieval_velocity', 'subject x class x time', ...
    'memory_accuracy',    'subject x test time x train time', ...
    'memory_velocity',    'subject x time', ...
    'learning_train_labels', 'without HD control, per participant: class / head-direction label per training trial, as in the RSA data');
sidecar.Units        = struct('accuracy', 'hit rate - false-alarm rate', 'velocity', 'deg/s', 'time', 's');
sidecar.RandomSeed   = info.rng_seed;
sidecar.Participants = info.participants;

fid = fopen(fullfile(dir_results, [fname '.json']), 'w');
fprintf(fid, '%s', jsonencode(sidecar));   % one line ('PrettyPrint' needs R2021a+)
fclose(fid);