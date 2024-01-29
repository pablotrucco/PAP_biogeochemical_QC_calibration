function newStructName=cruise_cnv2struct(filepath)

originalFolder=pwd;

% For example
% '/Volumes/SERPENT Hur/DY130/Sensors_and_Moorings/CTD/DY130/CTD Data/Processed';
% or '/Volumes/SERPENT Hur/JC231/Sensors_and_Moorings/CTD/CTD Data/CTD Pro Data';

%The location of the casts
cd(filepath)
files=dir(fullfile('*.cnv'));
files = files(~startsWith({files.name}, '._'));%Because of mac 


selected_files=struct('name',{});
counter=0;

for ii=1:length(files)
    file_name=files(ii).name;
    if contains(file_name, 'cfaldb.cnv') %      _align_CTM_Derive_2Hz    && contains(file_name, 'CTM') % old version length(file_name)==17 %
        counter=counter+1;
        selected_files(counter).name = file_name;
    end
end

%Creating a structure that will have the name of the cruise and inside each
%cast as named from the files

fileNames={selected_files.name};
firstFileName=fileNames{1};       %Asuming that all the .cnv filenames 
                                    % are preceded by the cruise name
                                    % Example: DY130_001.cnv
newStructName=genvarname(firstFileName(1:5));
newStructName=strcat(newStructName,  '_CTD_profiles');
% Create a new structure with the desired Cruise name
assignin('base', newStructName, struct);

% Loop through all file names to create the corresponding CTD cast inside
% of the structure with the Cruise name, Example DY130.CTD_001
for ii=1:length(fileNames)
    fileName=fileNames{ii};
    [~,name,~]=fileparts(fileName); % Get the file name without extension
    numbers=regexp(name,'\d+','match'); % Find all groups of consecutive numbers in the file name
    subclassName=genvarname(['CTD_' numbers{end}]); % -1 Get the last group of consecutive numbers (assuming it's always at the end of the file name)
    
    % Create a new subclass with the desired name inside the new structure
    evalin('base',[newStructName '.' subclassName ' = struct;']);
end

%Now to store the measurements of each cast in the corresponding place of
%the structure
subclassNames=fieldnames(evalin('base', newStructName));

for ii=1:length(subclassNames)

    subclassName = subclassNames{ii};

    r=readCnv(selected_files(:,ii).name);
    assignin('base', 'r', r)
    % keys(r.varNames)

    % Scan count
    evalin('base', [newStructName '.' subclassName '.Scan_count=r.scan;']);    
    % Datenum date
    evalin('base', [newStructName '.' subclassName '.DATE=repmat(r.Date,size(r.prDM));']);
    % Elapsed time seconds
    evalin('base', [newStructName '.' subclassName '.Time_elapsed_s=r.timeS;']);
    % Longitude 
    evalin('base', [newStructName '.' subclassName '.LONGITUDE=repmat(r.Longitude,size(r.prDM));']);
    % Latitude  
    evalin('base', [newStructName '.' subclassName '.LATITUDE=repmat(r.Latitude,size(r.prDM));']);
    % Pressure dB
    evalin('base', [newStructName '.' subclassName '.CTDPRS=r.prDM;']);
    % Temp primary °C
    evalin('base', [newStructName '.' subclassName '.CTDTMP_1=r.t090C;']);
    % Temp secondary °C
    evalin('base', [newStructName '.' subclassName '.CTDTMP_2=r.t190C;']);
    % Sal primary psu
    evalin('base', [newStructName '.' subclassName '.CTDSAL_1=r.sal00;']);
    % Sal secondary psu
    evalin('base', [newStructName '.' subclassName '.CTDSAL_2=r.sal11;']);
   
    % Oxygen primary in ml/L
    evalin('base', [newStructName '.' subclassName '.CTDOXY_ml_L_1=r.sbeox0MLL;']); %ml/l

    % Oxygen secondary in ml/L. Sometimes for PAP historical measurements
    % there is no secondary measurements, so the following conditionant has
    % been updated. This can be adapted for future version with similar
    % issues for other variables when you have the same problem.
    if isfield(r, 'sbeox1MLL')
        evalin('base', [newStructName '.' subclassName '.CTDOXY_ml_L_2=r.sbeox1MLL;']);
    end


    % Oxygen primary in umol/kg
%     evalin('base', [newStructName '.' subclassName '.CTDOXY_ml_L_1=r.sbox0MmKg;']); %umol/kg
%     % Oxygen secondary in umol/kg
%     evalin('base', [newStructName '.' subclassName '.CTDOXY_ml_L_2=r.sbox1MmKg;']); 

    
   
end

clear r
cd(originalFolder)


end