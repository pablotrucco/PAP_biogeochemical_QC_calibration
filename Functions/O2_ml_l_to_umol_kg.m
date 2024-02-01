function cruise_struct=O2_ml_l_to_umol_kg(cruise_struct)

original_name = evalin('caller', 'inputname(1)');
original_name = string(original_name);

% Get the names of the profiles
subStructNames = fieldnames(cruise_struct);

    for i = 1:length(subStructNames)

        currentSubStruct=subStructNames{i};

        sal=cruise_struct.(currentSubStruct).SAL_MEAN;
        press=cruise_struct.(currentSubStruct).CTDPRS;
        lon=cruise_struct.(currentSubStruct).LONGITUDE;
        lat=cruise_struct.(currentSubStruct).LATITUDE;
        temp=(cruise_struct.(currentSubStruct).CTDTMP_1 + cruise_struct.(currentSubStruct).CTDTMP_2)./2;
        cruise_struct.(currentSubStruct).TEMP_MEAN=temp;
        
        %Absolute salinity
        SA=gsw_SA_from_SP(sal,press,lon,lat);

        cruise_struct.(currentSubStruct).SA=SA;

        %Conservative temperature
        CT=gsw_CT_from_t(SA,temp,press);
        cruise_struct.(currentSubStruct).CT=CT;

        %rho is in situ density in kg/m3
        %rho=gsw_rho(SA,CT,press);
        rho=gsw_rho_CT_exact(SA,CT,press);
        cruise_struct.(currentSubStruct).RHO=rho;
        
        %For references of converting from ml L-1 to umol L-1 
        %https://www.ices.dk/data/tools/Pages/Unit-conversions.aspx

    % Check if field exists before attempting to convert
    if isfield(cruise_struct.(currentSubStruct), 'CTDOXY_ml_L_1')
        cruise_struct.(currentSubStruct).CTDOXY_umol_kg_1=...
            ((cruise_struct.(currentSubStruct).CTDOXY_ml_L_1).*44.661)./(rho./1000);
    end

    if isfield(cruise_struct.(currentSubStruct), 'CTDOXY_ml_L_2')
        cruise_struct.(currentSubStruct).CTDOXY_umol_kg_2=...
            ((cruise_struct.(currentSubStruct).CTDOXY_ml_L_2).*44.661)./(rho./1000);
    end
    


assignin('base', original_name, cruise_struct);


end