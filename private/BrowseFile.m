function handles = BrowseFile(handles)
% BrowseFile is called when the user clicks the BrowseButton, and prompts
% the user to select a file. It then calls ParseProfile on each input file, 
% then executes ProcessProfiles and UpdateResults.
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

% Request the user to select the profile
Event('UI window opened to select file');
[name, path] = uigetfile('*.*', 'Select the profiles to load', ...
    handles.config.DEFAULT_PATH, 'MultiSelect', 'on');

% If a file was selected
if iscell(name) || sum(name ~= 0)

    % If not cell array, cast as one
    if ~iscell(name)
    
        % Update text box with file name
        set(handles.filepath, 'String', fullfile(path, name));
        
        % Store filenames
        files = cell(1);
        files{1} = name;
    else
    
        % Update text box with first file
        set(handles.filepath, 'String', 'Multiple files selected');
        
        % Store filenames
        files = name;
    end
    
    % Log names
    Event([strjoin(files, ' selected\n'), ' selected']);
    
    % Update default path
    handles.config.DEFAULT_PATH = path;
    Event(['Default file path updated to ', path]);
    
    % Clear processed data cell array
    handles.processed = [];
    
    % Execute ParseProfile
    handles.data = ParseProfile(fullfile(path, files), ...
        get(handles.format, 'Value'));
    
    % If filename matching is enabled
    if handles.config.MATCH_FILENAME == 1
        
        % Find closest match for first file name
        if iscell(name)
            [a, b, c, d] = MatchFileName(name{1}, handles.reference);
        else
            [a, b, c, d] = MatchFileName(name, handles.reference);
        end

		% If a match was found
		if a > 0
			% Log selection
			Event(['Reference dataset ', handles.reference{a}.machine, ...
                ', ', handles.reference{a}.energies{b}.energy, ', ', ...
                handles.reference{a}.energies{b}.ssds{c}.ssd, ', ', ...
                handles.reference{a}.energies{b}.ssds{c}.fields{d}, ...
                ' found as most likely matching profile']); 
		else
			% Log lack of selection
			Event('The file name could not be matched to reference data', ...
                'WARN');

			% Use current values
			a = get(handles.machine, 'Value');
			b = get(handles.energy, 'Value');
			c = get(handles.ssd, 'Value');
			d = get(handles.fieldsize, 'Value');
		end

        % Update energy list
        str = cell(size(handles.reference{a}.energies));
        for i = 1:length(handles.reference{a}.energies)
            str{i} = handles.reference{a}.energies{i}.energy;
        end
        set(handles.energy, 'String', str);
        
        % Update SSD list
        str = cell(size(handles.reference{a}.energies{b}.ssds));
        for i = 1:length(handles.reference{a}.energies{b}.ssds)
            str{i} = handles.reference{a}.energies{b}.ssds{i}.ssd;
        end
        set(handles.ssd, 'String', str);
        
        % Update field size list
        str = cell(size(handles.reference{a}.energies{b}.ssds{c}.fields));
        for i = 1:length(handles.reference{a}.energies{b}.ssds{c}.fields)
            str{i} = handles.reference{a}.energies{b}.ssds{c}.fields{i};
        end
        set(handles.fieldsize, 'String', str);

        % Update selection
        set(handles.machine, 'Value', a);
        set(handles.energy, 'Value', b);
        set(handles.ssd, 'Value', c);
        set(handles.fieldsize, 'Value', d);
        
        % Clear temporary variables
        clear a b c d i m str;
    end
    
    % Execute ProcessProfiles
    handles = ProcessProfiles(handles);
    
    % Execute UpdateResults
    handles = UpdateResults(handles);
    
    % Enable save button
    set(handles.saveplots, 'Enable', 'on');
end

% Clear temporary variables
clear name path files;