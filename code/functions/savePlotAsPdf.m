function savePlotAsPdf(filename, folder, fig)
    % savePlotAsPdf(filename, folder, fig) saves the specified figure as a PDF file.
    % Input:
    %   filename : Name of the output PDF file (without extension)
    %   folder   : (Optional) Folder path where the PDF will be saved
    %   fig      : Figure object to be saved
    %
    % If the folder is not provided, the file will be saved in the current
    % working directory.

    % Check if the figure object is valid
    if ~isempty(fig) && ishandle(fig) && strcmp(get(fig, 'Type'), 'figure')
        % Valid figure object
    else
        error('Invalid figure object. Please provide a valid figure handle.');
    end

    % Append '.pdf' to the filename
    fullFilename = strcat(filename, '.pdf');
    
    % If a folder is specified, combine it with the filename
    if nargin >= 2
        % Make sure to add a file separator if needed
        if ~isfolder(folder)
            error('Specified folder does not exist.');
        end
        fullFilename = fullfile(folder, fullFilename);
    end

    % Save the specified figure as a PDF
    try
        % Save as PDF using 'print' functionality
        orient(fig,'landscape')
        print(fig, fullFilename, '-dpdf', '-bestfit'); % -bestfit option to fit to the page
        
        fprintf('Figure saved as %s\n', fullFilename);
        
    catch ME
        fprintf('Failed to save the figure: %s\n', ME.message);
    end
end