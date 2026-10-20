function keep_line_alpha(fig)
% Line transparency (4-element 'Color', e.g. [0 0 0 0.3]) is not stored in
% .fig files. Store it in each line's CreateFcn instead, which MATLAB runs
% when the .fig is opened again -> the transparency is restored.
    drawnow;                                   % render, so the alpha value is available
    for h = findall(fig, 'Type', 'line')'
        c = h.Color;
        if numel(c) < 4                        % alpha not reported by 'Color':
            try                                % read the rendered RGBA (undocumented)
                e = h.Edge;
                if strcmp(e.ColorType, 'truecoloralpha')
                    c = double(e.ColorData(:))' / 255;
                end
            catch
            end
        end
        if numel(c) == 4 && c(4) < 1
            h.CreateFcn = sprintf('set(gcbo, ''Color'', [%.4f %.4f %.4f %.4f]);', c);
        end
    end
end