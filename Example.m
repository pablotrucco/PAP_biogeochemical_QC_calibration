%% First of all, this following line is just to set the correct path to 
% the exampl data files in your computer.
currentDir = pwd;

%This second line will add all the subfolder below this Example.m to your
%MATLAB search path
addpath(genpath(currentDir))

%To run DY130 set cruise_opt to 1 for JC231 set cruise_opt to 2

cruise_opt=1;

%==========================================================================
%OUTSIDE OF MATLAB AND  PREVIOUS TO EXECUTE THE FUNCTIONS  
%
%                       CCCCC  TTTTTTTT    DDDDD
%                      CC         TT       D    D
%                     C           TT       D     D
%                     C           TT       D     D
%                      CC         TT       D    D
%                       CCCCC     TT       DDDDD

%%==========================================================================

%STAGE ONE: Use the SBE data processing to process the .xmlcon and .hex to
%the corresponding .cnv files. See manual for a step by step procedure of
%this stage.
%
%STAGE TWO: Again use the SBE data processing to process the .xmlcon and 
%.ros to the corresponding .bl files. See manual for a step by step 
%procedure of this stage.
%INSIDE MATLAB

%--------------------------------3-----------------------------------------
%STAGE THREE: Import .cnv files from STAGE ONE to a structure in MATLAB

%Define input variables

if cruise_opt==1
    filepath=fullfile(currentDir,'Data_example/SBE_Data_Processed/DY130/SeaBird/Data/Processed');
end


if cruise_opt==2
    filepath=fullfile(currentDir,'Data_example/SBE_Data_Processed/JC231/SeaBird/Data/Processed');
end

%Call the function and a little bit of more magic (nonsense,really) to get 
% the name of the structure

namesBefore=who;

cruise_cnv2struct(filepath); %Just this part is to call the function

%All the following lines is to get the name of the new created structure
clear r
varsAfter=whos;
newNames=setdiff({varsAfter.name}, namesBefore);
newStructNames=newNames(strcmp({varsAfter.class}, 'struct'));
structName=newStructNames{1};

%--------------------------------4-----------------------------------------
%STAGE FOUR: Use the structure output from the previous stage and quality
%control the data creating quality flags following OCADS scheme. More
%documentation in the function CTD_sal_qc
%CTD_sal_qc(cruise_struct,sig,acclim_depth,plot_graph)
%default values sig=3, acclim_depth=20, plot_graph=1( true, so plot graphs)

%Here I use the evalin to keep using the name of the cruise extracted from
%the files and keep the same name of the structure. I also opt for leaving
%all the default values

evalin('base', ['CTD_sal_qc(' structName ');']);


clearvars namesBefore varsAfter newNames newStructNames r 

%--------------------------------5-----------------------------------------
%STAGE FIVE: Import .bl files from STAGE 2 into a table

cruise_btl2table(filepath);

varsAfter=whos;
newTableNames=varsAfter(strcmp({varsAfter.class}, 'table'));
TableName1=newTableNames.name;

clearvars varsAfter newTableNames ans

%-+-+-+-+-+-+-IMPORTANT-+-+-+-+-+- NEXT if STATEMENT CASE BASED ONLY. FOR DY130
%This next step is necessary to solve an unconsistency between logsheets
%and .btl files in DY130. the Niskin Bottle numbering do not correspond between the
%two datasets. See Manual for clarifications
if cruise_opt==1
    DY130_CTD_btl.Niskin_Bottle(7:22)=DY130_CTD_btl.Niskin_Bottle(7:22)+2;
end
%--------------------------------6-----------------------------------------
%STAGE SIX: Import the results of the Autosal measurements. The input is 
%the .xlsx file (including the path to it). If the sheetName is not
%specified, the function would assume that the correct corresponding name 
% of the sheet is 'CTD SALINITIES'. If the dataLines are not specified 
% (where the data starts and where it ends) the function will assume that 
% dataLines = [9, 10000]; The second element of dataLines is assumed 
% large enough to avoid excluding any datapoint. 

