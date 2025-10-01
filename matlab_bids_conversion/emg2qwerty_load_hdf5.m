function EEG = emg2qwerty_load_hdf5(hdf5_path)
% emg2qwerty_load_hdf5 - Load emg2qwerty HDF5 session file into EEGLAB structure
%
% Usage:
%   EEG = emg2qwerty_load_hdf5(hdf5_path)
%
% Inputs:
%   hdf5_path - Path to the emg2qwerty HDF5 session file
%
% Outputs:
%   EEG       - EEGLAB structure with EMG data, events, and metadata
%
% Description:
%   Loads a single emg2qwerty HDF5 session file and converts it to EEGLAB
%   format. The HDF5 file contains:
%   - Left EMG: 16 channels, 2kHz sampling
%   - Right EMG: 16 channels, 2kHz sampling
%   - Timestamps for each sample
%   - Keystrokes: precise keystroke events with timing
%   - Prompts: text prompts displayed to the user
%
% Example:
%   EEG = emg2qwerty_load_hdf5('/path/to/session.hdf5');
%
% Author: Yahya Shirazi, SCCN, INC, UCSD
% Date: 2025-09-30

    % Check if file exists
    if ~exist(hdf5_path, 'file')
        error('File not found: %s', hdf5_path);
    end

    % Extract session name from filename
    [~, session_name, ~] = fileparts(hdf5_path);

    fprintf('Loading HDF5 file: %s\n', session_name);

    % Read HDF5 structure
    h5_group = '/emg2qwerty';

    % Read timeseries data (compound dataset)
    fprintf('  Reading EMG data...\n');
    timeseries = h5read(hdf5_path, [h5_group '/timeseries']);

    % Extract fields from compound dataset
    % Data is already stored as channels x samples
    emg_left = timeseries.emg_left;   % 16 x samples
    emg_right = timeseries.emg_right; % 16 x samples
    timestamps = timeseries.time;     % samples x 1

    % Concatenate left and right EMG (32 channels total)
    emg_data = [emg_left; emg_right];  % 32 x samples

    % Check for irregular sampling and resample if needed
    fprintf('  Checking sampling regularity...\n');
    intervals = diff(timestamps);
    avgInterval = mean(intervals);
    maxDeviation = max(abs(intervals - avgInterval)) / avgInterval;

    if maxDeviation > 0.01  % 1% tolerance
        fprintf('  Irregular sampling detected (%.2f%% deviation)\n', maxDeviation*100);
        fprintf('  Resampling to regular 2000 Hz...\n');

        % Target regular sampling at 2000 Hz
        targetSrate = 2000;
        numSamples = length(timestamps);
        regularTimestamps = linspace(timestamps(1), timestamps(end), numSamples)';

        % Resample each channel using interpolation
        emg_resampled = zeros(size(emg_data));
        for iChan = 1:size(emg_data, 1)
            emg_resampled(iChan, :) = interp1(timestamps, emg_data(iChan, :), regularTimestamps, 'pchip');
        end

        % Store original for event mapping
        timestamps_original = timestamps;
        timestamps = regularTimestamps;
        emg_data = emg_resampled;

        fprintf('  Resampling complete\n');
    else
        fprintf('  Sampling is regular (%.4f%% deviation)\n', maxDeviation*100);
        timestamps_original = timestamps;
    end

    % Read metadata
    fprintf('  Reading metadata...\n');
    user = h5readatt(hdf5_path, h5_group, 'user');
    condition = h5readatt(hdf5_path, h5_group, 'condition');
    duration_mins = h5readatt(hdf5_path, h5_group, 'duration_mins');

    % Read keystrokes and prompts (JSON strings)
    keystrokes_json = h5readatt(hdf5_path, h5_group, 'keystrokes');
    prompts_json = h5readatt(hdf5_path, h5_group, 'prompts');

    % Parse JSON
    keystrokes = jsondecode(keystrokes_json);
    prompts = jsondecode(prompts_json);

    % Initialize EEGLAB structure
    EEG = eeg_emptyset();

    % Set basic parameters
    EEG.setname = session_name;
    EEG.filename = '';
    EEG.filepath = '';
    EEG.subject = user;
    EEG.condition = condition;
    EEG.session = [];  % Will be set during batch processing
    EEG.comments = sprintf('emg2qwerty session: %s, user: %s, duration: %.2f mins', ...
                           session_name, user, duration_mins);

    % Set data
    EEG.data = emg_data;  % 32 x samples
    EEG.nbchan = size(emg_data, 1);
    EEG.pnts = size(emg_data, 2);
    EEG.trials = 1;  % Continuous data
    EEG.srate = 2000;  % 2 kHz sampling rate
    EEG.xmin = timestamps(1);
    EEG.xmax = timestamps(end);
    % Use regular timestamps (resampled if irregular)
    EEG.times = timestamps';

    % CRITICAL: Set datatype to 'emg' to trigger EMG-BIDS export
    EEG.etc.datatype = 'emg';

    % Set up channel information
    fprintf('  Setting up channels...\n');
    for i = 1:16
        % Left wrist channels (0-15)
        % Channel names must be UNIQUE across the entire dataset
        EEG.chanlocs(i).labels = sprintf('EMG%d', i-1);
        EEG.chanlocs(i).type = 'EMG';
        EEG.chanlocs(i).units = 'V';
        EEG.chanlocs(i).reference = 'bipolar';
        EEG.chanlocs(i).target_muscle = 'forearm muscles';
        % signal_electrode refers to the physical electrode (can be duplicated across groups)
        % Use E0-E15 naming (same physical device worn on both arms)
        EEG.chanlocs(i).signal_electrode = sprintf('E%d', i-1);
        EEG.chanlocs(i).group = 'left';

        % Right wrist channels (16-31)
        % Channel names continue numbering to ensure uniqueness
        EEG.chanlocs(16+i).labels = sprintf('EMG%d', 15+i);  % 16-31
        EEG.chanlocs(16+i).type = 'EMG';
        EEG.chanlocs(16+i).units = 'V';
        EEG.chanlocs(16+i).reference = 'bipolar';
        EEG.chanlocs(16+i).target_muscle = 'forearm muscles';
        % signal_electrode refers to physical electrode on right wrist (E0-E15)
        EEG.chanlocs(16+i).signal_electrode = sprintf('E%d', i-1);
        EEG.chanlocs(16+i).group = 'right';
    end

    % Set up coordinate systems for both forearms
    % This will trigger space-leftForearm_coordsystem.json and space-rightForearm_coordsystem.json at root
    EEG.chaninfo.BIDS.coordsystems = {};

    % Left forearm coordinate system
    leftCS = struct();
    leftCS.space = 'leftForearm';
    leftCS.EMGCoordinateSystem = 'Other';
    leftCS.EMGCoordinateSystemDescription = 'X: USP → RSP; Y: Right-hand rule (limits: Olecranon Process → Cubital Fossa); Z: midpoint RSP-USP → LHE; Radial Styloid Process (RSP); Ulnar Styloid Process (USP), Lateral Humerus Epicondyle (LHE), Posterior Elbow (Olecranon Process)';
    leftCS.EMGCoordinateUnits = 'percent';
    EEG.chaninfo.BIDS.coordsystems{1} = leftCS;

    % Right forearm coordinate system
    rightCS = struct();
    rightCS.space = 'rightForearm';
    rightCS.EMGCoordinateSystem = 'Other';
    rightCS.EMGCoordinateSystemDescription = 'X: RSP → USP; Y: Right-hand rule (limits: Olecranon Process → Cubital Fossa); Z: midpoint RSP-USP → LHE; Radial Styloid Process (RSP); Ulnar Styloid Process (USP), Lateral Humerus Epicondyle (LHE), Posterior Elbow (Olecranon Process)';
    rightCS.EMGCoordinateUnits = 'percent';
    EEG.chaninfo.BIDS.coordsystems{2} = rightCS;

    % Create events from keystrokes
    fprintf('  Creating events from keystrokes...\n');
    nevents = length(keystrokes);
    if nevents > 0
        EEG.event = struct('type', {}, 'latency', {}, 'duration', {}, ...
                          'key', {}, 'urevent', {});

        for i = 1:nevents
            ks = keystrokes(i);

            % Find latency in samples from original irregular timestamps
            [~, idx_start] = min(abs(timestamps_original - ks.start));
            [~, idx_end] = min(abs(timestamps_original - ks.end));

            % Create event
            EEG.event(i).type = sprintf('keystroke_%s', ks.key);
            EEG.event(i).latency = idx_start;
            EEG.event(i).duration = idx_end - idx_start;
            EEG.event(i).key = ks.key;
            EEG.event(i).urevent = i;
        end
    end

    % Add prompt events
    fprintf('  Adding prompt events...\n');
    nprompts = length(prompts);
    event_offset = nevents;

    for i = 1:nprompts
        prompt = prompts(i);

        % Only process text_prompt events
        if strcmp(prompt.name, 'text_prompt') && ~isempty(prompt.payload)
            % Find latency in samples from original irregular timestamps
            [~, idx_start] = min(abs(timestamps_original - prompt.start));
            [~, idx_end] = min(abs(timestamps_original - prompt.end));

            % Get prompt text
            prompt_text = prompt.payload.text;
            % Replace newline character
            prompt_text = strrep(prompt_text, char(9166), '\n');  % ⏎ to \n

            % Create event
            event_idx = event_offset + i;
            EEG.event(event_idx).type = 'prompt';
            EEG.event(event_idx).latency = idx_start;
            EEG.event(event_idx).duration = idx_end - idx_start;
            EEG.event(event_idx).prompt_text = prompt_text;
            EEG.event(event_idx).urevent = event_idx;
        end
    end

    % Sort events by latency
    if ~isempty(EEG.event)
        [~, sort_idx] = sort([EEG.event.latency]);
        EEG.event = EEG.event(sort_idx);

        % Update urevent indices
        for i = 1:length(EEG.event)
            EEG.event(i).urevent = i;
        end
    end

    % Update urevent structure
    EEG.urevent = EEG.event;

    % Check consistency
    EEG = eeg_checkset(EEG);

    fprintf('  Loaded: %d channels, %d samples (%.2f s), %d events\n', ...
            EEG.nbchan, EEG.pnts, EEG.xmax, length(EEG.event));
end
