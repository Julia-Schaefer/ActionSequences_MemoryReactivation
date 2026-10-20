
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 1st &  2nd order RSA on the time vector of each channel separatly, WITHIN
% sequence encoding (bootstrapped, option to include head direction
% localizer data) and BETWEEN sequence encoding and retrieval tasks (no
% linear detrending of data necessary); specify the block size of
% vectorized correaltions in the 2nd order RSA in line 791
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clearvars 
close all
clc

%% paths (derived from the location of this script, which lies in <repo>/code)

this_file = mfilename('fullpath');
if isempty(this_file), this_file = fullfile(pwd, 'script'); end
dir_repo = fileparts(fileparts(this_file));
addpath(fullfile(dir_repo, 'code', 'functions'))

dir_fieldtrip = 'C:\path\to\fieldtrip';   % set once; ignored if FieldTrip is already on the path
if ~exist('ft_defaults', 'file'), addpath(dir_fieldtrip); end
ft_defaults;

dir_data       = fullfile(dir_repo, 'data', 'example_data');   % input
dir_results    = fullfile(dir_repo, 'data', 'example_data');   % output
if ~exist(dir_results, 'dir'), mkdir(dir_results); end

dir_figures = fullfile(dir_repo, 'results', 'figures', 'RSA');  % output: figures

%% define key variables

HD_train        = 1; % include HD localizer task in training data or not
pp_eeg          = 5:40;
task_oi_1st     = [2 4 6 9 14]; 
task_oi_1st_cut = [20 6 9]; % 20 merged & cut tasks
task_oi_2nd     = [20 6 9];
% define Ns
n_boot           = 50;
win1             = 0.4; % time window 1st order RSA (window: even decimal number/ continuous: 0)
win2             = 0.4; % time window 2nd order RSA (window: even decimal number/ continuous: 0)
time_step        = 0.1;
task_name        = {'Image', 'SeqEnc',[], 'SeqCheck','WM_Maint','WM_HD',[],'EM_recall','EM_HD',[],[],[],[],'HD',[],[],[],[],[],'merged training data'};

%% color palet

cmap = [
255,216 125; % Gelb
229, 158, 86; % Orange
189, 103, 96; % Rot 
147, 170, 205; % Blau
155, 154, 109; % Grün
0, 0, 0; % Schwarz 
255, 212, 211; % Pink
226, 147, 142; % Rose
255, 244, 207; % Beige
];
cmap = cmap/255;
  
% profile on -memory

%% loop over pp

tic
for i = 1:length(pp_eeg)
    
    first_RSA_data          = cell(1,max(task_oi_1st));
    first_RSA_data_no_boot  = cell(1,max(task_oi_1st));
    second_RSA_data         = cell(1,max(task_oi_1st));

    clearvars -except HD_train dir_data dir_results dir_func dir_tools pp_eeg i task_oi_1st dir_figures n_boot win1 win2 task_name cmap task_oi_2nd first_RSA_data first_RSA_data_no_boot second_RSA_data time_step task_oi_1st_cut
    
    % define participant number
    pp_num = pp_eeg(i);
    pp_str = sprintf('sub-%02.0f',pp_num);  

%% Load eeg data

    try
        fprintf(sprintf('load data pp %d', pp_num));
        load(sprintf('%s/%s/%s_data_final_hd_no_demean_detrend.mat',dir_data,pp_str,pp_str),'eeg_data_final'); 
        load(sprintf('%s/%s/pp-%02.0f_RSA_info.mat',dir_results,pp_str,pp_num),'RSA_info');
    catch 
        continue % continue with next pp
    end

%% drop channels

    cfg                         = [];
    cfg.channel                 = {'all','-event','-polhemus_angle_coordinates','-BIP*'};
    data_eeg                    = ft_selectdata(cfg,eeg_data_final);

%% downsample to 100Hz

    cfg             = [];
    cfg.resamplefs  = 100;
    data_final      = ft_resampledata(cfg, data_eeg); % resampled data 
    clear data_eeg

%% select task data & loop over tasks

    labels          = cell(1,max(task_oi_1st));
    signal_task     = cell(1,max(task_oi_1st)); 
    time_test_plot  = cell(1,max(task_oi_1st));
    time_train_plot = cell(1,max(task_oi_1st));

    segment_info_all        = cell(1,max(task_oi_1st));
    labels_cut              = cell(1,max(task_oi_1st));
    labels_pre_cut          = cell(1,max(task_oi_1st));
    labels_post_cut        = cell(1,max(task_oi_1st));
    pos_cut                = cell(1,max(task_oi_1st));
    HD_cut                  = cell(1,max(task_oi_1st));

    signal_task_cut  = cell(1,max(task_oi_1st));
    RSA_HD           = cell(1,max(task_oi_1st)); 
    signal_atHD      = cell(1,max(task_oi_1st)); 
    time_test_data   = cell(1,max(task_oi_1st)); 

    for task = task_oi_1st 

        fprintf(sprintf('run 1st order RSA task %d pp %d',task, pp_num)); 

        trl_idx = NaN(length(data_final.trial),1);   
        for c = 1: length(data_final.trial)
            if isequal(data_final.trialinfo{c}.task,task_name{task})
                trl_idx(c) = 1;
            else
                trl_idx(c) = 0;
            end
        end

        cfg         = [];
        cfg.trials  = find(trl_idx);
        eeg         = ft_selectdata(cfg, data_final);
        data        = eeg;   

%% prepare EEG signal

        % extract eeg signal in trials and concatenate it to a 3d structure (trials, 64 channels (incl. polhemus), time samples) 
        signal_shaped       = reshape(cell2mat(data.trial),[numel(data.label) numel(data.time{1}) numel(data.trial)]);
        signal_shaped       = permute(signal_shaped,[3 1 2]); 
        signal_task{task}   = signal_shaped;
        clear signal_shaped 