if cruise_opt==1
    workbookFile=fullfile(currentDir,'Data_example/DY130/Sensors_and_Moorings/Salinity/DY130/SALFORM_SS.xlsx');
end

if cruise_opt==2
    workbookFile=fullfile(currentDir,'Data_example/JC231/Sensors_and_Moorings/CTD/Autosal Data/JC231_SALFORM_.xlsx');
end


namesBefore=whos;

import_autosal(workbookFile)

varsAfter=whos;
newNames=setdiff({varsAfter.name}, {namesBefore.name});
TableName2=newNames{1};

clearvars namesBefore varsAfter newNames ans
%--------------------------------7-----------------------------------------
%STAGE SEVEN: Perform a match up and a robust linear fit between the
%Autosal measurements and the CTD bottle data.
%The function can work either by input of the corresponding tables 
%(obtained from the STAGE FIVE and STAGE SIX), or by specifiying the paths
%to the relative folders where the .bl files and the .xslx are located.
%In the current example we are using the output of the previous two STAGES.
%Detailed documentation inside of the function.
%The output table is helpfull to find which pair of values produce large
%outliers and can be excluded in a consecutive iteration of the function
%using a table with the pair of values [CTD_num,Pressure_dbar]. The program
%will identify the corresponding points based on your input and exclude
%them from the linear model

[brob1,stats1,brob2,stats2,cross_match_table1,cross_match_table2] = evalin('base', ['crossMatchSal(''tables'', ' TableName1 ', ' TableName2 ');']);

%In the execution of the previous line, if you are processing DY130, you
%will see a large outlier in the CTD_4 at 13 dbar, with a residual of about
%0.16 for both salinity sensors. This is observable graphically but you can
%identified also from the tables. Then in order to exclude this, we need to
%run the match up function again but using a flagging system for the
%outliers. Statistically the function has detected outliers and it appear
%as logical indexes in the resulting tables (Outlier_1 and Outlier_2
%columns). You could opt to use them setting as follow:
%
% outl=[cross_match_table1.Outlier_1,cross_match_table2.Outlier_2];
%
%but this will avoid a lot of data points. So we will aim just to get rid
%of this large outlier mentioned before. To do so you need to create the
%same structure as above (outl) but with a logical value of 1 for the
%position of the targeted outlier. It will be:

outl=zeros(height(cross_match_table1),2,'logical');%Creates an array that say that there are not outliers


%Then we know from our tables that the CTD_4 at 13 dbar is in the row 29,
%so we set the 29 to logical 1 to count it as an outliers. You can do the
%same to all the data that you migth judge as outliers.
outl(29,:) = true;

[brob1,stats1,brob2,stats2,cross_match_table1,cross_match_table2] = evalin('base', ['crossMatchSal(''tables'', ' TableName1 ', ' TableName2 ', 1, outl );']);

%--------------------------------8-----------------------------------------
%STAGE EIGHT: Finally we use the coeficient from the previous stage to
%adjust the salinity of each sensor and the imported bottle closure table salinity too.
% We also use the QF to avoid to use suspiciuos bad data and compute a mean profile from both sensors.
plot_graph=1;
evalin('base',['adjust_salinity_profiles(' structName ',brob1,brob2,plot_graph,' TableName2 ');'])

evalin('base',['adjust_btl_salinity(' TableName1 ',brob1,brob2);'])

%--------------------------------9-----------------------------------------
%STAGE NINE: Convert oxygen from ml/l to umol/kg using the adjusted 
% salinity values. It also calculates and adds CT, SA, rho into the cruise
% structure and also create a new vector that is the mean temp between the
% primary and seconday temperature sensor

% Call the function and pass the cruise_struct to convert oxygen
evalin('caller', [structName ' = O2_ml_l_to_umol_kg(' structName ');']);


%--------------------------------10----------------------------------------
%STAGE TEN: As in Stage four with salinity, it uses the structure output 
% from the previous stage and quality
%control the data creating quality flags following OCADS scheme. More
%documentation in the function CTD_O2_qc
%CTD_sal_qc(cruise_struct,sig,acclim_depth,plot_graph)
%default values sig=3, acclim_depth=20, plot_graph=1( true, so plot graphs)

