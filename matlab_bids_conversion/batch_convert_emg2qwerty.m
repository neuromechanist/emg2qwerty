% batch_convert_emg2qwerty - Batch convert emg2qwerty HDF5 files to BIDS
%
% Description:
%   Batch processes all emg2qwerty HDF5 session files in a directory and
%   converts them to BIDS-EMG format using the eeg-bids plugin.
%
% Usage:
%   1. Edit the paths section below
%   2. Run: batch_convert_emg2qwerty
%
% Requirements:
%   - EEGLAB
%   - eeg-bids plugin
%   - emg2qwerty converter scripts in path
%
% Author: Yahya Shirazi, SCCN, INC, UCSD
% Date: 2025-09-30

clear all; close all;

%% ========== CONFIGURATION ==========
% Edit these paths for your system

% Path to EEGLAB
eeglabPath = '/Users/yahya/Documents/git/eeglab';

% Path to eeg-bids plugin (if not in EEGLAB plugins directory)
bidsPluginPath = '/Users/yahya/Documents/git/eeg-bids';

% Path to emg2qwerty HDF5 data
dataDir = '/Volumes/S1/Datasets/FRL/emg2qwerty';

% Output BIDS directory
bidsRoot = '/Volumes/S1/Datasets/FRL/emg2qwerty_bids';

% Path to this converter directory
converterPath = '/Users/yahya/Documents/git/emg2qwerty/matlab_bids_conversion';

%% ========== SETUP ==========
fprintf('==========================================================\n');
fprintf('emg2qwerty Batch BIDS Converter\n');
fprintf('==========================================================\n\n');

% Add EEGLAB to path
fprintf('Setting up EEGLAB...\n');
addpath(eeglabPath);
eeglab nogui;

% Remove any installed eeg-bids plugin and add development version
fprintf('Setting up eeg-bids plugin...\n');
installedPlugins = dir(fullfile(eeglabPath, 'plugins', 'EEG-BIDS*'));
for i = 1:length(installedPlugins)
    pluginDir = fullfile(installedPlugins(i).folder, installedPlugins(i).name);
    rmpath(genpath(pluginDir));
    fprintf('  Removed: %s\n', installedPlugins(i).name);
end
addpath(bidsPluginPath);
fprintf('  Added: %s\n', bidsPluginPath);

% Add converter scripts
fprintf('Adding converter scripts...\n');
addpath(converterPath);

% Verify dependencies
if ~exist('bids_export', 'file')
    error('bids_export not found. Check eeg-bids plugin path.');
end
if ~exist('emg2qwerty_convert_to_bids', 'file')
    error('emg2qwerty_convert_to_bids not found. Check converter path.');
end

fprintf('Setup complete.\n\n');

%% ========== GET FILES ==========
fprintf('Scanning for HDF5 files in: %s\n', dataDir);

% Get all .hdf5 files
files = dir(fullfile(dataDir, '*.hdf5'));
numFiles = length(files);

if numFiles == 0
    error('No HDF5 files found in: %s', dataDir);
end

fprintf('Found %d HDF5 files\n\n', numFiles);

%% ========== CONVERSION ==========
fprintf('==========================================================\n');
fprintf('Starting batch conversion (subject-by-subject)\n');
fprintf('==========================================================\n\n');

% Create output directory
if ~exist(bidsRoot, 'dir')
    mkdir(bidsRoot);
    fprintf('Created output directory: %s\n\n', bidsRoot);
end

% Group files by subject
% Extract subject IDs from filenames
fprintf('Grouping sessions by subject...\n');
subjectFiles = struct();
for i = 1:numFiles
    fname = files(i).name;
    % Extract user ID from filename (last component before .hdf5)
    parts = strsplit(fname, '-');
    % Check if last part contains user ID (before .hdf5)
    lastPart = strrep(parts{end}, '.hdf5', '');
    if ~strcmp(lastPart, 'keystrokes')
        subjectID = lastPart;
    else
        % No user ID in filename - use 'unknown'
        subjectID = 'unknown';
    end

    % Add to struct
    if ~isfield(subjectFiles, ['sub_' subjectID])
        subjectFiles.(['sub_' subjectID]) = {};
    end
    subjectFiles.(['sub_' subjectID]){end+1} = fullfile(files(i).folder, files(i).name);
end

% Get list of subjects
subjects = fieldnames(subjectFiles);
numSubjects = length(subjects);
fprintf('Found %d unique subjects\n\n', numSubjects);

% Track statistics
successCount = 0;
failCount = 0;
failedFiles = {};
subjectStats = struct();

% Start timer
tic;

% Process each subject (all sessions)
for iSubj = 1:numSubjects
    subjectID = subjects{iSubj};
    sessions = subjectFiles.(subjectID);
    numSessions = length(sessions);

    fprintf('==========================================================\n');
    fprintf('Subject %d/%d: %s (%d sessions)\n', iSubj, numSubjects, strrep(subjectID, 'sub_', ''), numSessions);
    fprintf('==========================================================\n');

    subjSuccess = 0;
    subjFail = 0;

    % Process each session for this subject
    for iSess = 1:numSessions
        hdf5File = sessions{iSess};
        [~, fname, ~] = fileparts(hdf5File);

        fprintf('  Session %d/%d: %s\n', iSess, numSessions, fname);

        try
            % Convert file
            emg2qwerty_convert_to_bids(hdf5File, bidsRoot, 'task', 'typing');

            successCount = successCount + 1;
            subjSuccess = subjSuccess + 1;
            fprintf('    ✓ SUCCESS\n');

        catch ME
            failCount = failCount + 1;
            subjFail = subjFail + 1;
            failedFiles{end+1} = fname; %#ok<SAGROW>

            fprintf('    ✗ FAILED: %s\n', ME.message);
        end
    end

    % Subject summary
    fprintf('Subject %s: %d/%d sessions successful\n\n', strrep(subjectID, 'sub_', ''), subjSuccess, numSessions);
    subjectStats.(subjectID).total = numSessions;
    subjectStats.(subjectID).success = subjSuccess;
    subjectStats.(subjectID).failed = subjFail;
end

% Stop timer
elapsedTime = toc;

%% ========== SUMMARY ==========
fprintf('==========================================================\n');
fprintf('Batch Conversion Complete\n');
fprintf('==========================================================\n\n');

fprintf('Results:\n');
fprintf('  Total files:    %d\n', numFiles);
fprintf('  Successful:     %d (%.1f%%)\n', successCount, 100*successCount/numFiles);
fprintf('  Failed:         %d (%.1f%%)\n', failCount, 100*failCount/numFiles);
fprintf('  Elapsed time:   %.1f seconds (%.1f min)\n', elapsedTime, elapsedTime/60);
fprintf('  Time per file:  %.1f seconds\n', elapsedTime/numFiles);

if failCount > 0
    fprintf('\nFailed files:\n');
    for i = 1:length(failedFiles)
        fprintf('  %d. %s\n', i, failedFiles{i});
    end
end

fprintf('\nOutput directory: %s\n', bidsRoot);
fprintf('==========================================================\n');

% Optional: Exit MATLAB (comment out if you want to keep working)
% exit;
