function [Datai,Mdata,floats_ids,float_profs,TT_floats_sorted]=float_in_mooring_footprint(vertices,table,sensor)
% Defining time and space

latlim=vertices(:,1);
lonlim=vertices(:,2);
t1=datestr(min(table.Datetime), 'yyyy mm dd');
t2=datestr(max(table.Datetime), 'yyyy mm dd');
target_depth=ceil(mean(table.PressureStrainGauge_db_));

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
[floats_ids,float_profs] = select_profiles(lonlim,latlim,t1,t2,...
    'sensor',sensor,... % this selects only floats with nitrate sensors
    'outside','none');% All floats that cross into the time/space limits
% are identified from the Sprof index. The optional
% 'outside' argument allows the user to specify
% whether to retain profiles from those floats that
% lie outside the space limits ('space'), time
% limits ('time'), both time and space limits
% ('both'), or to exclude all profiles that fall
% outside the limits ('none'). The default is 'none'

if isempty(float_profs)
 disp('No floats were found during this time in the vicinity of the mooring')

 return
end

% display the number of matching floats and profiles
disp(['# of matching profiles: ' num2str(sum(cellfun('length',...
    float_profs)))]);
disp(['# of matching floats: ' num2str(length(floats_ids))]);

[Data, Mdata] = load_float_data(floats_ids, 'ALL', float_profs);

floats = fieldnames(Data);
nfloats = length(floats);

% vertical interpolation to depths with regular intervals, selecting data
% with qc_flags 1: good data, 2: probably good data
%Datai = depth_interp(Data, qc_flags, varargin);
% for f = 1:nfloats
%     Datai.(floats{f}) = depth_interp(Data.(floats{f}), [1,2],'prs_res',2,'calc_mld_dens',1);
% end

data_names={'TIME';'LATITUDE';'LONGITUDE';'PRES_ADJUSTED';'PSAL_ADJUSTED';'TEMP_ADJUSTED';'DOXY_ADJUSTED'};


for jj=1:length(data_names)
    target_depth_float.(data_names{jj})=[];
end
Datai=[];

for f = 1:nfloats
    Datai.(floats{f}) = depth_interp(Data.(floats{f}), [1,2],'prs_res',1,'calc_mld_dens',1);
    for jj=1:length(data_names)
        A=Datai.(floats{f}).(data_names{jj});
        B=nan(size(A,2),1);
        for ii=1:size(A,2)
            if isempty(A(find(~isnan(A(:,ii)),1,'first'),ii))
             B(ii)=NaN;
            else
            B(ii)=  A(find(~isnan(A(:,ii)),1,'first'),ii);
            end
        end
     
        target_depth_float.(data_names{jj})=cat(1,target_depth_float.(data_names{jj}),B);
    end
end

TT_floats=timetable(datetime(datestr(target_depth_float.TIME)),target_depth_float.LATITUDE,target_depth_float.LONGITUDE,...
    target_depth_float.PRES_ADJUSTED,target_depth_float.TEMP_ADJUSTED,target_depth_float.PSAL_ADJUSTED,target_depth_float.DOXY_ADJUSTED);
TT_floats.Properties.VariableNames={'Lat' 'Lon' 'Press' 'Temp' 'Sal' 'DO'};
TT_floats_sorted=sortrows(TT_floats);

end