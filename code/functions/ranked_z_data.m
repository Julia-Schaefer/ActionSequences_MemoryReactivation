   
function data_rank_z = ranked_z_data(data_sliced)

% data_sliced:          data structure, sliced
% data_rank:            preallocation of data_rank 

n_dim = length(size(data_sliced));

  if n_dim == 4
      
          % rank order
          [n_dim1, n_dim2,n_dim3, nfeatures]    = size(data_sliced);
          data_rank                             = NaN(n_dim1, n_dim2,n_dim3, nfeatures);
      
          % sort along feature dimension
          % geat feature index from the sorting
          [~,feature_idx] = sort(data_sliced,n_dim);
          
          % create trial and boot index
          dim1_idx    = repmat((1:n_dim1)', [1, n_dim2,n_dim3, nfeatures]);
          dim2_idx    = repmat(reshape(1:n_dim2, 1, [], 1, 1), [n_dim1, 1, n_dim3, nfeatures]);
          dim3_idx    = repmat(reshape(1:n_dim3, 1, 1, [], 1), [n_dim1, n_dim2, 1, nfeatures]);      

          % get linear index
          linear_idx = sub2ind([n_dim1, n_dim2,n_dim3, nfeatures], dim1_idx, dim2_idx,dim3_idx, feature_idx);
          clear feature_idx dim1_idx dim2_idx dim3_idx
          
          % create ntrials x nboots x time x nfeatures array with ranks 1:nfeatures
          % assign ranks to defined indices
          data_rank(linear_idx) = repmat(reshape(1:nfeatures, 1, 1, 1, []), n_dim1, n_dim2, n_dim3, 1);
     
   elseif n_dim == 3 
         
          % rank order
          [n_dim1, n_dim2, nfeatures]    = size(data_sliced);
          data_rank                      = NaN(n_dim1, n_dim2, nfeatures);

          % sort along feature dimension
          % get feature index from the sorting
          [~,feature_idx] = sort(data_sliced, n_dim);            
          
          % create trial and boot index
          dim1_idx    = repmat((1:n_dim1)', [1, n_dim2, nfeatures]);
          dim2_idx    = repmat(reshape(1:n_dim2, 1, [], 1), [n_dim1, 1, nfeatures]);

          % get linear index
          linear_idx = sub2ind([n_dim1, n_dim2, nfeatures], dim1_idx, dim2_idx, feature_idx);
          clear feature_idx dim1_idx dim2_idx
          
          % create ntrials x time x nfeatures array with ranks 1:nfeatures
          % assign ranks to defined indices
          data_rank(linear_idx) = repmat(reshape(1:nfeatures, 1, 1, []), n_dim1, n_dim2, 1);
          
   end

          % Nan zcoring
          mean_val               = mean(data_rank, n_dim,'omitnan');
          std_val                = std(data_rank, 0, n_dim,'omitnan');
          data_rank_z            = (data_rank - mean_val) ./ std_val;

end
% squeeze(data_rank(1,:,:,:))
% 
% size(data_rank)