%Here I use the evalin to keep using the name of the cruise extracted from
%the files and keep the same name of the structure. I also opt for leaving
%all the default values

evalin('base', ['CTD_O2_qc(' structName ');']);

%--------------------------------11----------------------------------------
%STAGE ELEVEN: Import the Winkler measurements to the workspace to be used
%in the cross match to the CTD oxygen sensor data, to adjust its values

if cruise_opt==1
    workbookFile2=fullfile(currentDir,'Data_example/DY130/Bottle_Oxygen/metadata_submission_templates_2021_bottle oxygen_DY130_vPTP.xlsx');
end

if cruise_opt==2
    workbookFile2=fullfile(currentDir,'Data_example/JC231/Bottle_oxygen/metadata_submission_templates_2022_bottle oxygen_JC231.xlsx');
end
namesBefore=whos;

import_O2_winkler(workbookFile2);

varsAfter=whos;
newNames=setdiff({varsAfter.name}, {namesBefore.name});
TableName3=newNames{1};

%--------------------------------12----------------------------------------
%STAGE TWELVE: The winkler data is in umol L-1 and we want it in umol kg-1.
%The imported table do not have latitude and longitude, and we need the
%coordinates to calculate absolute salinity, that in turn will be use to
%calculate in-situ density (and use it to convert the oxygen concentration)


evalin('base',['add_lat_lon_table(' TableName3 ' , ' structName ');']);


%--------------------------------13----------------------------------------
%STAGE THIRTEEN: The CTD oxygen bottle data is in ml L-1 and we want it in 
% umol kg-1. The imported table do not have latitude and longitude, and we 
% need the coordinates to calculate absolute salinity, that in turn will be 
% use to calculate in-situ density (and use it to convert the oxygen 
% concentration)


evalin('base',['add_lat_lon_table(' TableName1 ' , ' structName ');']);


%--------------------------------14----------------------------------------
%STAGE FOURTEEN: The cross match between the CTD oxygen bottle data and the
% Winkler oxygen measurements. Appart from making the cross match, the
% function also calculate and adds to the Winkler table the absolute salinity, 
% potential temperature, in-situ density and oxygen in umol kg-1. It has to
% be called providing the two tables, because it depends on the execution
% of step 5, 11 and 12.

[oxybrob1,oxystats1,oxybrob2,oxystats2,cross_match_table1_oxy,cross_match_table2_oxy] = evalin('base', ['crossMatchO2( ' TableName1 ', ' TableName3 ');']);

%--------------------------------15----------------------------------------
%STAGE FIFTEEN: Finally we use the coeficient from the previous stage to
%adjust the oxygen of each sensor. We also use the QF to avoid to use
%suspiciuos bad data and compute a mean profile from both sensors.
plot_graph=1;
evalin('base',['adjust_oxygen_profiles(' structName ',oxybrob1,oxybrob2,plot_graph,' TableName3 ')'])



%% This will start another serie of processes that will deal with the calibration
% of the mooring data


%             MM   MM   OOOOO   OOOOO   RRRRR   IIIII   NN   N    GGGGG
%             M M M M   O   O   O   O   R   R     I     N N  N    G
%             M  M  M   O   O   O   O   RRRR      I     N  N N    G  GG
%             M  M  M   O   O   O   O   R  R      I     N   NN    G   G
%             M     M   OOOOO   OOOOO   R   R   IIIII   N    N    GGGGG

% We will start with the first cruise and then continue with the second.
% Adjusting for offset at the beginning and then adjusting for linear
% drift, using the calibrated CTD casts
%--------------------------------1----------------------------------------

%STAGE ONE: Transform the structure with the CTD profiles into a table. It
%would be easier to handle in the next stage.
evalin('base',['CTD_struct2table(' structName ');'])