%% extract labels of all 4 categories 

        % training data images
        if task ==1 
            labels{task}  = cellfun(@(x) x.imCategory, data.trialinfo);

        % head turns   
         elseif task ==14 
            image_seq   = cellfun(@(x) x.HDSeq, data.trialinfo, 'UniformOutput', false);
            for trl = 1:length(image_seq)
                labels{task}(1,trl) = image_seq{trl}(1);
                labels{task}(2,trl) = image_seq{trl}(2);
                labels{task}(3,trl) = image_seq{trl}(3);
                labels{task}(4,trl) = image_seq{trl}(4);
            end

        % memory tasks    
        else 
            image_seq   = cellfun(@(x) x.ImagSeq, data.trialinfo, 'UniformOutput', false);
            for trl = 1:length(image_seq)
                labels{task}(1,trl) = image_seq{trl}(1);
                labels{task}(2,trl) = image_seq{trl}(2);
                labels{task}(3,trl) = image_seq{trl}(3);
                labels{task}(4,trl) = image_seq{trl}(4);
            end
        end
        
        % extract time all tasks
        time_test_data{task} = data.time{1};

%% Cut training data

        if task == 2 || task == 4 || task == 14

        % cut correlation values each trial into HD segments
        % clear overall structures
        RSA_time                   = -1.5:0.01:4;
        HD_time                    = time_test_data{task};
        lock                       = 1;

        % Prepare NaN structures
        RSA_HD            = NaN(size(signal_task{task},1),4);
        data_cut          = NaN(size(signal_task{task},1),4,size(signal_task{task},2),length(RSA_time));

        segment_info.trlID      = NaN(size(signal_task{task},1),4);
        segment_info.Pos        = NaN(size(signal_task{task},1),4);
        segment_info.class      = NaN(size(signal_task{task},1),4);
        segment_info.notclass   = NaN(size(signal_task{task},1),4,3);
        segment_info.HD         = NaN(size(signal_task{task},1),4);   
        segment_info.angle      = NaN(size(signal_task{task},1),4);
        segment_info.class_pre  = NaN(size(signal_task{task},1),4);
        segment_info.HD_pre     = NaN(size(signal_task{task},1),4);
        segment_info.class_post = NaN(size(signal_task{task},1),4);
        segment_info.HD_post    = NaN(size(signal_task{task},1),4);


            for trl = 1:size(signal_task{task},1) % loop over trials 

%% extract head motion on/offsets (only the ones that are there, starting from first head motion!!!)

                try
                    % get all motion on and offsets
                    temp_hd                        = RSA_info{task}.info.trialinfo{trl}.vel_motion_on_offsets; 
                    temp_hd1 = temp_hd(:,1);
                    temp_hd2 = temp_hd(:,2); 
                    temp_hd1                       = unique(temp_hd1, 'stable'); 
                    temp_hd2                       = unique(temp_hd2, 'stable');
                    temp_hd1(isnan(temp_hd1))      = [];
                    temp_hd2(isnan(temp_hd2))      = [];
                    temp_hd3                       = [temp_hd1 temp_hd2];  
                catch % if there are no timestamps at all  
                    continue;
                end   

                for Pos = 1:size(RSA_HD,2)            
                    % for each head tun try if on/ offset time is there
                    try
                        if lock == 1
                        % lock to checked onset
                            RSA_HD(trl,Pos)      = nearest(HD_time, temp_hd3(Pos,1));         
                        % lock to checked offset
                        elseif lock == 2
                            RSA_HD(trl,Pos)      = nearest(HD_time, temp_hd3(Pos,2));   
                        % lock to fix cross/ image onsets
                        elseif lock == 3
                           RSA_HD(trl,Pos)       = nearest(HD_time,data_HD.stim_onsets(trl,Pos));
                        end
                    catch  % if no on/ offset
                        RSA_HD(trl,Pos)         = NaN;
                        continue
                    end    
                end

%% loop over head directions that are valid

                % if there is all 4 peripheral head directions
                if sum(~isnan(RSA_HD(trl,1:4))) == 4 
                    if task ~= 14
                        class_HD             = RSA_info{task}.info.trialinfo{trl}.ImagSeq;   
                    else
                        class_HD             = RSA_info{task}.info.trialinfo{trl}.HDSeq;
                    end
                        HD_HD                = RSA_info{task}.info.trialinfo{trl}.HDSeq;

                    for Pos = 1:4

%% save segment information

                        % save trial identity of each segment
                        trlID_seg = RSA_info{task}.info.trialinfo{trl}.HDSeq;
                        % Concatenate the 4 numbers along the last dimension to form a 4-digit number
                        segment_info.trlID(trl,Pos) = trlID_seg(1)*1000 + trlID_seg(2)*100 + trlID_seg(3)*10 + trlID_seg(4);
                        % safe class and Position & HD info     
                        segment_info.Pos(trl,Pos)        = Pos;
                        segment_info.class(trl,Pos)      = class_HD(Pos);
                        segment_info.notclass(trl,Pos,:) = class_HD(~ismember(class_HD,class_HD(Pos)));
                        segment_info.HD(trl,Pos)         = HD_HD(Pos);

                        % get current HD on vector -2,-1,1,2
                        if segment_info.HD(trl,Pos) < 3
                            HD_curr                                  = segment_info.HD(trl,Pos)-3;
                        else
                            HD_curr                                  = segment_info.HD(trl,Pos)-2;
                        end 

                        % pre segment info
                        try
                            % class pre
                            segment_info.class_pre(trl,Pos)  = class_HD(Pos-1);
                            % HD pre
                            segment_info.HD_pre(trl,Pos)     = HD_HD(Pos-1);
                            % get pre HD on vector -2,-1,1,2
                            if segment_info.HD_pre(trl,Pos) < 3
                                HD_pre                              = segment_info.HD_pre(trl,Pos)-3;
                            else
                                HD_pre                              = segment_info.HD_pre(trl,Pos)-2;
                            end

                            % difference pre HD and current HD (angle travelled)         
                            segment_info.angle(trl,Pos)      = HD_curr-HD_pre;

                        catch
                        end

                        % post segment info
                        try
                            segment_info.class_post(trl,Pos) = class_HD(Pos+1);
                            segment_info.HD_post(trl,Pos)    = HD_HD(Pos+1);
                        catch
                        end

