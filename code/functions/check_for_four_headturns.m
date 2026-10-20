function trl_hd_info = check_for_four_headturns(data)

trl_hd_info = NaN(24,1);

for trl = 1:size(data.trialinfo,1) % loop over trials 
                       
%% extract head motion on/offsets (only the ones that are there, starting from first head motion!!!)

                try
                % get all motion on and offsets
                temp_hd                        = data.trialinfo{trl}.vel_motion_on_offsets; 
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
                       
% if there is all 4 peripheral head directions
        if size(temp_hd3,1)>=4           
            trl_id = data.trialinfo{trl}.trial;
            if data.trialinfo{trl}.run == 2 || data.trialinfo{trl}.run == 3
                trl_id = trl_id + 8 * (data.trialinfo{trl}.run - 1);
            end  
            trl_hd_info(trl) = trl_id;
        else 
           continue;  
        end   
        
end                
end