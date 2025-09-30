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
dataDir = '/Volumes/data/FRL/emg2qwerty';

% Output BIDS directory
bidsRoot = '/Users/yahya/Documents/git/emg2qwerty_bids';

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
fprintf('Starting batch conversion\n');
fprintf('==========================================================\n\n');

% Create output directory
if ~exist(bidsRoot, 'dir')
    mkdir(bidsRoot);
    fprintf('Created output directory: %s\n\n', bidsRoot);
end

% Track statistics
successCount = 0;
failCount = 0;
failedFiles = {};

% Start timer
tic;

% Process each file
for i = 1:numFiles
    fprintf('----------------------------------------------------------\n');
    fprintf('Processing %d/%d: %s\n', i, numFiles, files(i).name);
    fprintf('----------------------------------------------------------\n');

    hdf5File = fullfile(files(i).folder, files(i).name);

    try
        % Convert file
        emg2qwerty_convert_to_bids(hdf5File, bidsRoot, ...
                                   'task', 'typing');

        successCount = successCount + 1;
        fprintf('✓ SUCCESS\n\n');

    catch ME
        failCount = failCount + 1;
        failedFiles{end+1} = files(i).name; %#ok<SAGROW>

        fprintf('✗ FAILED: %s\n', ME.message);
        fprintf('Stack trace:\n');
        for j = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(j).name, ME.stack(j).line);
        end
        fprintf('\n');

        % Continue with next file
        continue;
    end
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
