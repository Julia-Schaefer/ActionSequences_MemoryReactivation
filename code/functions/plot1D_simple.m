function p1 = plot1D_simple(plt_matrix, timeX, color, yax, legend_label)
    % plot1D plots mean + SE area for 1D data
    % Only mean line is added to the legend (SE is hidden)
    %
    % Inputs:
    %   plt_matrix     = [subjects x time] data
    %   timeX          = time vector for x-axis
    %   color          = color of the line (RGB or char)
    %   yax            = y-axis limits (or 0 for auto)
    %   legend_label   = optional string for legend

    if nargin < 5
        legend_label = '';  % No label by default
    end

    if isequal(color, 0)
        color = 'k';
    end

    % Mean and SE
    h1 = squeeze(mean(plt_matrix, 1, 'omitnan'));
    h2 = h1 + nanstd(plt_matrix)./sqrt(size(plt_matrix,1));
    h3 = h1 - nanstd(plt_matrix)./sqrt(size(plt_matrix,1));

    % Plot mean line (included in legend)
    if ~isempty(legend_label)
        p1 = plot(timeX, h1', 'Color', color, 'LineWidth', 3, 'DisplayName', legend_label);
    else
        p1 = plot(timeX, h1', 'Color', color, 'LineWidth', 3);
    end
    hold on;

    % Plot SE bounds (excluded from legend)
    plot(timeX, h2', 'Color', color, 'HandleVisibility', 'off');
    plot(timeX, h3', 'Color', color, 'HandleVisibility', 'off');

    % Shaded error area (excluded from legend)
    x2 = [timeX, fliplr(timeX)];
    inBetween = [h2, fliplr(h3)];
    h = fill(x2(~isnan(inBetween)), inBetween(~isnan(inBetween)), color);
    if color == [255, 212, 211]/255; % Rose % in case of reose color (velocity)
        set(h, 'FaceAlpha', 0.3, 'EdgeColor', 'white', 'HandleVisibility', 'off');
    else
        set(h, 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end

    % Y-axis limits
    if ~isequal(yax, 0)
        ylim([yax]);
    end

    % Clean plot aesthetics
    set(gca, 'Box', 'off');
    set(gca, 'TickDir', 'out');
    set(gca, 'Layer', 'top');
end
