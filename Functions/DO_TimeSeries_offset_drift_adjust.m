function microcat_table=DO_TimeSeries_offset_drift_adjust(first_cruise,second_cruise,microcat_table)


%Import microcat data 
%***
%filepath='/Volumes/SERPENT Hur/Timeseries_DY130_JC231/OneDrive_2_13-04-2023/timeseries/buoy/DY130_Apr2021_SBE37-ODO-16503/DY130_Apr2021_SBE37-ODO_sn16503_1m-corrected-Jon.xlsx';
mooring_lat=48.9667;
mooring_lon=-16.4167;
%***
%opts=detectImportOptions(filepath);
%microcat_table=readtable(filepath,opts);

microcat_table.Datetime=datetime(datestr(microcat_table.MatlabTime_days_));
microcat_table = movevars(microcat_table, 'Datetime', 'Before', 1);

%The beginning and the end of the timeseries
mintime=min(microcat_table.Datetime);
maxtime=max(microcat_table.Datetime);


%Depth of the sensor

target_depth=ceil(mean(microcat_table.PressureStrainGauge_db_));
%% ========================================================================
%                           O   F   F   S   E   T
%
%First we select the indices of the CTD cast that where performed after the
%deployment of the mooring

ix_time_first=find(first_cruise.Datetime>=mintime);

first_cruise_valid=first_cruise(ix_time_first,:);

%We calculate the distance between the mooring and the profiles
first_cruise_valid.Dist_2_Moor=(deg2km(distance(first_cruise_valid.LATITUDE,...
    first_cruise_valid.LONGITUDE,mooring_lat,mooring_lon)));

%Using a criteria of ~5 m depth and a distance to the mooring less than <10
%km (Palevsky & Nicholson, 2018) we select the values from the CTD profiles

ix_valid_values_first=find(first_cruise_valid.Dist_2_Moor<=10 & first_cruise_valid.CTDPRS<=target_depth+3 & ...
    first_cruise_valid.CTDPRS>=target_depth-3);


valid_calibration_values_first=first_cruise_valid(ix_valid_values_first,:);
var_classes = varfun(@class, valid_calibration_values_first, 'OutputFormat', 'cell');

groupvars = {'CTD_cast', 'Datetime'};
tblstats_first = grpstats(valid_calibration_values_first, groupvars, {'mean','std'});

CTD_num_used_first=cellstr(tblstats_first.CTD_cast);


figure
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_,20,'filled')
hold on
scatter(tblstats_first.Datetime,tblstats_first.mean_OXY_MEAN,60,'sg','filled','MarkerEdgeColor','k')

box on
grid on
ax=gca;
ax.FontSize=14;
ax.YLabel.String='Dissolved Oxygen [\mumol kg^-^1]';
ax.XMinorTick='on';
legend('Unadjusted','First cruise - CTD values')

figure
hold on
for ii=1:length(CTD_num_used_first)

    plot(first_cruise.OXY_MEAN(strcmp(cellstr(first_cruise.CTD_cast),CTD_num_used_first(ii))), ...
        first_cruise.CTDPRS(strcmp(cellstr(first_cruise.CTD_cast),CTD_num_used_first(ii))))
    axis ij
    ax=gca;
    ax.FontSize=14;
    ax.XLabel.String='Dissolved Oxygen [\mumol kg^-^1]';
    ax.YLabel.String='Pressure (dbar)';
    ax.YLim=[0 200];
end
legend(cell2mat(CTD_num_used_first),'Interpreter', 'none')


%To determine the offset and minimize the effect of rapid changes in the
%microcat signal with respect to the CTD measurements, we will coordinate
%the two timeseries and interpolate in equal timestamp and calculate its
%difference
ix_time_cross_first=find(microcat_table.Datetime>=(min(tblstats_first.Datetime)-minutes(30)) & ...
    microcat_table.Datetime<=(max(tblstats_first.Datetime)+minutes(30)));

TT_microcat_for_offset=timetable(microcat_table.Datetime(ix_time_cross_first), ...
    microcat_table.OxygenSBE63_umol_kg_(ix_time_cross_first));

TT_CTD_for_offset=timetable(tblstats_first.Datetime,tblstats_first.mean_OXY_MEAN);
TT_offset=synchronize(TT_microcat_for_offset,TT_CTD_for_offset,'union','linear');