%% get rval of all classes at current head turn 

                        time_test_select       = RSA_HD(trl,Pos)-100*abs(RSA_time(1)):RSA_HD(trl,Pos)+100*abs(RSA_time(end));
                        % check which timepoints are in the data
                        valid_toi = ismember(time_test_select,1:length(HD_time));
                        % snippet of current head turn 
                        % trl x Pos x chan x time test
                        data_cut(trl,Pos,:,valid_toi) = squeeze(signal_task{task}(trl,:,time_test_select(valid_toi)));  

                    end   
                else % in case of not all four HD present, trial gets not filled
                end
            end

%% reshape all data and segment info

        segment_info_all{task}.trlID      = reshape(segment_info.trlID,size(segment_info.trlID,1)*size(segment_info.trlID,2),1);
        segment_info_all{task}.class      = reshape(segment_info.class,size(segment_info.class,1)*size(segment_info.class,2),1);
        segment_info_all{task}.class_post = reshape(segment_info.class_post,size(segment_info.class_post,1)*size(segment_info.class_post,2),1);
        segment_info_all{task}.class_pre  = reshape(segment_info.class_pre,size(segment_info.class_pre,1)*size(segment_info.class_pre,2),1);
        segment_info_all{task}.notclass   = reshape(segment_info.notclass,size(segment_info.class,1)*size(segment_info.notclass,2),3);
        segment_info_all{task}.Pos        = reshape(segment_info.Pos,size(segment_info.Pos,1)*size(segment_info.Pos,2),1);
        segment_info_all{task}.HD         = reshape(segment_info.HD,size(segment_info.HD,1)*size(segment_info.HD,2),1);
        segment_info_all{task}.angle      = reshape(segment_info.angle,size(segment_info.angle,1)*size(segment_info.angle,2),1);
        segment_info_all{task}.HD_pre     = reshape(segment_info.HD_pre,size(segment_info.HD_pre,1)*size(segment_info.HD_pre,2),1);
        segment_info_all{task}.HD_post    = reshape(segment_info.HD_post,size(segment_info.HD_post,1)*size(segment_info.HD_post,2),1);

%% save labels

        labels_cut{task}        = segment_info_all{task}.class;
        labels_pre_cut{task}    = segment_info_all{task}.class_pre;
        labels_post_cut{task}   = segment_info_all{task}.class_post;
        pos_cut{task}           = segment_info_all{task}.Pos;
        HD_cut{task}            = segment_info_all{task}.HD;

        time_data_cut       = RSA_time;
        % reshape HD data (concatenate positions (across trials))        
        signal_task_cut{task}  = reshape(data_cut,size(data_cut,1)*size(data_cut,2),size(data_cut,3),size(data_cut,4));

        else

        labels_cut{task} = labels{task};
        signal_task_cut{task} = signal_task{task};

        end

    end

%% merge encoding and sequence check

    % merged task = 20
    signal_task_cut{20}     = [signal_task_cut{2}; signal_task_cut{4}];
    labels_cut{20}          = [labels_cut{2}; labels_cut{4}];
    labels_pre_cut{20}      = [labels_pre_cut{2}; labels_pre_cut{4}];
    labels_post_cut{20}     = [labels_post_cut{2}; labels_post_cut{4}];
    pos_cut{20}             = [pos_cut{2}; pos_cut{4}];
    HD_cut{20}              = [HD_cut{2}; HD_cut{4}];

%% include head direction trials

    if HD_train == 1
    % select 24 random trials per HD from the HD task (balance No. of trials per HD)
    % check how many trials per class and make sure that the overall number of
    % fix cross trials is the same, by balancing the hd within the trial
    % selection
    trial_No    = round(histcounts(labels_cut{20})/4);
    task        = 14;

    HD_select_all = NaN(4,trial_No(1));
    for HD_select = 1:4
        % all indices of one HD
        temp = find(labels_cut{task} == HD_select);
        % random set of trials 
        temp1 = randperm(length(temp));
        % select random set of trials
        HD_select_all(HD_select,:) = temp(temp1(1:trial_No(1)));
    end

    % create new label: 5 for fixation cross
    labels_cut_HD_balanced      = ones(trial_No(1)*4,1)*5;
    signal_task_cut_balanced    = signal_task_cut{task}(HD_select_all(:),:,:);

    %% merge encoding & sequence check with HD task
    labels_cut{20}      = [labels_cut{20}; labels_cut_HD_balanced];
    signal_task_cut{20} = [signal_task_cut{20}; signal_task_cut_balanced]; 

    end

%% within and cross classification by RSA

    for task = task_oi_1st_cut

        % get rid of NaN trials
        nan_seg = isnan(labels_cut{task});
        signal_task_cut{task}(nan_seg,:,:)  = [];
        labels_cut{task}(nan_seg)           = [];    

        if task == 20 && HD_train == 0
            labels_pre_cut{task}(nan_seg)       = [];   
            labels_post_cut{task}(nan_seg)      = [];
            pos_cut{task}(nan_seg)              = [];
            HD_cut{task}(nan_seg)               = [];
        end


    %% define time of interest

        if task == 20 % train 
            time_train              = time_data_cut;
            time_test               = time_data_cut;
            toi_te(1)               = nearest(time_train,RSA_time(1)+win1/2);
            toi_te(2)               = nearest(time_train,RSA_time(end)-win1/2);
            time_train_plot{task}   = time_train(toi_te(1):toi_te(2));
            time_test_plot{task}    = time_test(toi_te(1):toi_te(2));
        else 
            time_test               = time_test_data{task};
            toi_te(1)               = nearest(time_test,-1.2);
            toi_te(2)               = nearest(time_test,17.5);
            time_train_plot{task}   = time_train_plot{20};
            time_test_plot{task}    = time_test(toi_te(1):toi_te(2));
        end

        n_time_train    = length(time_train_plot{task}(1):time_step:time_train_plot{task}(end));
        n_time_test     = length(time_test_plot{task}(1):time_step:time_test_plot{task}(end));
        n_channels      = 63; % dont count polhemus channel