%**************** S T O P ******* R E A D *********************************
%At this stage you can save the result of the first cruise (if you have set
% the value of cruise_opt at the beginning of this file to 1, meaning that 
% you have been processing the deployment cruise DY130 first) into a safe
% location, and keep it in your Workspace. 
% For example if you have choosen to process the DY130 CTD profiles  
% (cruise_opt=1) then save into your computere the DY130_CTD_profiles_table
% (the result of the CTD_struct2table that we executed in the previous line)
% After doing this clear your Workspace (clear all)

%NOW START OVER FROM THE BEGINNING WITH THE OTHER CRUISE CALIBRATION 
% THROUGH OUT THE PREVIOUS SECTION (set cruise_opt=2 to do JC231) AND RUN 
% THE LAST FUNCTION AGAIN (LINE 274)
%**************************************************************************

%Now with the two calibrated cruise tables in the workspace (you migth want
% to get ride of all the other variables) you can call the next function
% You should have at this stage two tables for each cruise, probably named
% as DY130_CTD_profiles_table and JC231_CTD_profiles_table (perhaps you 
% have been testing this codes with other cruises, so you will get 
% different names as results)

%--------------------------------2----------------------------------------

%STAGE TWO: Calibrating the sensor in the mooring with the calibrated CTD
%cast from the deployment and recovery of the moooring. 
%The location of the sensor
currentDir = pwd;

filepath=fullfile(currentDir,'Data_example/Timeseries_DY130_JC231/OneDrive_2_13-04-2023/timeseries/buoy/DY130_Apr2021_SBE37-ODO-16503/DY130_Apr2021_SBE37-ODO_sn16503_1m-corrected-Jon.xlsx');
opts=detectImportOptions(filepath);
microcat_table=readtable(filepath,opts);

%Change the name of this two variables if you different cruises
first_cruise=DY130_CTD_profiles_table;
second_cruise=JC231_CTD_profiles_table;

microcat_table=SAL_TimeSeries_offset_drift_adjust(first_cruise,second_cruise,microcat_table);

microcat_table=DO_TimeSeries_offset_drift_adjust(first_cruise,second_cruise,microcat_table);

%All the Gibbs Equations functions to ultimate calculate oxygen saturation
%and oxygen supersaturation.On the microcat data. PAP station Lat=48.9667, 
% Lon=-16.4167
microcat_table.SA=gsw_SA_from_SP(microcat_table.SalinityPractical_PSU_,microcat_table.PressureStrainGauge_db_, ...
    -16.4167,48.9667);
microcat_table.CT=gsw_CT_from_t(microcat_table.SA,microcat_table.Temperature_ITS_90DegC_, ...
    microcat_table.PressureStrainGauge_db_);
microcat_table.O2Sat=gsw_O2sol(microcat_table.SA,microcat_table.CT, ...
    microcat_table.PressureStrainGauge_db_,-16.4167,48.9667);
microcat_table.Supersaturation=((microcat_table.OxygenSBE63_umol_kg_Offset_linear_drift_corrected./microcat_table.O2Sat)-1)*100;





%--------------------------------3----------------------------------------
%STAGE THREE: Checking there are any floats during the year that we are
%working on. The search footprint is based on the area that Henson et al., 2016 
% defined for for PAP observations
area=1.43E6;
centroid=[48.9667,-16.4167]; %The location of the PAP mooring
[vertices] = centroid_area_to_vertices(centroid, area); %This can be changed 
                                                        %if you have other
                                                        %vertices with the
                                                        %shape of the
                                                        %footprint. For
                                                        %instance if you
                                                        %get from Steph the
                                                        %actual polygon
                                                        %defined for PAP
plot_footprints(centroid, vertices)


%This function below will make a selection of the floats nearby and get the
%data at the depth iof the sensor to use it in the following lines for
%having an extra comparison. It will also display in the command window how
%many floats and profiles you can get for the given time, space and sensor
%being selected.
[PAP_DOXY_float_DY130_JC231,~,floats_ids,~,TT_float_target_depth]=float_in_mooring_footprint( ...
    vertices,microcat_table,'DOXY');


%This line of code will show you which floats are present for the
%determined area, and the trajectories that they had.
show_trajectories(floats_ids,'color','multiple')

