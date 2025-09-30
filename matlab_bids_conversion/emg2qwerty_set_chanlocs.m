function EEG = emg2qwerty_set_chanlocs(EEG)
% emg2qwerty_set_chanlocs - Set channel locations for emg2qwerty data
%
% Usage:
%   EEG = emg2qwerty_set_chanlocs(EEG)
%
% Inputs:
%   EEG - EEGLAB structure
%
% Outputs:
%   EEG - EEGLAB structure with updated channel locations
%
% Description:
%   Sets anatomically-informed 2D electrode positions for the 16+16
%   electrodes arranged around the left and right wrists. The coordinates
%   are based on the emg_TwoWristbands BIDS example and represent electrode
%   positions around the circumference of the forearm/wrist.
%
%   Coordinate system:
%   - Left wrist: X: USP → RSP; Y: Right-hand rule; Z: midpoint RSP-USP → LHE
%   - Right wrist: Mirrored placement
%   - Units: percent of forearm circumference
%
% Author: Yahya Shirazi, SCCN, INC, UCSD
% Date: 2025-09-30

    fprintf('Setting channel locations...\n');

    % Define electrode positions (x, y, z) based on BIDS example
    % Left wrist electrodes (EMG0-EMG15)
    left_positions = [
        0,   50,  10;   % EMG0
        5,   30,  10;   % EMG1
        20,  10,  10;   % EMG2
        30,  0,   10;   % EMG3
        40,  5,   10;   % EMG4
        50,  10,  10;   % EMG5
        70,  20,  10;   % EMG6
        90,  30,  10;   % EMG7
        100, 40,  10;   % EMG8
        90,  60,  10;   % EMG9
        80,  80,  10;   % EMG10
        70,  100, 10;   % EMG11
        60,  100, 10;   % EMG12
        50,  100, 10;   % EMG13
        40,  100, 10;   % EMG14
        20,  90,  10    % EMG15
    ];

    % Right wrist electrodes (EMG0-EMG15, mirrored)
    right_positions = [
        100, 50,  10;   % EMG0
        95,  30,  10;   % EMG1
        80,  10,  10;   % EMG2
        70,  0,   10;   % EMG3
        60,  5,   10;   % EMG4
        50,  10,  10;   % EMG5
        30,  20,  10;   % EMG6
        10,  30,  10;   % EMG7
        0,   40,  10;   % EMG8
        10,  60,  10;   % EMG9
        20,  80,  10;   % EMG10
        30,  100, 10;   % EMG11
        50,  100, 10;   % EMG12
        70,  100, 10;   % EMG13
        80,  100, 10;   % EMG14
        80,  90,  10    % EMG15
    ];

    % Set positions for all channels
    for i = 1:16
        % Left wrist channels (1-16)
        EEG.chanlocs(i).labels = sprintf('EMG%d', i-1);
        EEG.chanlocs(i).X = left_positions(i, 1);
        EEG.chanlocs(i).Y = left_positions(i, 2);
        EEG.chanlocs(i).Z = left_positions(i, 3);
        EEG.chanlocs(i).sph_theta = [];
        EEG.chanlocs(i).sph_phi = [];
        EEG.chanlocs(i).sph_radius = [];
        EEG.chanlocs(i).theta = [];
        EEG.chanlocs(i).radius = [];
        EEG.chanlocs(i).type = 'EMG';

        % Right wrist channels (17-32)
        EEG.chanlocs(16+i).labels = sprintf('EMG%d', i-1);
        EEG.chanlocs(16+i).X = right_positions(i, 1);
        EEG.chanlocs(16+i).Y = right_positions(i, 2);
        EEG.chanlocs(16+i).Z = right_positions(i, 3);
        EEG.chanlocs(16+i).sph_theta = [];
        EEG.chanlocs(16+i).sph_phi = [];
        EEG.chanlocs(16+i).sph_radius = [];
        EEG.chanlocs(16+i).theta = [];
        EEG.chanlocs(16+i).radius = [];
        EEG.chanlocs(16+i).type = 'EMG';
    end

    % Check consistency
    EEG = eeg_checkset(EEG);

    fprintf('  Channel locations set for %d channels\n', EEG.nbchan);
end
