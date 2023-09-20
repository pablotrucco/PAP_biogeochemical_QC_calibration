function []=float_in_mooring_footprint(vertices,table)
% Defining time and space
latlim=[-70 -50];%Previous [-64 -51]
lonlim=[-130 -70];


latlim=vertices(:,1);%Previous [-64 -51]
lonlim=vertices(:,1);
t1=datestr(min(table.Datetime), 'yyyy mm dd');
t2=datestr(max(table.Datetime), 'yyyy mm dd');

%Lines need it to define paths and create folders need it for the routine
%to work.
%***it will create two folders (Profiles and Index) in the current path***
initialize_argo();
global Sprof Float Settings;

%==========================================================================
% 'sensor', 'SENSOR_TYPE': By default, all floats within the lon/lat/time
%           limits are considered. This option allows the selection by
%           sensor type. Available are: PRES, PSAL, TEMP, DOXY, BBP,
%           BBP470, BBP532, BBP700, TURBIDITY, CP, CP660, CHLA, CDOM,
%           NITRATE, BISULFIDE, PH_IN_SITU_TOTAL, DOWN_IRRADIANCE,
%           DOWN_IRRADIANCE380, DOWN_IRRADIANCE412, DOWN_IRRADIANCE443,
%           DOWN_IRRADIANCE490, DOWN_IRRADIANCE555, DOWN_IRRADIANCE670,
%           UP_RADIANCE, UP_RADIANCE412, UP_RADIANCE443, UP_RADIANCE490,
%           UP_RADIANCE555, DOWNWELLING_PAR, DOXY2, DOXY3
%           (Currently, only one sensor type can be selected.)

%Select profiles based on limits, and specified sensor
[floats_DO,float_profs_DO] = select_profiles(lonlim,latlim,t1,t2,...
    'sensor','DOXY',... % this selects only floats with nitrate sensors
    'outside','none');% All floats that cross into the time/space limits
% are identified from the Sprof index. The optional
% 'outside' argument allows the user to specify
% whether to retain profiles from those floats that
% lie outside the space limits ('space'), time
% limits ('time'), both time and space limits
% ('both'), or to exclude all profiles that fall
% outside the limits ('none'). The default is 'none'

if isempty(float_profs_DO)
 disp('No floats were found during this time in the vicinity of the mooring')

 return
end

% display the number of matching floats and profiles
disp(['# of matching profiles: ' num2str(sum(cellfun('length',...
    float_profs_DO)))]);
disp(['# of matching floats: ' num2str(length(floats_DO))]);

[Data_DO, Mdata_DO] = load_float_data(floats_DO, 'ALL', float_profs_DO);

floats = fieldnames(Data_DO);
nfloats = length(floats);

% vertical interpolation to depths with regular intervals, selecting data
% with qc_flags 1: good data, 2: probably good data
%Datai = depth_interp(Data, qc_flags, varargin);
for f = 1:nfloats
    Datai_DO.(floats{f}) = depth_interp(Data_DO.(floats{f}), [1,2],'prs_res',2,'calc_mld_dens',1);
end
end