%This line will add to the float data table (the table with the relative
%measurements at the same depth that the depth of the mooring sensor) a
%column with the distance between the mooring and the floats
TT_float_target_depth.dist_from_mooring=deg2km(distance(TT_float_target_depth{:,1},...
    TT_float_target_depth{:,2},centroid(1),centroid(2)));

%All the Gibbs Equations functions to ultimate calculate oxygen saturation
%and oxygen supersaturation. In the float data
TT_float_target_depth.SA=gsw_SA_from_SP(TT_float_target_depth.Sal,TT_float_target_depth.Press, ...
    TT_float_target_depth.Lon,TT_float_target_depth.Lat);
TT_float_target_depth.CT=gsw_CT_from_t(TT_float_target_depth.SA,TT_float_target_depth.Temp, ...
    TT_float_target_depth.Press);
TT_float_target_depth.O2Sat=gsw_O2sol(TT_float_target_depth.SA,TT_float_target_depth.CT, ...
    TT_float_target_depth.Press,TT_float_target_depth.Lon,TT_float_target_depth.Lat);
TT_float_target_depth.Supersaturation=((TT_float_target_depth.DO./TT_float_target_depth.O2Sat)-1)*100;







%Oxygen
figure
sc1=scatter(microcat_table.Datetime,microcat_table.OxygenSBE63_umol_kg_Offset_linear_drift_corrected,20,'k','filled');
hold on
sc2=scatter(TT_float_target_depth.Time,TT_float_target_depth.DO,80,TT_float_target_depth.dist_from_mooring,'filled');

div=50;
zmax=round(max(TT_float_target_depth.dist_from_mooring)/div)*div;
zmin=round(min(TT_float_target_depth.dist_from_mooring)/div)*div;


cb=colorbar;
colormap(jet(round((zmax-zmin)/div)))
cb.Title.String='Float';
cb.Label.String='dist from PAP (km)';
cb.Limits=[zmin zmax];
box on
grid on
ax=gca;
ax.FontSize=14;
ax.YLabel.String='Dissolved Oxygen [\mumol kg^-^1]';
ax.XMinorTick='on';
legend([sc1],'PAP obs')


%Supersaturation difference between float and mooring
figure
sc1=scatter(microcat_table.Datetime,microcat_table.Supersaturation,20,'k','filled');
hold on
sc2=scatter(TT_float_target_depth.Time,TT_float_target_depth.Supersaturation,80,TT_float_target_depth.dist_from_mooring,'filled');

div=50;
zmax=round(max(TT_float_target_depth.dist_from_mooring)/div)*div;
zmin=round(min(TT_float_target_depth.dist_from_mooring)/div)*div;


cb=colorbar;
colormap(jet(round((zmax-zmin)/div)))
cb.Title.String='Float';
cb.Label.String='dist from PAP (km)';
cb.Limits=[zmin zmax];
box on
grid on
ax=gca;
ax.FontSize=14;
ax.YLabel.String='Oxygen supersaturation (%)';
ax.XMinorTick='on';
legend([sc1],'PAP obs')



%T-S diagram of floats and mooring data

figure
sc1=scatter(microcat_table.SA,microcat_table.CT,20,'k','filled');
hold on
sc2=scatter(TT_float_target_depth.SA,TT_float_target_depth.CT,60,TT_float_target_depth.dist_from_mooring,'Filled');

div=50;
zmax=round(max(TT_float_target_depth.dist_from_mooring)/div)*div;
zmin=round(min(TT_float_target_depth.dist_from_mooring)/div)*div;


cb=colorbar;
colormap(jet(round((zmax-zmin)/div)))
cb.Title.String='Float';
cb.Label.String='dist from PAP (km)';
cb.Limits=[zmin zmax];

box on
grid on
axis square
ax=gca;
ax.FontSize=14;
ax.YLabel.String='CT (°C)';
ax.XLabel.String='SA [g kg^-^1]';
ax.XMinorTick='on';
legend([sc1],'PAP obs')
