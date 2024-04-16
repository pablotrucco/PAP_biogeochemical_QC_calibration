function varName = import_btl_sal(workbookFile, sheetName, dataLines)
%import_btl_sal Import data from a spreadsheet
%  T = import_btl_sal(FILE) reads data from the first worksheet
%  in the Microsoft Excel spreadsheet file named FILE.  Returns the data
%  as a table.
%
%  T = import_btl_sal(FILE, SHEET) reads from the specified
%  worksheet.
%
%  T = import_btl_sal(FILE, SHEET, DATALINES) reads from the
%  specified worksheet for the specified row interval(s). Specify
%  DATALINES as a positive scalar integer or a N-by-2 array of positive
%  scalar integers for dis-contiguous row intervals.
%
%  Example:
%  T = import_btl_sal("/Volumes/SERPENT Hur/JC231/Sensors_and_Moorings/CTD/Autosal Data/JC231_SALFORM_.xlsx", "CTD SALINITIES", [8, 97]);
%   *****WARNING*******
%   THIS FUNCTION ASSUMES THAT THE STRUCTURE OF THE .xlsx FILE WONT CHANGE 
%   LIKE THE INFO OF THE NAME OF THE CRUISE WOULD BE STORED IN THE A2 CELL
%   OF THE FILE
%  See also READTABLE.
%

%% Input handling

% If no sheet is specified, read first sheet
if nargin == 1 || isempty(sheetName)
    sheetName='CTD SALINITIES';
end

% If row start and end points are not specified, define defaults
if nargin <= 2
    dataLines = [9, 10000];
end

%% Set up the Import Options and import the data
opts = spreadsheetImportOptions("NumVariables", 12);

% Specify sheet and range
opts.Sheet = sheetName;
if isinf(dataLines(1, 2))
    opts.DataRange = "A" + dataLines(1, 1) + ":L";
else
    opts.DataRange = "A" + dataLines(1, 1) + ":L" + dataLines(1, 2);
end

% Specify column names and types
opts.VariableNames = ["CTD", "ROSETTE", "BOTTLE", "JULIAN", "AUTOSAL", "CTD1", "ERROR1", "CTD2", "ERROR2", "PRIM_min_SECON", "CORR1", "CORR2"];
opts.VariableTypes = ["double", "double", "double", "string", "double", "double", "double", "double", "double", "double", "double", "double"];

% Specify variable properties
opts = setvaropts(opts, "JULIAN", "WhitespaceRule", "preserve");
opts = setvaropts(opts, "JULIAN", "EmptyFieldRule", "auto");

% Import the data
T = readtable(workbookFile, opts, "UseExcel", false);

for idx = 2:size(dataLines, 1)
    opts.DataRange = "A" + dataLines(idx, 1) + ":L" + dataLines(idx, 2);
    tb = readtable(workbookFile, opts, "UseExcel", false);
    T = [T; tb]; %#ok<AGROW>
end

% Find index of first row with missing value in first column
firstMissingRow = find(ismissing(T{:, 1}), 1);
    
% Remove all rows below first row with missing value in first column
if ~isempty(firstMissingRow)
    T(firstMissingRow:end, :) = [];
end

% Read header data from Excel file
[~, headerText] = xlsread(workbookFile, sheetName, 'J2');

% Convert header data to string and extract date 
headerStr = string(headerText);
substrings = split(headerStr);
    
% Find index of substring that contains 'DATE:'
DateIndex = find(contains(substrings, 'DATE:'));

% Extract date from next substring
DateStr = substrings(DateIndex + 1);
Year_cruise=datetime(DateStr);
Year_cruise=num2str(Year_cruise.Year);

% Convert JULIAN time column to datetime values

julianDates = strcat(repmat(string(Year_cruise), height(T),1),{' '},T.JULIAN);

datetimeValues = datetime(julianDates, 'InputFormat', 'uuuu DDD/HH:mm');

%warning('on', 'MATLAB:datetime:NonstandardYearField');

% Add new column with datetime values to table
T.DateTime = datetimeValues;


% Add variable "QF" with all values set to 2 if it doesn't exist
if ~any(strcmp('QF', T.Properties.VariableNames))
    T.QF = ones(size(T, 1), 1) * 2;
end

% Read header data from Excel file
[~, headerText] = xlsread(workbookFile, sheetName, 'A2');

% Convert header data to string and extract cruise name
headerStr = string(headerText);
substrings = split(headerStr);
    
% Find index of substring that contains 'CRUISE:'
cruiseIndex = find(contains(substrings, 'CRUISE:'));

% Extract cruise name from next substring
cruiseName = substrings(cruiseIndex + 1);

% Create variable name by appending '_btl_sal' to cruise name
varName = cruiseName + "_autosal";

% Assign value of T to variable with desired name in base workspace
assignin('base', varName, T);

end