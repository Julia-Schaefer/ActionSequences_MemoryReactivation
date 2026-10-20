function [RSA_atHD, velocity, segment_info] = HD_segment_data(RSA_time, lock, data)

% lock = 1/2/3 HD onset/ HD offset/ image onset
% RSA_time = desired segment size

n_class                  = size(data.R_val,1);
% Perpare NaN structures
% subj x trl x Pos x class train x time test x time train
RSA_atHD          = NaN(24,4,n_class,length(RSA_time),size(data.R_val,4));
velocity          = NaN(24,4,length(RSA_time));
RSA_HD            = NaN(size(data.R_val,2),4);

%             trlID_seg = data.info.trialinfo{trl}.HDSeq;
%             segment_info{i,task}.trlID(trl,1:4)      = trlID_seg(1)*1000 + trlID_seg(2)*100 + trlID_seg(3)*10 + trlID_seg(4);
            segment_info.trlID      = NaN(24,4);
            segment_info.Pos        = NaN(24,4);
            segment_info.class      = NaN(24,4);
            segment_info.notclass   = NaN(24,4,3);
            segment_info.HD         = NaN(24,4);   
            segment_info.angle      = NaN(24,4);
            segment_info.class_pre  = NaN(24,4);
            segment_info.HD_pre     = NaN(24,4);
            segment_info.class_post = NaN(24,4);
            segment_info.HD_post    = NaN(24,4);
            segment_info.perform    = NaN(24,4);

        for trl = 1:size(data.R_val,2) % loop over trials 
            
            
%% extract head motion on/offsets (only the ones that are there, starting from first head motion!!!)

                try
                % get all motion on and offsets
                temp_hd                        = data.motion_on_offsets{trl}; 
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
                            RSA_HD(trl,Pos)      = nearest(data.time_test, temp_hd3(Pos,1));         
                    % lock to checked offset
                        elseif lock == 2
                            RSA_HD(trl,Pos)      = nearest(data.time_test, temp_hd3(Pos,2));   
                    % lock to fix cross/ image onsets
                        elseif lock == 3
                           RSA_HD(trl,Pos)       = nearest(data.time_test,data.stim_onsets(trl,Pos));
                        end
                        % check if all 4 head turns have enough baseline time
                        % (pre and post)
%                         if RSA_HD(trl,Pos) < length(data.time_test)-10*abs(RSA_time(end)) && RSA_HD(trl,Pos) > 10*abs(RSA_time(1))
%                         else % continue with next Pos                                                 
%                         RSA_HD(trl,Pos) = NaN;
%                         continue;
%                         end
                catch % if no on/ offset
                    RSA_HD(trl,Pos)         = NaN;
                    continue
                end    
            end

%% loop over head directions that are valid

% if there is all 4 peripheral head directions
        if sum(~isnan(RSA_HD(trl,1:4)))==4 
              class_HD             = data.test_label_1st(:,trl)';
%              class_HD             = data.test_label(:,trl)';
            % sanity check 
            if sum(class_HD  == data.info.trialinfo{trl}.ImagSeq) == 4
                segment_info.perform(trl,:) = data.info.trialinfo{trl}.Performance_parts;
            else
                error('class mismatch')
            end

            for Pos = 1:4
                
%% save segment information

                % save trial identity of each segment 
                if data.info.trialinfo{trl}.run == 1
                    segment_info.trlID(trl,Pos) = data.info.trialinfo{trl}.trial;
                elseif data.info.trialinfo{trl}.run == 2
                    segment_info.trlID(trl,Pos) = data.info.trialinfo{trl}.trial+8;
                elseif data.info.trialinfo{trl}.run == 3
                     segment_info.trlID(trl,Pos) = data.info.trialinfo{trl}.trial+16;
                end

%                 trlID_seg = data.info.trialinfo{trl}.HDSeq;
%                 % Concatenate the 4 numbers along the last dimension to form a 4-digit number
%                 segment_info.trlID(trl,Pos) = trlID_seg(1)*1000 + trlID_seg(2)*100 + trlID_seg(3)*10 + trlID_seg(4);

                % safe class and Position & HD info     
                segment_info.Pos(trl,Pos)        = Pos;
                segment_info.class(trl,Pos)      = class_HD(Pos);
                segment_info.notclass(trl,Pos,:) = class_HD(~ismember(class_HD,class_HD(Pos)));
                segment_info.HD(trl,Pos)         = data.info.trialinfo{trl}.HDSeq(Pos);
                
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
                    segment_info.HD_pre(trl,Pos)     = data.info.trialinfo{1, trl}.HDSeq(Pos-1);
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
                    segment_info.HD_post(trl,Pos)    = data.info.trialinfo{1, trl}.HDSeq(Pos+1);
                catch
                end
                
%% get rval of all classes at current head turn 

                time_test_select       = RSA_HD(trl,Pos)-10*abs(RSA_time(1)):RSA_HD(trl,Pos)+10*abs(RSA_time(end));
                % check which timepoints are in the data
                valid_toi = ismember(time_test_select,1:length(data.time_test));
                
                % truncate velocity
                vel_temp = data.motion_data_velocity(:,ismember(data.time_test,data.time_test));

                % snippet of current head turn 
                % data_corr = class train x trl x time test x time train
                % RSA_atHD = subj x trl x Pos x class train x time
                % test, time train
                % test
                % fill only valid timpoints from the data, leave the rest
                % filled with NaNs
                 RSA_atHD(trl,Pos,:,valid_toi,:) = squeeze(data.R_val(:,trl,time_test_select(valid_toi),:));
                 velocity(trl,Pos,valid_toi)   = vel_temp(trl,time_test_select(valid_toi));
%                 RSA_atHD(trl,Pos,:,1:length(time_test_select),:) = squeeze(data.R_val(:,trl,time_test_select,:)); 
%                 velocity(trl,Pos,1:length(time_test_select),:)   = vel_temp(trl,time_test_select);
            
            end   
        else % in case of not all four HD present, trial gets not filled
        end
        end
end


