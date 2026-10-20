function plot1D_RSA(plt_matrix,timeX,color)
% plot1D_RSA plot 1D vector with SE

            if color == 0
                        color = 'r';
            end
            h1          = squeeze(mean(plt_matrix,1,'omitnan'));        
            h2          = h1 + nanstd(plt_matrix)./sqrt(size(plt_matrix,1));
            h3          = h1 - nanstd(plt_matrix)./sqrt(size(plt_matrix,1));
            plot(timeX,h1'/10,color)
            hold on;
            plot(timeX,h2'/10,color);
            hold on;
            plot(timeX,h3'/10,color);
            x2          = [timeX, fliplr(timeX)];
            inBetween   = [h2/10, fliplr(h3/10)];
            h           = fill(x2(~isnan(inBetween)), inBetween(~isnan(inBetween)), color);
            set(h,'facealpha',.3,'edgecolor','none') 
end

