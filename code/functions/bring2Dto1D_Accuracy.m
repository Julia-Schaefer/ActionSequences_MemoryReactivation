function data1D = bring2Dto1D_Accuracy(data2D,train_window,test_time, train_time,diag)

% averages the 2D Accuracy either along th diagonal or in a specified
% window of the traning time
% diag = 1 (diagonal) diag = 0 (window training time)
% train_window = train time window start & stop

data1D = NaN(4,size(data2D,1), size(test_time,2)); % Preallocate result vector

for cl = 1:size(data2D,2)
    for i = 1:size(data2D,1)
        if diag == 1
             A = squeeze(data2D(i,cl,:,train_window(1):end))'; % flip test and train time    
        else
             A = squeeze(data2D(i,cl,:,:))'; % flip test and train time    
        end
             for t = 1:size(test_time,2)
                if diag == 0
                 row_start = train_window(1); 
                 row_end = train_window(2); 
                else
                row_start = max(1, t - 2);
                row_end = min(length(train_time)-train_window(1), t + 2);
                end
                % average +/- along the training time for each diagonal entry
                data1D(cl,i,t) = mean(A(row_start:row_end, t));
            end
    end
end