%% prep training data

        % find number of classes
        n_class = length(histcounts(labels_cut{20}));

        % select balanced number of all classes for training data
            indices     = cell(1,n_class);
            indices_sum = NaN(1,n_class);
            for num = 1:n_class
                indices{num}        = find(labels_cut{20} == num); % Find indices of each class
                indices_sum(num)    = sum(labels_cut{20} == num); % how many of each class?
            end
            min_idx     = min(indices_sum); % min number of each class

        % precompute sample indices for bootstrap
        if task == 20 % image X image       
            test_no     = floor(min_idx/3); % get 1/3 for test trials
            train_no    = floor(min_idx/3)*2; % get 2/3 for train trials     

            test_idx  = zeros(n_boot,n_class * test_no);
            train_idx = zeros(n_boot,n_class * train_no);

            for boot =1:n_boot   
                test_idx_temp  = zeros(n_class * test_no,1);
                train_idx_temp = zeros(n_class * train_no,1);

                    for num = 1:n_class
                        class_indices   = indices{num};  % Vector of indices for class `num`
                        rand_order      = randperm(length(class_indices));  % One random permutation

                        % Select test and train indices
                        test_range      = (num-1)*test_no + (1:test_no);
                        train_range     = (num-1)*train_no + (1:train_no);

                        % store in varibale
                        test_idx_temp(test_range)    = class_indices(rand_order(1:test_no));
                        train_idx_temp(train_range)  = class_indices(rand_order(test_no+1:test_no+train_no));

                    end
                test_idx(boot,:)    = sort(test_idx_temp);
                train_idx(boot,:)   = sort(train_idx_temp);
            end
        else  % image x other task 

            % take whole localizer data for training, balance classes
            train_idx = [];
            for num = 1:n_class 
            train_idx = [train_idx; indices{num}(randperm(length(indices{num}),min_idx))];
            end    
            train_idx = sort(train_idx);

        end

%% ranked z-scored training and test trials

        % trainings task
        data_sliced_train               = slice_data(signal_task_cut{20},time_train,time_train_plot{20}(1), time_train_plot{20}(end),win1,time_step,0,1);
        % extract polhemus data
        polhemus_data_train             = squeeze(mean(data_sliced_train(:,end,:,:),4));
        % get rid of polhemus channel 
        data_sliced_train(:,end,:,:)    = [];
        % rank order along feature dimension
        class_trials_train_rank_z       = ranked_z_data(data_sliced_train);
        clear data_sliced_train
        % bring into shape for bootstrap
        % channels, trls,  time , time slice
        class_trials_train_rank_z       = permute(class_trials_train_rank_z,[2,1,3,4]);

        % other tasks
        if task ~= 20
            data_sliced_test            = slice_data(signal_task_cut{task},time_test,time_test_plot{task}(1), time_test_plot{task}(end),win1,time_step,0,1);
            % extract polhemus data
            polhemus_data               = squeeze(mean(data_sliced_test(:,end,:,:),4));
            % get rid of polhemus channel 
            data_sliced_test(:,end,:,:) = [];
            % rank order along feature dimension
            class_trials_test_rank_z    = ranked_z_data(data_sliced_test);
            clear data_sliced_test
            % bring into shape for bootstrap
            % channels, trls,  time, 1 , time slice
             class_trials_test_rank_z   = permute(class_trials_test_rank_z,[2,1,3,4]);
        end