figure
scatter(TT_offset.Time,TT_offset.(1)-TT_offset.(2),20,'Filled')
hold on
yline(0)
clr=rgb('red');
yl=yline(mean(TT_offset.(1)-TT_offset.(2)),'Color',clr,'linewidth',2);
yl.Label=strcat('Mean offset =', num2str(round(mean(TT_offset.(1)-TT_offset.(2)),2)), '\mumol kg^-^1');
yl.FontSize=14;
yl.FontWeight='bold';

yl2=yline(mean(TT_offset.(1)-TT_offset.(2))+std(TT_offset.(1)-TT_offset.(2)),'Color',clr,'linestyle','--','linewidth',2);
yl2.Label=strcat('1 \sigma',' (',num2str(round(std(TT_offset.(1)-TT_offset.(2)),2)),'\mumol kg^-^1)');
yl2.FontSize=14;
yl2.FontWeight='bold';

yl3=yline(mean(TT_offset.(1)-TT_offset.(2))-std(TT_offset.(1)-TT_offset.(2)),'Color',clr,'linestyle','--','linewidth',2);
yl3.Label='-1 \sigma';
yl3.FontSize=14;
yl3.FontWeight='bold';

ax=gca;
ax.FontSize=14;
ax.YLabel.String='Sensor offset [\mumol kg^-^1]';
box on

%Adjusting the measurement by substracting the offset

microcat_table.OxygenSBE63_umol_kg_Offset_corrected=microcat_table.OxygenSBE63_umol_kg_-(round(mean(TT_offset.(1)-TT_offset.(2)),2));

figure
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_,20)
hold on
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_Offset_corrected,20,'*')
scatter(tblstats_first.Datetime,tblstats_first.mean_OXY_MEAN,60,'sg','filled','MarkerEdgeColor','k')
box on
grid on
ax=gca;
ax.FontSize=14;
ax.YLabel.String='Dissolved Oxygen [\mumol kg^-^1]';
ax.XMinorTick='on';
legend('Unadjusted','Offset corrected','First cruise - CTD values')

%% ========================================================================
%          L   I   N   E   A   R           D   R   I   F   F   T
%
%Now we select the indices of the CTD cast that where performed before the
%recovery of the mooring

ix_time_second=find(second_cruise.Datetime<=maxtime);

second_cruise_valid=second_cruise(ix_time_second,:);


%We calculate the distance between the mooring and the profiles
second_cruise_valid.Dist_2_Moor=(deg2km(distance(second_cruise_valid.LATITUDE,...
    second_cruise_valid.LONGITUDE,mooring_lat,mooring_lon)));

%Using a criteria of ~5 m depth and a distance to the mooring less than <10
%km (Palevsky & Nicholson, 2018) we select the values from the CTD profiles

ix_valid_values_second=find(second_cruise_valid.Dist_2_Moor<=10 & second_cruise_valid.CTDPRS<=target_depth+3 & ...
    second_cruise_valid.CTDPRS>=target_depth-3);


valid_calibration_values_second=second_cruise_valid(ix_valid_values_second,:);
var_classes = varfun(@class, valid_calibration_values_second, 'OutputFormat', 'cell');

groupvars = {'CTD_cast', 'Datetime'};
tblstats_second = grpstats(valid_calibration_values_second, groupvars, {'mean','std'});

CTD_num_used_second=cellstr(tblstats_second.CTD_cast);


figure
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_,20)
hold on
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_Offset_corrected,20,'*')
scatter(tblstats_first.Datetime,tblstats_first.mean_OXY_MEAN,60,'sg','filled','MarkerEdgeColor','k')
scatter(tblstats_second.Datetime,tblstats_second.mean_OXY_MEAN,60,'dg','filled','MarkerEdgeColor','k')
box on
grid on
ax=gca;
ax.FontSize=14;
ax.YLabel.String='Dissolved Oxygen [\mumol kg^-^1]';
ax.XMinorTick='on';
legend('Unadjusted','Offset corrected','First cruise CTD values','Second cruise CTD values')

figure
hold on
for ii=1:length(CTD_num_used_second)

    plot(second_cruise.OXY_MEAN(strcmp(cellstr(second_cruise.CTD_cast),CTD_num_used_second(ii))), ...
        second_cruise.CTDPRS(strcmp(cellstr(second_cruise.CTD_cast),CTD_num_used_second(ii))))
    axis ij
    ax=gca;
    ax.FontSize=14;
    ax.XLabel.String='Dissolved Oxygen [\mumol kg^-^1]';
    ax.YLabel.String='Pressure (dbar)';
    ax.YLim=[0 200];
    %legend(cell2mat(CTD_num_used(ii)),'Interpreter', 'none')
