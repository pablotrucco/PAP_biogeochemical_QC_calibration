function newTableName=cruise_xlsx_btl2table(filepath)

fileNames = dir(fullfile(filepath2, '*.xlsx'));
fileNames = fileNames(~startsWith({fileNames.name}, '._'));%Because of mac 
%Creating extra files
%Getting the cruise name
newTableName=genvarname(fileNames(1).name(1:5));




% Initialize a cell array to store the data from all files
all_data = {};
% Loop through each file
for k = 1:length(fileNames)
    filename = fullfile(filepath2, fileNames(k).name);

    opts=detectImportOptions(filename);
    T = readtable(filename, opts);

    % Use regexp to find the CTD number, including leading zeros
    % The pattern looks for 'CTD' followed by any number of digits (\d+)
    ctdPattern = 'CTD(\d+)';
    tokens = regexp(filename, ctdPattern, 'tokens');
    ctdNumber = tokens{1}{1}; % This extracts the first (and should be only) match group

    % Construct the new string for use in the column, combining cruise name and CTD number
    newColumnEntry = sprintf('%s_%s', newTableName, ctdNumber);
    T.Cruise_CTD = repmat({newColumnEntry}, height(T), 1);


    fid = fopen(filename, 'r');
    if fid == -1
        error('Could not open file: %s', filename);
    end
    % Initialize variables
    header_row = 0;
    data_row = 0;
    row_count = 0;
    % Loop through the file to find the header row
    while ~feof(fid)
        row_count = row_count + 1;
        line = fgetl(fid);
        % Check if the line contains the header identifier
        if contains(line, 'Bottle')
            header_row = row_count;
            break;
        end
    end
    % Rewind the file
    frewind(fid);
    % Read and discard lines before the header row
    for i = 1:header_row-1
        fgetl(fid);
    end
    % Read the header row and split it into column names
    headers = strsplit(fgetl(fid));
    % Initialize a cell array to store the data from this file
    data = {};
    % Loop through the rest of the file to read the data rows
    while ~feof(fid)
        line = fgetl(fid);
        % Check if the line ends with (avg)
        if endsWith(line, '(avg)')
            % Split the line into cells and convert numeric cells to numbers
            row = strsplit(line);
            for i = 1:length(row)
                [num, status] = str2num(row{i});
                if status
                    row{i} = num;
                end
            end
            % Remove empty cells and (avg) cell from row
            row(cellfun('isempty', row)) = [];
            row(end) = [];
            % Append the row to the data cell array
            data(end+1,:) = row;
        end
    end
    fclose(fid);

    % Extract CTD cast number from filename and create CTD cast string in CTD_XXX format
    ctd_cast_str = regexp(filename, 'CTD_\d{3}', 'match');
    ctd_cast_str = strrep(ctd_cast_str, 'CTD', newTableName);
   
    % Create a new column for CTD cast string and fill it with ctd_cast_str
    ctd_cast_col = repmat({ctd_cast_str}, size(data, 1), 1);

      
    % Append CTD cast column to data cell array as first column
    data = [ctd_cast_col data];
    
    % Append data from this file to all_data cell array
    all_data = [all_data; data];
end
headers(1)=[];

% Convert the all_data cell array to a table and set the column names (including CTD_Cast as first column)
T = cell2table(all_data);
T.Date=datetime(datestr(strcat(string(T.(4)),string(T.(3)),string(T.(5)))));
T(:,[3,4,5])=[];
T=movevars(T,'Date','Before','all_data2');
T.Date.Format = 'yyyy-MM-dd';
T.Properties.VariableNames = ['Cruise_CTD' 'Sample_Date' 'Niskin_Bottle' headers(3:end)];

splitStrings = cellfun(@(x) split(x,'_'), T.Cruise_CTD, 'UniformOutput', false);
T.CTD = cellfun(@(x) str2double(x{2}), splitStrings);
% Create a new table with the desired Cruise name
newTableName = newTableName + "_CTD_btl";

assignin('base', newTableName, T);
%evalin('base', [newTableName ' = [' newTableName '; T];']);%***************

end