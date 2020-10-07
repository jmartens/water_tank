function data = CalcProfileStats(varargin)
% CalcProfileStats computes a cell array (table) of statistics based on
% a provided set of profiles. If called with no inputs, it will return a 
% an empty table.
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

% Initialize data table
data = {
    'Axis'
    'Depth'
    'TG-45 Flatness'
    'Varian Symmetry'
    'Area Symmetry'
    'FWXM' 
    'Reference FWXM' 
    'Difference'
    'FWXM Center'
    'Local RMS Error'
    'Local Max Error'
    'Mean Gamma'
    'Max Gamma'
    'Gamma Pass Rate'
};

% If no data was passed
if nargin == 0
    return;
else
    profiles = varargin{1};
end

% Adjust names for FWXM stat
p = varargin{2};
if p == 0.5
    data{6} = 'FWHM';
    data{7} = 'Reference FWHM';
    data{9} = 'FWHM Center';
    p = 0.25;
elseif p == 0.25
    data{6} = 'FWQM';
    data{7} = 'Reference FWQM';
    data{9} = 'FWQM Center';
end

% Initialize counter
c = 1;

% Loop through profiles
for i = 1:length(profiles)
    
    % If this is an X, Y, or diagonal profile
    if (max(profiles{i}(:,1)) - min(profiles{i}(:,1))) > 1 || ...
            (max(profiles{i}(:,2)) - min(profiles{i}(:,2))) > 1
        
        % Increment counter
        c = c + 1;
        
        % List the axis and store the axis
        if (max(profiles{i}(:,1)) - min(profiles{i}(:,1))) > 1 && ...
                (max(profiles{i}(:,2)) - min(profiles{i}(:,2))) > 1
            
            % Set positive or negative diagonal based on X/Y product
            if mean(profiles{i}(:,1) .* profiles{i}(:,2)) > 0
                data{1,c} = 'PDIAG';
            else 
                data{1,c} = 'NDIAG';
            end
            
            % Store x axis as square root
            x = sqrt(profiles{i}(:,1).^2 + profiles{i}(:,2).^2) .* ...
                sign(profiles{i}(:,1));
            
        elseif (max(profiles{i}(:,1)) - min(profiles{i}(:,1))) > 1
            data{1,c} = 'IEC X';
            x = profiles{i}(:,1);
        else
            data{1,c} = 'IEC Y';
            x = profiles{i}(:,2);
        end
        
        % List depth
        data{2,c} = sprintf('%0.1f mm', profiles{i}(1,3));
        
        % Find index of maximum value
        [~, I] = max(profiles{i}(:,4));

        % Find highest lower index just below half maximum
        lI = find(profiles{i}(1:I,4) < ...
            p * max(profiles{i}(:,4)), 1, 'last');

        % Find lowest upper index just above half maximum
        uI = find(profiles{i}(I:end,4) < ...
            p * max(profiles{i}(:,4)), 1, 'first');

        % Calculate FWHM and offset
        try
            % Interpolate to find lower half-maximum value
            l = interp1(profiles{i}(lI-1:lI+2,4), ...
                x(lI-1:lI+2), p * max(profiles{i}(:,4)), 'linear');

            % Interpolate to find upper half-maximum value
            u = interp1(profiles{i}(I+uI-3:I+uI,4), ...
                x(I+uI-3:I+uI), p * max(profiles{i}(:,4)), 'linear');

            % Compute FWXM and offset
            fwhm = sprintf('%0.1f mm', sum(abs([l u])));
            offset = sprintf('%0.2f mm', (l+u)/2);
        catch
            Event(sprintf('Profile %i FWXM could not be computed', i),... 
                'WARN');

            % Set full range
            lI = 1;
            uI = length(x) - I;
            
            % Set FWHM and offset as undefined
            fwhm = 'N/A';
            offset = 'N/A';
        end

        % Compute the range and center indices for the central 80%
        range = ceil((lI + I + uI)/2 - abs(I + uI - lI) * 0.4):...
            floor((lI + I + uI)/2 + abs(I + uI - lI) * 0.4);
        center = round(interp1(x, 1:length(x), 0, 'linear'));
        
        % Calculate AAPM TG-45 Flatness
        data{3,c} = sprintf('%0.2f%%', (max(profiles{i}(range,4)) - ...
            min(profiles{i}(range,4)))/(max(profiles{i}(range,4)) + ...
            min(profiles{i}(range,4))) * 100);

        % Calculate Varian Point Symmetry
        data{4,c} = sprintf('%0.2f%%', ...
            max(abs(profiles{i}(range(1):center,4) - ...
            interp1(x, profiles{i}(:,4), -x(range(1):center), 'linear')) / ...
            interp1(x, profiles{i}(:,4), 0, 'linear')) * 100);

        % Calculate Area Symmetry (note, areas are normalized to the
        % data range, as rounding differences when determining the range 
        % may result in un-balanced areas for low-resolution profiles)
        left = horzcat(x(range(1):center), ...
            profiles{i}(range(1):center,4));
        right = horzcat(x(center:range(end)), ...
            profiles{i}(center:range(end),4));
        data{5,c} = sprintf('%0.2f%%', ...
            (trapz(right(:,1), right(:,2))/abs(right(end,1)-right(1,1)) - ...
            trapz(left(:,1), left(:,2))/abs(left(end,1)-left(1,1))) / ...
            (trapz(right(:,1), right(:,2))/abs(right(end,1)-right(1,1)) + ...
            trapz(left(:,1), left(:,2))/abs(left(end,1)-left(1,1))) * 200);

        % Store FWXM
        data{6,c} = fwhm;
 
        % Find reference highest lower index just below half maximum
        lI = find(profiles{i}(1:I,5) < p * ...
            max(profiles{i}(:,5)), 1, 'last');

        % Find reference lowest upper index just above half maximum
        uI = find(profiles{i}(I:end,5) < p * ...
            max(profiles{i}(:,5)), 1, 'first');

        % Calculate reference FWHM
        try
            % Interpolate to find lower half-maximum value
            l = interp1(profiles{i}(lI-1:lI+2,5), ...
                x(lI-1:lI+2), p * max(profiles{i}(:,5)), 'linear');

            % Interpolate to find upper half-maximum value
            u = interp1(profiles{i}(I+uI-3:I+uI,5), ...
                x(I+uI-3:I+uI), p * max(profiles{i}(:,5)), 'linear');

            % Compute FWXM and offset
            data{7,c} = sprintf('%0.1f mm', sum(abs([l u])));
            
            % Compute FWXM difference
            if ~strcmp(fwhm, 'N/A')
                data{8,c} = sprintf('%0.2f mm', str2double(fwhm(1:end-3)) - ...
                    sum(abs([l u])));
            end
        catch
            Event(sprintf('Profile %i Reference FWXM could not be computed', ...
                i), 'WARN');

            % Set FWHM as undefined
            data{7,c} = 'N/A';
            data{8,c} = 'N/A';
        end
        
        % Store offset
        data{9,c} = offset;
        
        % Calculate RMS error
        data{10,c} = sprintf('%0.2f%%', sqrt(mean(((profiles{i}(range,4) - ...
            profiles{i}(range,5)) ./ profiles{i}(range,5)).^2)) * 100);
        
        % Calculate Max error
        data{11,c} = sprintf('%0.2f%%', max(abs(profiles{i}(range,4) - ...
            profiles{i}(range,5)) ./ profiles{i}(range,5)) * 100);
        
        % Calculate Mean Gamma
        data{12,c} = sprintf('%0.2f', mean(profiles{i}(range,6)));
        
        % Calculate Max Gamma
        data{13,c} = sprintf('%0.2f', max(profiles{i}(range,6)));
        
        % Calculate Gamma Pass Rate
        data{14,c} = sprintf('%0.1f%%', sum(profiles{i}(range,6) < 1) / ...
            length(range) * 100);
    end
end