end
legend(cell2mat(CTD_num_used_second),'Interpreter', 'none')


%To determine the offset and minimize the effect of rapid changes in the
%microcat signal with respect to the CTD measurements, we will coordinate
%the two timeseries and interpolate in equal timestamp and calculate its
%difference
ix_time_cross_second=find(microcat_table.Datetime>=(min(tblstats_second.Datetime)-minutes(30)) & ...
    microcat_table.Datetime<=(max(tblstats_second.Datetime)+minutes(30)));

TT_microcat_for_linear_drift=timetable(microcat_table.Datetime(ix_time_cross_second), ...
    microcat_table.OxygenSBE63_umol_kg_Offset_corrected(ix_time_cross_second));

TT_CTD_for_linear_drift=timetable(tblstats_second.Datetime,tblstats_second.mean_OXY_MEAN);
TT_linear_drift=synchronize(TT_microcat_for_linear_drift,TT_CTD_for_linear_drift,'union','linear');


figure
scatter(TT_linear_drift.Time,TT_linear_drift.(1)-TT_linear_drift.(2),20,'Filled')
hold on
yline(0)
clr=rgb('red');
yl=yline(mean(TT_linear_drift.(1)-TT_linear_drift.(2)),'Color',clr,'linewidth',2);
yl.Label=strcat('Mean offset =', num2str(round(mean(TT_linear_drift.(1)-TT_linear_drift.(2)),2)), '\mumol kg^-^1');
yl.FontSize=14;
yl.FontWeight='bold';

yl2=yline(mean(TT_linear_drift.(1)-TT_linear_drift.(2))+std(TT_linear_drift.(1)-TT_linear_drift.(2)),'Color',clr,'linestyle','--','linewidth',2);
yl2.Label=strcat('1 \sigma',' (',num2str(round(std(TT_linear_drift.(1)-TT_linear_drift.(2)),2)),'\mumol kg^-^1)');
yl2.FontSize=14;
yl2.FontWeight='bold';

yl3=yline(mean(TT_linear_drift.(1)-TT_linear_drift.(2))-std(TT_linear_drift.(1)-TT_linear_drift.(2)),'Color',clr,'linestyle','--','linewidth',2);
yl3.Label='-1 \sigma';
yl3.FontSize=14;
yl3.FontWeight='bold';

ax=gca;
ax.FontSize=14;
ax.YLabel.String='Sensor linear drift final deviation [\mumol kg^-^1]';
box on

%Adjusting the measurement by substracting the offset
linear_correction=linspace(0,(round(mean(TT_linear_drift.(1)-TT_linear_drift.(2)),2)),height(microcat_table));
microcat_table.OxygenSBE63_umol_kg_Offset_linear_drift_corrected=microcat_table.OxygenSBE63_umol_kg_Offset_corrected - ...
linear_correction';

%clearvars -except microcat_table tblstats_first tblstats_second

figure
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_,20)
hold on
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_Offset_corrected,20,'*')
scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_Offset_linear_drift_corrected,20,'+')
scatter(tblstats_first.Datetime,tblstats_first.mean_OXY_MEAN,60,'sg','filled','MarkerEdgeColor','k')
scatter(tblstats_second.Datetime,tblstats_second.mean_OXY_MEAN,60,'dg','filled','MarkerEdgeColor','k')

% plot(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_)
% hold on
% plot(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_Offset_corrected)
% plot(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_Offset_linear_drift_corrected)
% scatter(tblstats_first.Datetime,tblstats_first.mean_OXY_MEAN,60,'sg','filled','MarkerEdgeColor','k')
% scatter(tblstats_second.Datetime,tblstats_second.mean_OXY_MEAN,60,'dg','filled','MarkerEdgeColor','k')



box on
grid on
ax=gca;
ax.FontSize=14;
ax.YLabel.String='Dissolved Oxygen [\mumol kg^-^1]';
ax.XMinorTick='on';
lg=legend('Unadjusted','Offset corrected','Offset & Linear Drift corrected','First Cruise CTD values', 'Second Cruise CTD values');
lg.FontSize=14;
lg.Location='southeast';

%Erase this two lines below
%first_cruise=DY130_CTD_profiles_table;
%second_cruise=JC231_CTD_profiles_table;
end
