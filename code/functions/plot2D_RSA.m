function plot2D_RSA(timeX,timeY,data,colorminmax,Xlabel, Ylabel, Clabel)
    % plot2D_RSA plots 2D matrix 
    imagesc(timeX,timeY,data);
    set(gca,'YDir','normal','FontSize',12);
    cb = colorbar(); 
    if colorminmax ~= 0
    caxis(colorminmax)
    end
    ylabel(cb,Clabel,'FontSize',10,'Rotation',270)
    cb.Label.Position(1) = cb.Label.Position(1) + 0.02; % Adjust the first element for horizontal distance
    xlabel(Xlabel);
    ylabel(Ylabel);
    xline(0)
end