%% within and cross classification by RSA

        % for within task -> bootstrap
        first_RSA_data{task}.R_val                  = [];
        first_RSA_data{task}.motion_data_angle      = [];
        first_RSA_data{task}.motion_data_velocity   = [];
        first_RSA_data{task}.test_label_1st         = [];

        if task == 20    
            for boot = 1:n_boot
                % select train and test data (within both from train data)       
                test_data_ranked        = class_trials_train_rank_z(:,test_idx(boot,:),:,:);
                train_data_ranked       = class_trials_train_rank_z(:,train_idx(boot,:),:,:);
                test_label              = labels_cut{task}(test_idx(boot,:));
                train_label             = labels_cut{task}(train_idx(boot,:)); 

                % save additional bootstrapped info for later bias check
                if task == 20 && HD_train == 0
                    first_RSA_data{task}.train_labels_pre_1st(boot,:,:)     = labels_pre_cut{task}(train_idx(boot,:));
                    first_RSA_data{task}.test_labels_pre_1st(boot,:,:)      = labels_pre_cut{task}(test_idx(boot,:));
                    first_RSA_data{task}.train_labels_post_1st(boot,:,:)    = labels_post_cut{task}(train_idx(boot,:));
                    first_RSA_data{task}.test_labels_post_1st(boot,:,:)     = labels_post_cut{task}(test_idx(boot,:));
                    first_RSA_data{task}.train_pos_1st(boot,:,:)            = pos_cut{task}(train_idx(boot,:));
                    first_RSA_data{task}.test_pos_1st(boot,:,:)             = pos_cut{task}(test_idx(boot,:));
                    first_RSA_data{task}.train_HD_1st(boot,:,:)             = HD_cut{task}(train_idx(boot,:));
                    first_RSA_data{task}.test_HD_1st(boot,:,:)              = HD_cut{task}(test_idx(boot,:));
                end

                % Compute RSA-> dim: bootsampl,channels,class,trial,time test, time train  
                size_test                                           = size(test_data_ranked);
                test_data_ranked                                    = reshape(test_data_ranked,size_test(1),size_test(2),size_test(3),1,size_test(4));
                % channels, trls,  1, time, time slice
                size_train                                          = size(train_data_ranked);
                train_data_ranked                                   = reshape(train_data_ranked,size_train(1),size_train(2),1,size_train(3),size_train(4)); 

                % boots, channels x class x trials x test time x train time
                first_RSA_data{task}.R_val(boot,:,:,:,:,:)          = get_Rval(train_data_ranked, test_data_ranked,n_class,train_label,0,1);

               if size(first_RSA_data{20}.R_val,3) ~= n_class
                error('class dim wrong');
               end

                clear train_data_ranked test_data_ranked

                % bootstrap polhemus
                first_RSA_data{task}.motion_data_angle(boot,:,:)     = polhemus_data_train(test_idx(boot,:),:);
                % first derivation/ sampling rate in sec
                first_RSA_data{task}.motion_data_velocity(boot,:,:)  = diff(polhemus_data_train(test_idx(boot,:),:),1,2)/0.1;
                % labels bootstrap
                first_RSA_data{task}.test_label_1st(boot,:,:)            = test_label;
                first_RSA_data{task}.train_label_1st(boot,:,:)           = train_label;
            end

        else 
            % select train and test data       
            test_data_ranked        = class_trials_test_rank_z;
            clear class_trials_test_rank_z
            train_data_ranked       = class_trials_train_rank_z(:,train_idx,:,:);
            clear class_trials_train_rank_z
            test_label              = labels_cut{task};
            train_label             = labels_cut{20}(train_idx);  

            % Compute RSA -> dim: channels,class,trial,time test, time train 
            % channels, trls,  time, 1 , time slice
            size_test                                      = size(test_data_ranked);
            test_data_ranked                               = reshape(test_data_ranked,size_test(1),size_test(2),size_test(3),1,size_test(4));
            % channels, trls,  1, time, time slice
            size_train                                     = size(train_data_ranked);
            train_data_ranked                              = reshape(train_data_ranked,size_train(1),size_train(2),1,size_train(3),size_train(4));  
            % channels x class x trials x test time x train time
            first_RSA_data{task}.R_val                     = get_Rval(train_data_ranked, test_data_ranked,n_class,train_label,0,1);
            clear train_data_ranked test_data_ranked

            % bootstrap polhemus
            first_RSA_data{task}.motion_data_angle     = polhemus_data;
            % first derivation/ sampling rate in sec
            first_RSA_data{task}.motion_data_velocity  = diff(polhemus_data,1,2)/0.1;
            % labels bootstrap
            first_RSA_data{task}.test_label_1st            = test_label;
        end

        % create structure with variables
        first_RSA_data{task}.ppID        = pp_num;
        first_RSA_data{task}.time_test   = time_test_plot{task}(1):time_step:time_test_plot{task}(end);
        first_RSA_data{task}.time_train  = time_train_plot{task}(1):time_step:time_train_plot{task}(end);

    %% add RSA info for every subject, realign trial onsets to head motion onsets for all non cut tasks

    if task ~= 20

        % save org cut data
        first_RSA_data{task}.R_val_org                 = first_RSA_data{task}.R_val;
        first_RSA_data{task}.motion_data_angle_org     = first_RSA_data{task}.motion_data_angle;
        first_RSA_data{task}.motion_data_velocity_org  = first_RSA_data{task}.motion_data_velocity;
        first_RSA_data{task}.time_test_org             = first_RSA_data{task}.time_test;

        % take same time as in 1st order RSA
        time_train_plot{task}   = time_train_plot{20};
        time_test_plot{task}    = -1.2:time_step:17.5;

        duration        = size(time_test_plot{task},2);  % Get the maximum size

        % add trialinfo
        for trl = 1:length(RSA_info{task}.info.trialinfo)      
            first_RSA_data{task}.info.trialinfo{trl} = RSA_info{task}.info.trialinfo{trl};  
        end  
        
        % re-align all tasks to image onset or onset of first fixation cross       
       % define org. trigger value
       if task == 6
           trig = 23;
       elseif task == 9
           trig = 43;
       elseif task ==14
           trig = 43;
       end

        % prapare structures for new cut data
        first_RSA_data{task}.R_val                 = NaN(size(first_RSA_data{task}.R_val_org,1),size(first_RSA_data{task}.R_val_org,2),size(first_RSA_data{task}.R_val_org,3),duration,size(first_RSA_data{task}.R_val_org,5));
        first_RSA_data{task}.motion_data_angle     = NaN(size(first_RSA_data{task}.motion_data_angle_org,1),duration);
        first_RSA_data{task}.motion_data_velocity  = NaN(size(first_RSA_data{task}.motion_data_velocity_org,1),duration);
        first_RSA_data{task}.time_test             = NaN(size(first_RSA_data{task}.time_test,1),duration);
        first_RSA_data{task}.motion_on_offsets     = [];

        onset_oi_samp     = NaN(length(RSA_info{task}.info.trialinfo));
        periph_fix_onset  = NaN(length(RSA_info{task}.info.trialinfo),4);

        for trl = 1:length(RSA_info{task}.info.trialinfo)  
            
            % find onsets of first peripheral fixation cross/ Image onset
            % and recut the trial
            % find sample of fix onset
            periph_fix_sample               = find(RSA_info{task}.info.trial{trl}(1,:)==trig);

            % get timepoint of fix/image onset
            if task == 6 || task == 9
                periph_fix_onset(trl,:)   = RSA_info{task}.info.time{trl}(periph_fix_sample(2:5));
            else
                periph_fix_onset(trl,:)   = RSA_info{task}.info.time{trl}(periph_fix_sample(1:4));
            end

            % get baseline period in RSA data, make it longer to compenssate for cut data 
            baseline_oi                     = abs(first_RSA_data{task}.time_test_org(1))+0.5;
            % find nearest timepoint to fix onset minus baseline
            onset_oi_samp(trl)              = nearest(first_RSA_data{task}.time_test_org,periph_fix_onset(trl,1)-baseline_oi);
            % subtract first stim onset from all stim onsets to get
            % timepoints in new time axes
            first_RSA_data{task}.stim_onsets(trl,:)     = periph_fix_onset(trl,:) - periph_fix_onset(trl,1);

            % lock data to new timepoint (timpoint-baseline till defined overall duration of trial)   
            length_new_lock                                                        = size(first_RSA_data{task}.R_val_org(:,:,trl,onset_oi_samp(trl):end,:),4);
            first_RSA_data{task}.R_val(:,:,trl,1:length_new_lock,:)                = first_RSA_data{task}.R_val_org(:,:,trl,onset_oi_samp(trl):end,:);
            first_RSA_data{task}.motion_data_angle(trl,1:length_new_lock)          = first_RSA_data{task}.motion_data_angle_org(trl,onset_oi_samp(trl):end);
            first_RSA_data{task}.motion_data_velocity(trl,1:length_new_lock-1)     = first_RSA_data{task}.motion_data_velocity_org(trl,onset_oi_samp(trl):end);

            % subtract the time reset from head motion on and offsets         
            try
                % get all motion on and offsets
                temp_hd                        = RSA_info{task}.info.trialinfo{trl}.vel_motion_on_offsets; 
                temp_hd1                       = temp_hd(:,1);
                temp_hd2                       = temp_hd(:,2); 
                temp_hd1                       = unique(temp_hd1, 'stable'); 
                temp_hd2                       = unique(temp_hd2, 'stable');
                temp_hd1(isnan(temp_hd1))      = [];
                temp_hd2(isnan(temp_hd2))      = [];
                temp_hd3                       = [temp_hd1 temp_hd2]; 
            catch
                temp_hd3 = NaN;
            end
            first_RSA_data{task}.motion_on_offsets{trl}                        = temp_hd3-periph_fix_onset(trl,1);
        end

        % adjust time axis(cut to new size and subtract the lag)
        length_new_lock_time                                               = length(first_RSA_data{task}.time_test_org(round(median(onset_oi_samp)):end));
        first_RSA_data{task}.time_test(1:length_new_lock_time)             = first_RSA_data{task}.time_test_org(round(median(onset_oi_samp)):end)-round(median(periph_fix_onset(:,1),1),1);

        % sanity check
        if first_RSA_data{task}.time_test(1) == first_RSA_data{task}.time_test_org(1)-0.5
        else
            error('Re-aligning went wrong at task %d subject %d',task,i)
        end   

        % take original uncut time of encoding after sanity check
        % from the pp with the longets duration in the self paced
        % tasks
        first_RSA_data{task}.time_test = time_test_plot{task}(1)-0.5:time_step:time_test_plot{task}(end)-0.5;

        % delete org cut data
        first_RSA_data{task} = rmfield(first_RSA_data{task},'R_val_org');
        first_RSA_data{task} = rmfield(first_RSA_data{task},'motion_data_angle_org');
        first_RSA_data{task} = rmfield(first_RSA_data{task},'motion_data_velocity_org');
        first_RSA_data{task} = rmfield(first_RSA_data{task},'time_test_org');

        if size(first_RSA_data{20}.R_val,3) ~= n_class
          error('class dim wrong');
        end

    end

    %% save for writing to disc

        if task ~= 20 
            first_RSA_data_no_boot{task} = first_RSA_data{task};
        else % for bootstrapped within training task   
            
            first_RSA_data_no_boot{task} = first_RSA_data{task};

            % to compute the mean (all bootstraps have the same
            % number of trials): use indexing and average over all concatenated
            % trials rather than mean within bootstraps and then across
            % flatten data across trial dimension (stack all trials of one bootstrap on
            % top of all other bootstraps)

            % labels
            % dim: boot, trials
            size_label          = size(first_RSA_data_no_boot{task}.test_label_1st);
            data_flat_labels    = reshape(first_RSA_data_no_boot{task}.test_label_1st,size_label(1)*size_label(2),1);

            % R_vals
            % dim: boot, channel, train class, trials, time test, time train
            % into: boot, trials, channel, train class, time test, time train
            data_flat_Rval                      = permute(first_RSA_data_no_boot{task}.R_val,[1,4,2,3,5,6]);
            size_Rval                           = size(data_flat_Rval);
            % concatenate boots and trials
            data_flat_Rval                      = reshape(data_flat_Rval,size_Rval(1)*size_Rval(2),size_Rval(3),size_Rval(4),size_Rval(5),size_Rval(6));

            % average over same class trials for all bootstrap samples
            % dim: channel, test class, train class, time test, time train
            data_Rval       = NaN(size_Rval(3), n_class, size_Rval(4), size_Rval(5), size_Rval(6));

            for cl = 1:n_class
                data_Rval(:,cl,:,:,:)   = squeeze(mean(data_flat_Rval(data_flat_labels==cl,:,:,:,:)));
            end

            first_RSA_data_no_boot{task}.R_val                    = data_Rval;
        end

    end

