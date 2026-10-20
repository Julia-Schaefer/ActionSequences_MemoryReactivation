   
function data_sliced = slice_data(data,time_axis, time_loop_start,time_loop_stop,win,output_interval,if_boot,RSA_order)

% data:            data structure for each channel with dim
%                       trials, selected channel, time of interest, (other dim such as train class or
%                       train time)
% time_axis:            time axis for time of interest
% time_loop_start/stop: timpoints to start and stop the RSA computation
% n_sliding_window:     number of samples within window
% win:                  window size in metric of time axis (e.g. ms) or 0 (no window but
%                       timeXtime computation
% if_boot:              bootstrapping dimension as input?
% RSA_order:            order of RSA

sampling_interval   = (time_axis(2)-time_axis(1));
output_timeaxis     = time_loop_start:output_interval:time_loop_stop;
n_output_timeaxis   = length(output_timeaxis);
n_sliding_window    = round(win/sampling_interval,1)+1;

     
%% 1st oder RSA, no bootstrap: trls x chan x time
     
  if if_boot == 0 && RSA_order == 1
      
    data_sliced   = NaN(size(data,1),size(data,2),n_output_timeaxis,n_sliding_window);    
    cc=0;
    % loop over training time
    for t_train = output_timeaxis        
         cc = cc+1;  
         rsa_t = zeros(1,2);
         rsa_t(1)       = nearest(time_axis,t_train - win/2);
         rsa_t(2)       = nearest(time_axis,t_train + win/2); 
         % if there is not enough time left for win, fill NaN template
         % with only available data
         fill_data      = (rsa_t(2)-rsa_t(1))+1;
         
         if win ~= 0 % for window approach 
            data_sliced(:,:,cc,1:fill_data) = data(:,:,rsa_t(1):rsa_t(2));
         else % for contiuous approach
            data_sliced(:,:,cc,:) = data(:,:,rsa_t(1));
         end
               
     end
      
     %% 2nd order RSA, bootstrap: trls x boot x time test x class x time train x channels (2nd order bootstrap)
     
     elseif if_boot == 1 && RSA_order == 2 
         
        data_sliced     = NaN(size(data,1),size(data,2),n_output_timeaxis,n_sliding_window,size(data,4),size(data,5),size(data,6));
         
        cc=0;
        for t_train = output_timeaxis         
             cc = cc+1;  
             rsa_t = zeros(1,2);
             rsa_t(1)       = nearest(time_axis,t_train - win/2);
             rsa_t(2)       = nearest(time_axis,t_train + win/2);
             fill_data      = (rsa_t(2)-rsa_t(1))+1;
             
             if win ~= 0 % for window approach 
                data_sliced(:,:,cc,1:fill_data,:,:,:) = data(:,:,rsa_t(1):rsa_t(2),:,:,:);
             else % for contiuous approach
                data_sliced(:,:,cc,:,:,:,:) = data(:,:,rsa_t(1),:,:,:);
             end       
        end
        
        data_sliced = reshape(data_sliced,size(data,1),size(data,2),n_output_timeaxis,[]);
     
     %% 2nd order RSA, no bootstrap: trls x time test x class x time train x chan
     
     elseif if_boot == 0 && RSA_order == 2 
         
        data_sliced     = NaN(size(data,1),n_output_timeaxis,n_sliding_window,size(data,3),size(data,4),size(data,5));
         
        cc=0;
        for t_train = output_timeaxis     
             cc = cc+1;  
             rsa_t = zeros(1,2);
             rsa_t(1)       = nearest(time_axis,t_train - win/2);
             rsa_t(2)       = nearest(time_axis,t_train + win/2); 
             fill_data      = (rsa_t(2)-rsa_t(1))+1;

             if win ~= 0 % for window approach 
                data_sliced(:,cc,1:fill_data,:,:,:) = data(:,rsa_t(1):rsa_t(2),:,:,:);
             else % for contiuous approach
                data_sliced(:,cc,:,:,:,:) = data(:,rsa_t(1),:,:,:);
             end
        end
        
        data_sliced = reshape(data_sliced,size(data,1),n_output_timeaxis,[]);

   end
end


