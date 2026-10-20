function p1 = plot1D(plt_matrix,timeX,color_mean,color_fill,color_borders,scale_fact,constant,Linewidth,Linestyle, legend_label)
% plot1D_RSA plot 1D vector with SE

            if color_fill == 0
                        color_fill = 'k';
            end
            h1          = squeeze(mean(plt_matrix,1,'omitnan'));        
            h2          = h1 + nanstd(plt_matrix)./sqrt(size(plt_matrix,1));
            h3          = h1 - nanstd(plt_matrix)./sqrt(size(plt_matrix,1));       
            plot(timeX,h2*scale_fact+constant', 'Color',color_borders,'Linewidth',Linewidth-Linewidth/2, 'HandleVisibility', 'off');
            hold on;
            plot(timeX,h3*scale_fact+constant', 'Color',color_borders,'Linewidth',Linewidth-Linewidth/2, 'HandleVisibility', 'off');
            x2          = [timeX, fliplr(timeX)];
            inBetween   = [h2*scale_fact+constant, fliplr(h3*scale_fact+constant)];
            h           = fill(x2(~isnan(inBetween)), inBetween(~isnan(inBetween)),color_fill);
            hold on;
                
            % Plot mean line (included in legend)
            if ~isempty(legend_label)
                p1 = plot(timeX,h1*scale_fact+constant','Color',color_mean,'Linewidth',Linewidth,'Linestyle', Linestyle,'DisplayName', legend_label); 
            else
                p1 = plot(timeX,h1*scale_fact+constant','Color',color_mean,'Linewidth',Linewidth,'Linestyle', Linestyle);
            end
            hold on;
            set(h,'facealpha',.3,'edgecolor','none', 'HandleVisibility', 'off') 
end

