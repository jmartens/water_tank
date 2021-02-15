function handles = ProcessProfiles(handles)
% ProcessProfiles is called by WaterTankAnalysis and subfunctions and
% applies each data processing technique to the provided raw profiles.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2017 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% If raw data exists
if isfield(handles, 'data') && ~isempty(handles.data)
    
    % If an EPOM shift is requested, ask user for isocenter
    if get(handles.epom, 'Value') > 2 && ...
            handles.config.ASK_RCAV == 1
        rcav = str2double(inputdlg('Enter cavity radius (mm):', ...
            'EPOM Adjustment', 1, sprintf('%0.1f', ...
            handles.config.DEFAULT_RCAV)));
    
    % Otherwise, use value from selected detectors.txt entry
    else
        rcav = handles.detectors{get(handles.detector, 'Value'), 2} / 2;
    end

    % If this is an electron energy and EPOM is set to 0.6, set to 0.5
    % rcav, and vice versa for photons
    if contains(handles.reference{get(handles.machine, ...
            'Value')}.energies{get(handles.energy, 'Value')}.energy, 'e') ...
            && get(handles.epom, 'Value') == 3
        set(handles.epom, 'Value', 4);
    elseif ~contains(handles.reference{get(handles.machine, ...
            'Value')}.energies{get(handles.energy, 'Value')}.energy, 'e') ...
            && get(handles.epom, 'Value') == 4
        set(handles.epom, 'Value', 3);
    end
    
    % Start waitbar
    progress = waitbar(0, 'Processing profiles');

    % Shift by EPOM
    handles.processed = ShiftProfiles(handles.data.profiles, ...
        get(handles.epom, 'Value'), rcav);
    
    % Update waitbar
    waitbar(0.1, progress);
    
    % Smooth profiles (unless reference will also be smoothed)
    if handles.config.SMOOTH_REFERENCE == 0
        handles.processed = SmoothProfiles(handles.processed, ...
            get(handles.smooth, 'Value'), handles.config);
    end
    
    % Update waitbar
    waitbar(0.3, progress);
    
    % Center profiles (unless reference will also be centered)
    if handles.config.CENTER_REFERENCE == 0 || ...
            get(handles.center, 'Value') == 2
        handles.processed = CenterProfiles(handles.processed, ...
            get(handles.center, 'Value'));
    end
    
    % Update waitbar
    waitbar(0.5, progress);
    
    % Define reference file and path
    ref_file = [handles.reference{get(handles.machine, 'Value')}...
        .energies{get(handles.energy, 'Value')}...
        .ssds{get(handles.ssd, 'Value')}.fields{...
        get(handles.fieldsize, 'Value')}, '.dcm'];
    
    if contains(handles.config.REFERENCE_PATH, ':')
        ref_path = fullfile(handles.config.REFERENCE_PATH, ...
            handles.reference{get(handles.machine, 'Value')}.machine, ...
            handles.reference{get(handles.machine, 'Value')}...
            .energies{get(handles.energy, 'Value')}.energy, ...
            handles.reference{get(handles.machine, 'Value')}...
            .energies{get(handles.energy, 'Value')}...
            .ssds{get(handles.ssd, 'Value')}.ssd, filesep);
    elseif handles.config.REFERENCE_PATH(1) == '/'
        ref_path = fullfile(handles.config.REFERENCE_PATH, ...
            handles.reference{get(handles.machine, 'Value')}.machine, ...
            handles.reference{get(handles.machine, 'Value')}...
            .energies{get(handles.energy, 'Value')}.energy, ...
            handles.reference{get(handles.machine, 'Value')}...
            .energies{get(handles.energy, 'Value')}...
            .ssds{get(handles.ssd, 'Value')}.ssd, filesep);
    else
        ref_path = fullfile(pwd, handles.config.REFERENCE_PATH, ...
            handles.reference{get(handles.machine, 'Value')}.machine, ...
            handles.reference{get(handles.machine, 'Value')}...
            .energies{get(handles.energy, 'Value')}.energy, ...
            handles.reference{get(handles.machine, 'Value')}...
            .energies{get(handles.energy, 'Value')}...
            .ssds{get(handles.ssd, 'Value')}.ssd, filesep);
    end
    
    % Set origin, first using origin file, then default reference
    if isfile([ref_path, 'origin.txt'])
        Event(['Opening origins file ', ref_path, 'origin.txt']);
        fid = fopen(filename, 'r');
        c = textscan(fid, '%s', 'Delimiter', '=', 'CommentStyle', '%');
        fclose(fid);
        for i = 1:2:length(c{1})
            if strtrim(c{1}{i}) == 'ORIGINX'
                handles.origin(1) = str2double(strtrim(c{1}{i+1}));
            elseif strtrim(c{1}{i}) == 'ORIGINY'
                handles.origin(2) = str2double(strtrim(c{1}{i+1}));
            elseif strtrim(c{1}{i}) == 'ORIGINZ'
                handles.origin(3) = str2double(strtrim(c{1}{i+1}));
            end
        end
    elseif ~isfield(handles, 'origin') || isempty(handles.origin)
        handles.origin = [handles.config.REFERENCE_ORIGINX ...
            handles.config.REFERENCE_ORIGINY ...
            handles.config.REFERENCE_ORIGINZ];
    end
    
    % Prompt user to confirm origin, if flag is set
    if handles.config.ASK_REFERENCE_ORIGIN == 1
        handles.origin = str2double(inputdlg({'Origin IEC X (mm):', ...
            'Origin IEC Y (mm):', 'Origin IEC Z (mm):'}, ...
            'Enter DICOM Origin', 1, {sprintf('%0.1f', handles.origin(1)), ...
            sprintf('%0.1f', handles.origin(2)), sprintf('%0.1f', ...
            handles.origin(3))}));
    end
    
    % Execute ExtractRefProfile
    handles.processed = ExtractRefProfile(handles.processed, ...
        [ref_path, ref_file], handles.origin);
    
    % If smooth reference flag is set, smooth profiles now
    if handles.config.SMOOTH_REFERENCE == 1 && ...
            get(handles.smooth, 'Value') > 1
        handles.processed = SmoothProfiles(handles.processed, ...
            get(handles.smooth, 'Value'), handles.config);
    end
    
    % Update waitbar
    waitbar(0.7, progress);
    
    % Convolve profiles, passing detector name, rcav, and energy
    handles.processed = ConvolveProfiles(handles.processed, ...
        get(handles.convolve, 'Value'), handles.detectors{...
        get(handles.detector, 'Value'), 1}, rcav, ...
        handles.reference{get(handles.machine, ...
        'Value')}.energies{get(handles.energy, 'Value')}.energy);
   
    % If center reference flag is set, center profiles now
    if handles.config.CENTER_REFERENCE == 1 && ...
            get(handles.center, 'Value') > 2
        handles.processed = CenterProfiles(handles.processed, ...
            get(handles.center, 'Value'), 1);
    end
    
    % Convert to depth dose if energy is an electron
    if ~isempty(regexpi(handles.reference{get(handles.machine, ...
            'Value')}.energies{get(handles.energy, 'Value')}.energy, 'e'))
        handles.processed = ConvertDepthDose(handles.processed, ...
            get(handles.pdi, 'Value'), handles.config, rcav);
    end
    
    % Update waitbar
    waitbar(0.9, progress);

    % Normalize profiles
    handles.processed = ScaleProfiles(handles.processed, ...
        get(handles.normalize, 'Value'));
    
    % Close
    waitbar(1.0, progress, 'Done');
    close(progress);
    
    % Clear temporary variables
    clear rcav progress;
end