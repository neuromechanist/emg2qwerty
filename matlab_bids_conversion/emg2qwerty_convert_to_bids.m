function emg2qwerty_convert_to_bids(hdf5_file, bids_root, varargin)
% emg2qwerty_convert_to_bids - Convert emg2qwerty HDF5 to BIDS format
%
% Usage:
%   emg2qwerty_convert_to_bids(hdf5_file, bids_root)
%   emg2qwerty_convert_to_bids(hdf5_file, bids_root, 'key', value, ...)
%
% Inputs:
%   hdf5_file  - Path to emg2qwerty HDF5 session file
%   bids_root  - Output directory for BIDS dataset
%
% Optional Parameters:
%   'subject'     - Subject ID (default: extracted from metadata)
%   'session'     - Session number (default: extracted from filename)
%   'task'        - Task name (default: 'typing')
%   'eeglab_path' - Path to EEGLAB (default: auto-detect)
%   'bids_path'   - Path to eeg-bids plugin (default: auto-detect)
%
% Example:
%   % Convert single file
%   emg2qwerty_convert_to_bids('session.hdf5', '/output/bids');
%
%   % Batch convert all files
%   files = dir('/Volumes/data/FRL/emg2qwerty/*.hdf5');
%   for i = 1:length(files)
%       filepath = fullfile(files(i).folder, files(i).name);
%       emg2qwerty_convert_to_bids(filepath, '/output/bids');
%   end
%
% Description:
%   Converts emg2qwerty HDF5 session files to BIDS-EMG format using the
%   eeg-bids MATLAB plugin. The conversion includes:
%   - 32-channel EMG data (16 left + 16 right wrist)
%   - Keystroke events with precise timing
%   - Prompt events with text descriptions
%   - Channel locations and coordinate system
%   - Full BIDS metadata (JSON sidecars)
%
% Dependencies:
%   - EEGLAB (https://sccn.ucsd.edu/eeglab/)
%   - eeg-bids plugin (https://github.com/sccn/eeg-bids)
%   - emg2qwerty_load_hdf5.m
%   - emg2qwerty_set_chanlocs.m
%
% Author: Yahya Shirazi, SCCN, INC, UCSD
% Date: 2025-09-30

    % Parse inputs
    p = inputParser;
    addRequired(p, 'hdf5_file', @ischar);
    addRequired(p, 'bids_root', @ischar);
    addParameter(p, 'subject', '', @ischar);
    addParameter(p, 'session', '', @ischar);
    addParameter(p, 'task', 'typing', @ischar);
    addParameter(p, 'eeglab_path', '', @ischar);
    addParameter(p, 'bids_path', '', @ischar);
    parse(p, hdf5_file, bids_root, varargin{:});

    % Extract parameters
    subject_id = p.Results.subject;
    session_id = p.Results.session;
    task_name = p.Results.task;

    % Check if EEGLAB is in path
    if ~exist('eeg_emptyset', 'file')
        error(['EEGLAB not found. Please add EEGLAB to the MATLAB path or ', ...
               'specify the path using ''eeglab_path'' parameter.']);
    end

    % Check if eeg-bids plugin is available
    if ~exist('bids_export', 'file')
        error(['eeg-bids plugin not found. Please install it from: ', ...
               'https://github.com/sccn/eeg-bids']);
    end

    fprintf('========================================\n');
    fprintf('emg2qwerty to BIDS Converter\n');
    fprintf('========================================\n');

    % Load HDF5 file into EEGLAB structure
    EEG = emg2qwerty_load_hdf5(hdf5_file);

    % Set channel locations
    EEG = emg2qwerty_set_chanlocs(EEG);

    % Extract subject and session from metadata if not provided
    if isempty(subject_id)
        % Try to get subject from user field
        subject_id = EEG.subject;
        % Clean up subject ID (remove any non-alphanumeric characters)
        subject_id = regexprep(subject_id, '[^a-zA-Z0-9]', '');
    end

    if isempty(session_id)
        % Extract session number from filename
        % Format: YYYY-MM-DD-TIMESTAMP-keystrokes[-USER].hdf5
        [~, fname, ~] = fileparts(hdf5_file);
        tokens = strsplit(fname, '-');
        % Use timestamp as session identifier
        if length(tokens) >= 4
            session_id = tokens{4};  % timestamp
        else
            session_id = '01';
        end
    end

    fprintf('\nConverting to BIDS format:\n');
    fprintf('  Subject: sub-%s\n', subject_id);
    fprintf('  Session: ses-%s\n', session_id);
    fprintf('  Task: %s\n', task_name);

    % Prepare BIDS export parameters
    % General information (gInfo)
    gInfo = struct();
    gInfo.Name = 'emg2qwerty';
    gInfo.BIDSVersion = 'BEP-034';  % EMG extension
    gInfo.License = 'CC-BY-NC-SA-4.0';
    gInfo.Authors = {'Meta Reality Labs CTRL-labs'};
    gInfo.ReferencesAndLinks = {'https://github.com/facebookresearch/emg2qwerty', ...
                                'https://arxiv.org/abs/2410.20081'};
    gInfo.DatasetDOI = '';

    % Task-level information (tInfo)
    tInfo = struct();
    tInfo.TaskName = task_name;
    tInfo.TaskDescription = ['Touch typing on a QWERTY keyboard while wearing ' ...
                            'EMG wristbands. Participants typed prompted text.'];
    tInfo.InstitutionName = 'Meta Reality Labs';
    tInfo.InstitutionAddress = '';
    tInfo.Manufacturer = 'CTRL-Labs at Meta Reality Labs';
    tInfo.ManufacturersModelName = 'sEMG Research Device (sEMG-RD)';
    tInfo.SamplingFrequency = 2000;
    tInfo.PowerLineFrequency = 60;
    tInfo.HardwareFilters = struct('Highpass', struct('CutoffHz', 20), ...
                                   'Lowpass', struct('CutoffHz', 850));
    tInfo.SoftwareFilters = 'n/a';
    tInfo.RecordingType = 'continuous';
    tInfo.RecordingDuration = EEG.xmax;

    % EMG-specific metadata
    tInfo.EMGChannelCount = 32;
    tInfo.EMGPlacementScheme = 'Other';
    tInfo.EMGPlacementSchemeDescription = ['Two wristbands with 16 dry electrodes each, ' ...
                                           'placed on left and right wrists. ' ...
                                           'See channels.tsv for details.'];
    tInfo.EMGReference = 'bipolar';
    tInfo.EMGGround = 'n/a';

    % Coordinate system information
    tInfo.EMGCoordinateSystem = 'Other';
    tInfo.EMGCoordinateSystemDescription = ['Left wrist: X: USP → RSP; ' ...
        'Y: Right-hand rule; Z: midpoint RSP-USP → LHE. ' ...
        'Right wrist: Mirrored placement. ' ...
        'RSP: Radial Styloid Process; USP: Ulnar Styloid Process; ' ...
        'LHE: Lateral Humerus Epicondyle'];
    tInfo.EMGCoordinateUnits = 'percent';

    % Save EEG to temporary file for bids_export
    temp_file = fullfile(tempdir, [EEG.setname '.set']);
    pop_saveset(EEG, 'filename', temp_file);

    % Prepare file structure for bids_export
    % The bids_export function expects specific formats
    files(1).file = {temp_file};  % Must be cell array
    files(1).session = str2double(session_id);
    if isnan(files(1).session)
        % If session_id is not numeric, use 1
        files(1).session = 1;
    end
    files(1).run = 1;
    files(1).task = {task_name};  % Must be cell array

    % Subject information (cell array with header row + data rows)
    % Row 1 is header, subsequent rows are participants
    participant_info = cell(2, 3);  % 2 rows (header + 1 participant), 3 columns
    participant_info{1,1} = 'participant_id';
    participant_info{1,2} = 'age';
    participant_info{1,3} = 'sex';
    participant_info{2,1} = subject_id;
    participant_info{2,2} = 'n/a';
    participant_info{2,3} = 'n/a';

    % Create BIDS output directory
    if ~exist(bids_root, 'dir')
        mkdir(bids_root);
    end

    fprintf('\nExporting to BIDS...\n');

    try
        % Call bids_export (first argument is files structure, not EEG)
        % Create participant description structure
        pInfoDesc = struct();
        pInfoDesc.participant_id.Description = 'Unique participant identifier';
        pInfoDesc.age.Description = 'Age of participant';
        pInfoDesc.age.Units = 'years';
        pInfoDesc.sex.Description = 'Sex of participant';
        pInfoDesc.sex.Levels.M = 'male';
        pInfoDesc.sex.Levels.F = 'female';

        bids_export(files, ...
                   'targetdir', bids_root, ...
                   'gInfo', gInfo, ...
                   'tInfo', tInfo, ...
                   'pInfo', participant_info, ...
                   'pInfoDesc', pInfoDesc, ...
                   'trialtype', {}, ...
                   'renametype', {}, ...
                   'checkresponse', 'off');

        % Clean up temporary file
        if exist(temp_file, 'file')
            delete(temp_file);
        end
        fdt_file = strrep(temp_file, '.set', '.fdt');
        if exist(fdt_file, 'file')
            delete(fdt_file);
        end

        fprintf('\n========================================\n');
        fprintf('Conversion completed successfully!\n');
        fprintf('BIDS dataset location: %s\n', bids_root);
        fprintf('========================================\n');

    catch ME
        fprintf('\n========================================\n');
        fprintf('ERROR during BIDS export:\n');
        fprintf('%s\n', ME.message);
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
        fprintf('========================================\n');
        rethrow(ME);
    end
end