%% save PDF plot for every pp

    count = 0;
    for task = task_oi_1st_cut 
    figure(1)
    count = count + 1;
    subplot(1,3,count)
        if task == 20
            plot_data           = squeeze(mean(first_RSA_data_no_boot{task}.R_val,[1 2 3],'omitnan')); % channel, test class, train class, time bins test, time bins train
            plot2D_RSA(first_RSA_data_no_boot{task}.time_test,first_RSA_data_no_boot{task}.time_train,plot_data',0,'time test [sec]', 'time training [sec]','R vals')
            hold on
            % plot head velocity mean across trials, with standard error
            plot1D_RSA(squeeze(mean(abs(first_RSA_data_no_boot{task}.motion_data_velocity),1))*0.05,first_RSA_data_no_boot{task}.time_test(1:end-1), cmap(7,:))
            title(task_name{task});       
        else 
            plot_data           = squeeze(mean(first_RSA_data_no_boot{task}.R_val,[1 2 3],'omitnan')); % channels, classes, test trials, time bins test, time bins train
            plot2D_RSA(first_RSA_data_no_boot{task}.time_test,first_RSA_data_no_boot{task}.time_train,plot_data',0,'time test [sec]', 'time training [sec]','R vals')
            hold on
            % plot head velocity mean across trials, with standard error
            plot1D_RSA(abs(first_RSA_data_no_boot{task}.motion_data_velocity)*0.05,first_RSA_data_no_boot{task}.time_test(1:end), cmap(7,:))
            title(task_name{task});
        end
    end

%% Create a new PDF file

    fprintf(sprintf('save PDFs pp %d', pp_num));
    savePlotAsPdf([sprintf('pp-%02.0f',pp_num) '_EncCheckHD_train_chan_1st_order_RSA_400'],dir_figures,figure(1))
    % savePlotAsPdf([sprintf('pp-%02.0f',pp_num) '_EncCheck_train_chan_1st_order_RSA_400'],dir_figures,figure(1))
    close all

%% save 1st order RSA 
    save(sprintf('%s/sub-%02.0f/pp-%02.0f_RSA_data_EncCheckHD_train_chan_1st_order_RSA_400.mat',dir_results,pp_num,pp_num),'first_RSA_data_no_boot','-v7.3');
    % save(sprintf('%s/sub-%02.0f/pp-%02.0f_RSA_data_EncCheck_train_chan_1st_order_RSA_400.mat',dir_results,pp_num,pp_num),'first_RSA_data_no_boot','-v7.3');

    clearvars -except HD_train dir_data dir_results dir_func dir_tools pp_eeg i first_RSA_data task_oi_1st dir_figures task_name cmap task_oi_2nd pp_num second_RSA_data time_step win1 win2 n_class task_oi_1st_cut

%% transfer data

    second_RSA_data = first_RSA_data; 
    % make memory space
    clear first_RSA_data

%% 2nd order RSA (bootstrapped for training data)

    block_size                    = 3;
    n_boot                        = size(second_RSA_data{20}.R_val,1); % get nboots from training data size
    count = 0;
    
    for task = task_oi_2nd  
        
        fprintf(sprintf('run 2nd order RSA task %d pp %d',task, pp_num));

        % set parameters 
        time_train                    = second_RSA_data{task}.time_test; 
        sample_Intv                   = time_train(2)-time_train(1);

        if task == 20
            
%% get min number of trials per class for preallocation (same number for each boot)

            indices_sum = NaN(1,n_class);
            for num = 1:n_class
                indices_sum(num)    = sum(second_RSA_data{task}.test_label_1st(1,:) == num); % how many of each class?
            end
            min_idx     = min(indices_sum); % min number of each class               
            test_no     = floor(min_idx/3); % get 1/3 for test trials
            train_no    = floor(min_idx/3)*2; % get 2/3 for train trials    
            test_idx    = zeros(n_boot,n_class * test_no,1);
            train_idx   = zeros(n_boot,n_class * train_no,1);

            % get train and test indices
            for boot = 1:n_boot 
                indices     = cell(1,n_class);
                for num = 1:n_class
                    indices{num}        = find(second_RSA_data{task}.test_label_1st(boot,:) == num); % Find indices of each class
                end

                test_idx_temp  = zeros(n_class * test_no,1);
                train_idx_temp = zeros(n_class * train_no,1);

                for num = 1:n_class
                    class_indices   = indices{num};  % Vector of indices for class `num`
                    rand_order      = randperm(length(class_indices));  % One random permutation
                    % Select test and train indices
                    test_range      = (num-1)*test_no + (1:test_no);
                    train_range     = (num-1)*train_no + (1:train_no);
                    % store in varibale
                    test_idx_temp(test_range)    = class_indices(rand_order(1:test_no));                  
                    train_idx_temp(train_range)  = class_indices(rand_order(test_no+1:test_no+train_no));    
                end

                 test_idx(boot,:)    = sort(test_idx_temp);
                 train_idx(boot,:)   = sort(train_idx_temp);
            end
            
       
%% taking out overall RSA pattern over all training classes
            
            second_RSA_data{task}.R_val                       = squeeze(second_RSA_data{task}.R_val-mean(second_RSA_data{task}.R_val,3,'omitnan'));  
            % bring future feature dims to the back into: 
            % trials x boots x test time  x train class x train time x channels
            second_RSA_data{task}.R_val                       = permute(second_RSA_data{task}.R_val,[4,1,5,3,6,2]);
            
%% loop over boot chunks

            size_corr = size(second_RSA_data{task}.R_val);
            % preallocate: class x trials x test time x train time x boot  
            temp_corr_tXt               = NaN(size_corr(4),size(test_idx,2),size_corr(3)-round(win2/sample_Intv),size_corr(5)-round(win2/sample_Intv),n_boot); 
            test_label                  = NaN(n_boot,size(test_idx,2));
            class_trials_train_rank_z   = NaN(size_corr(1),n_boot,size_corr(3)-round(win2/sample_Intv),size_corr(4)*size_corr(5)*size_corr(6)*round((win2/sample_Intv)+1));
            
            for b = 1:block_size:n_boot
                
                idx = b : min(b + block_size - 1, n_boot);
                % data test time slices 
                data_sliced_train       = slice_data(second_RSA_data{task}.R_val(:,idx,:,:,:,:),time_train,time_train(1)+win2/2, time_train(end)-win2/2,win2,time_step,1,2);
                % trl x boots x train time (former test) x features    
                class_trials_train_rank_z(:,idx,:,:)       = ranked_z_data(data_sliced_train);
                clear data_sliced_train
       
                % trials, boots,time test, features (class train x time
                % train x channel)
                size_data                   = size(class_trials_train_rank_z(:,idx,:,:));
                train_label_boot            = NaN(size_data(2),size(train_idx,2));
                train_data                  = NaN(size(train_idx,2),size_data(3),size_data(4),size_data(2));
                test_data                   = NaN(size(test_idx,2),size_data(3),size_data(4),size_data(2));
                train_data_class            = NaN(4,size_data(3),size_data(4),size_data(2));
            
                % for bootstrapping condition get class mean before Rval function
                % loop within bootstrap chunk
                ic = 0;
                for boot = 1:size(idx,2)
                    ic = ic +1;
                    test_label(idx(boot),:)            = second_RSA_data{task}.test_label_1st(idx(boot),test_idx(idx(boot),:));
                    train_label_boot(ic,:)             = second_RSA_data{task}.test_label_1st(idx(boot),train_idx(idx(boot),:)); 
                    test_data(:,:,:,ic)                = class_trials_train_rank_z(test_idx(idx(boot),:),idx(boot),:,:);  
                    train_data(:,:,:,ic)               = class_trials_train_rank_z(train_idx(idx(boot),:),idx(boot),:,:);
                    for cl = 1:n_class
                        train_data_class(cl,:,:,ic) = squeeze(mean(train_data(train_label_boot(ic,:)== cl,:,:,ic),1));
                    end 
                end
                clear train_data train_label_boot

                %% reshape test and train data (trials/ mean over class trials, time, features (time train x
                % channels x class train)) by adding an additional dimension to
                % compute the inner dot product (each timepoint in the training
                % data with each timepoint in the test data and each class with each trial)
                size_test           = size(test_data);
                size_train          = size(train_data_class);
                test_data           = reshape(test_data,size_test(1),size_test(2),1,size_test(3),size_test(4));
                train_data_class    = reshape(train_data_class,size_train(1),1,size_train(2),size_train(3),size_train(4));

                % get Rvals, 0 indicates no labels in bootstrapping condition 
                % output: class x trials x test time x train time x boot
                temp_corr_tXt(:,:,:,:,idx) = get_Rval(train_data_class, test_data,n_class,0,1,2);
                clear train_data_class test_data
            end  
            
             second_RSA_data{task}.R_val             = temp_corr_tXt;
             second_RSA_data{task}.test_label_2nd    = test_label;
             
            % prep for other tasks:
            % take average of ranked and zscored training data for each
            % class and each bootstrap then average acorss bootstraps 
            train_data_ranked_class_boot = NaN(n_class, size(class_trials_train_rank_z,2),size(class_trials_train_rank_z,3),size(class_trials_train_rank_z,4));
            for boot = 1:n_boot 
                for c = 1:n_class
                    class_temp        = find(second_RSA_data{20}.test_label_1st(boot,:) == c); % Find indices of each class
                     % mean class trials, boots, time test (training data), features (slice x class train x time train x channel)
                    train_data_ranked_class_boot(c,boot,:,:) = squeeze(mean(class_trials_train_rank_z(class_temp,boot,:,:),1));
                end
            end           
            train_data_ranked_class = squeeze(mean(train_data_ranked_class_boot,2));
            size_train                  = size(train_data_ranked_class);
            train_data_ranked_class     = reshape(train_data_ranked_class,size_train(1),1,size_train(2),size_train(3));
            clear train_data_ranked_class_boot class_trials_train_rank_z

        else
            
            % taking out overall RSA pattern over all training classes in
            % test data
            second_RSA_data{task}.R_val           = squeeze(second_RSA_data{task}.R_val-mean(second_RSA_data{task}.R_val,2,'omitnan'));     
            % bring future feature dims to the back: trls x time test x class x time train x chan
            second_RSA_data{task}.R_val           = permute(second_RSA_data{task}.R_val,[3,4,2,5,1]);
            % data test time slices
            data_sliced_test    = slice_data(second_RSA_data{task}.R_val,time_train,time_train(1)+win2/2, time_train(end)-win2/2,win2,time_step,0,2);

            % rank test data across features, trl x test time x features (within slice data: window
            % size*train classes*train time*channels
            trials_test_rank_z             = ranked_z_data(data_sliced_test);
            clear data_sliced_test
                  
            % reshape test and train data (trials/ mean over class trials, time, features (time train x
            % channels x class train)) by adding an additional dimension to
            % compute the inner dot product (each timepoint in the training
            % data with each timepoint in the test data and each class with each trial)
            size_test                   = size(trials_test_rank_z);
            trials_test_rank_z          = reshape(trials_test_rank_z,size_test(1),size_test(2),1,size_test(3));
            
            % get Rvals, 0 indicates no labels in bootstrapping condition 
            % class x trials x test time x train time 
            % overwrite old Rval
            second_RSA_data{task}.R_val      = get_Rval(train_data_ranked_class, trials_test_rank_z,n_class,0,0,2);
            clear trials_test_rank_z
      
        end
        
%% adapt time and velocity if win2 is not 0

    if win2 ~= 0
        second_RSA_data{task}.time_train = second_RSA_data{task}.time_train(1+(win2/sample_Intv)/2:end-(win2/sample_Intv)/2);
        second_RSA_data{task}.time_test = second_RSA_data{task}.time_test(1+(win2/sample_Intv)/2:end-(win2/sample_Intv)/2);
        if task == 20
            second_RSA_data{task}.motion_data_velocity = second_RSA_data{task}.motion_data_velocity(:,:,1+(win2/sample_Intv)/2:end-(win2/sample_Intv)/2);
            second_RSA_data{task}.motion_data_angle = second_RSA_data{task}.motion_data_angle(:,:,1+(win2/sample_Intv)/2:end-(win2/sample_Intv)/2); 
        else
            second_RSA_data{task}.motion_data_velocity = second_RSA_data{task}.motion_data_velocity(:,1+(win2/sample_Intv)/2:end-(win2/sample_Intv)/2);
            second_RSA_data{task}.motion_data_angle = second_RSA_data{task}.motion_data_angle(:,1+(win2/sample_Intv)/2:end-(win2/sample_Intv)/2);  
        end
    end
        
%% save PDF plot for every pp

    figure(2)  
        if task == 20
            count = count + 1;
            subplot(2,4,count)
            plot_data           = squeeze(mean(second_RSA_data{task}.R_val,[1 2 5],'omitnan')); % train class, trials time bins test, time bins train, boots
            plot2D_RSA(second_RSA_data{task}.time_test,second_RSA_data{task}.time_train,plot_data',0,'time test [sec]', 'time training [sec]','R vals')
            hold on
            % plot head velocity mean across trials, with standard error
            plot1D_RSA(squeeze(mean(abs(second_RSA_data{task}.motion_data_velocity),1))*0.05,second_RSA_data{task}.time_test(1:end-1), cmap(7,:))
            title(task_name{task});       
        else 
            count = count + 1;
            subplot(2,4,count)
            plot_data           = squeeze(mean(second_RSA_data{task}.R_val,[1 2],'omitnan')); % train class, trials time bins test, time bins train, boots
            plot2D_RSA(second_RSA_data{task}.time_test,second_RSA_data{task}.time_train,plot_data',0,'time test [sec]', 'time training [sec]','R vals')
            hold on
            % plot head velocity mean across trials, with standard error
            plot1D_RSA(abs(second_RSA_data{task}.motion_data_velocity)*0.05,second_RSA_data{task}.time_test,cmap(7,:))
            title(task_name{task});
        end
        
    end
    
%% Create a new PDF file

     fprintf(sprintf('save PDFs pp %d', pp_num));
      savePlotAsPdf([sprintf('pp-%02.0f',pp_num) '_EncCheckHD_train_chan_2nd_order_RSA_400'],dir_figures,figure(2))
%       savePlotAsPdf([sprintf('pp-%02.0f',pp_num) '_EncCheck_train_chan_2nd_order_RSA_400'],dir_figures,figure(2))
     close all
    
%% safe 2nd order RSA data

    save(sprintf('%s/sub-%02.0f/pp-%02.0f_RSA_data_EncCheckHD_train_chan_2nd_order_RSA_400.mat',dir_results,pp_num,pp_num),'second_RSA_data','-v7.3');
    % save(sprintf('%s/sub-%02.0f/pp-%02.0f_RSA_data_EncCheck_train_chan_2nd_order_RSA_400.mat',dir_results,pp_num,pp_num),'second_RSA_data','-v7.3');
   
end
toc

% profile off
% p = profile('info');
% profile viewer
