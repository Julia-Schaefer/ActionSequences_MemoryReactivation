function stat1D = ClusBasedPermTest1D(clusalpha,timeX,data1,data2)
% ClusBasedPermTest2D performs a cluster based permutation test on 2D data,
% after restructuring the data into the fieldtrip structure format

% if data2 is set to 0, the test is performed against a zero matrix

            if data2 == 0
                data2      = zeros(size(data1));
            else
                data2      = data2;
            end 
            
            if clusalpha == 0
                alphaval = 0.05;
            else
                alphaval = clusalpha;
            end
            
            stat1D       = [];

            % prepare ft_structure
            tmp         = [];
            tmp.dimord  = 'freq_time';
            tmp.R       = [];
            tmp.time    = timeX;
            tmp.label   = '1';
            tmp.cfg     = [];

            % create two fieldtrip structures, one for each conditon with data cell array (one cell per channel/subject) 
            R1          = cell(1,size(data1,1));
            R2          = cell(1,size(data1,1));
            for n       = 1:size(data1,1)
             tmp.R      = data1(n,:);
             R1{n}      = tmp;
             tmp.R      = data2(n,:);
             R2{n}      = tmp;
            end

            % ft_freqstatistics
            cfg                     = [];
            cfg.neighbours          = [];  
            cfg.parameter           = 'R';
            cfg.method              = 'montecarlo';
            cfg.correctm            = 'cluster';
            cfg.statistic           = 'ft_statfun_depsamplesT';
            cfg.clusteralpha        = alphaval;
            cfg.clusterstatistic    = 'maxsum';
            cfg.alpha               = 0.05;
            cfg.correcttail         = 'alpha';
            cfg.numrandomization    = 1000000;
            cfg.randomseed          = 42; 
            cfg.avgoverfreq         ='no';
            cfg.clustertail         = 0;
            cfg.tail                = 0;    % Two-sided test
%             cfg.tail              = 1;    % One-sided test, testing if condition 1 is greater than condition 2
    %         cfg.tail              = -1;   % One-sided test, testing if condition 1 is less than condition 2
            cfg.critval             = 'yes';

            % prepare design matrix
            Nsub                    = numel(R1); % NSub = NChan in this case
            cfg.design(1,1:2*Nsub)  = [ones(1,Nsub) 2*ones(1,Nsub)];
            cfg.design(2,1:2*Nsub)  = [1:Nsub 1:Nsub];
            cfg.ivar                = 1; % the 1st row in cfg.design contains the independent variable
            cfg.uvar                = 2; % the 2nd row in cfg.design contains the subject number

            % compute statistics
            stat1D = ft_timelockstatistics(cfg, R1{:},R2{:});
end

