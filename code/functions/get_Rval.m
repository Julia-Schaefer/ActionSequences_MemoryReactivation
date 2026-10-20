function R_val = get_Rval(train_data_ranked, test_data_ranked,n_class,train_label,if_boot,RSA_order)

% train_data_ranked
% test_data_ranked
% n_class
% train_label
% Rval preallocation (NaN)
% if_boot
% RSA_order

size_test     = size(test_data_ranked);
size_train    = size(train_data_ranked);

    %% 1st order incl. channels, no bootstrap: trls, 1/time/1, features
    if if_boot == 0 && RSA_order == 0 
       
        R_val                     = NaN(n_class,size_test(1),size_test(2),size_train(3));
        
        % get trials of one class (averaging after the rank order is a speed
        % version of trlxtrl correlation
        train_data_ranked_class    = NaN(n_class,size_train(2),size_train(3),size_train(4));
        for c = 1:n_class
            % class, 1, time, features
            train_data_ranked_class(c,:,:,:) = mean(train_data_ranked(train_label==c,:,:,:),1);
        end
         
        % loop over classes
          for c = 1:n_class                           
             % inner dot product
             % class, trials, time test, time train 
             R_val(c,:,:,:)        = mean(test_data_ranked.*train_data_ranked_class(c,:,:,:),4,'omitnan'); % The correlation coefficient is the average cross- product of z-scores 
          end


    %% 1st order RSA, no bootstrap: channels x trls x 1/time/1 x time slice 
    
    elseif if_boot == 0 && RSA_order == 1 
       
        R_val                     = NaN(size_test(1), n_class,size_test(2),size_test(3),size_train(4));
        
        % get trials of one class (averaging after the rank order is a speed
        % version of trlxtrl correlation
        train_data_ranked_class    = NaN(size_train(1),n_class,size_train(3),size_train(4),size_train(5));
        for c = 1:n_class
            % channels,class, 1, time, time slice
            train_data_ranked_class(:,c,:,:,:) = mean(train_data_ranked(:,train_label==c,:,:,:),2);
        end
         
        % loop over classes
          for c = 1:n_class                           
             % inner dot product
             % channels, class, trials, time test, time train 
             R_val(:,c,:,:,:)        = mean(test_data_ranked.*train_data_ranked_class(:,c,:,:,:),5,'omitnan'); % The correlation coefficient is the average cross- product of z-scores 
          end

    %% 2nd order RSA, bootstrap:
    
   elseif if_boot == 1 && RSA_order == 2   

         R_val                 = NaN(n_class,size_test(1),size_test(2),size_train(3),size_test(5));
          
          % loop over classes
          for c = 1:n_class 
%               for trial_b = 1:trial_block:size_test(2)
%                idx = trial_b : min(trial_b + trial_block - 1, size_test(2));
%                 % inner dot product
                 % class, trials, time test, time train, boots 
                 R_val(c,:,:,:,:)        = mean(test_data_ranked(:,:,:,:,:).*train_data_ranked(c,:,:,:,:),4,'omitnan'); % The correlation coefficient is the average cross- product of z-scores 
%               end
          end
          
    %% 2nd order RSA, no bootstrap: 
    
    elseif if_boot == 0 && RSA_order == 2 
        R_val                     = NaN(n_class,size_test(1),size_test(2),size_train(3));
        % loop over classes
          for c = 1:n_class                           
             % inner dot product
             % class, trials, time test, time train 
             R_val(c,:,:,:)        = mean(test_data_ranked.*train_data_ranked(c,:,:,:),4,'omitnan'); % The correlation coefficient is the average cross- product of z-scores 
          end
    end
end





