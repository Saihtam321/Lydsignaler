function synthesizer()
    global fs sounds waveform eqGains baseFreq audioPlayers resonatorFreq resonatorBandwidth;

    fs = 44100;  % Sampling frequency
    waveform = 'Sine';  % Initial waveform type
    eqGains = [1.5, 1.0, 0.5];  % Initial EQ settings
    baseFreq = 220;  % Initial base frequency
    resonatorFreq = 440;  % Default resonator frequency
    resonatorBandwidth = 100;  % Default resonator bandwidth
    sounds = cell(1, 12);
    audioPlayers = cell(1, 12);

    generateAllSounds();
    createGUI();
end

function generateAllSounds()
    global fs sounds waveform eqGains baseFreq resonatorFreq resonatorBandwidth;
    t = 0:1/fs:1;  % One second time vector

    for i = 1:12
        f = baseFreq * 2^((i-1)/12);
        wave = generateWave(f, t, waveform);
        wave = applyADSR(wave, fs);
        wave = multiBandEQ(wave, fs, eqGains);
        wave = addBass(wave, fs);
        wave = resonator(wave, fs, resonatorFreq, resonatorBandwidth); 
        wave = applyFadeOut(wave, fs);
        stereoWave = monoToStereoWithPanning(wave, fs, i);
        sounds{i} = stereoWave;
    end
end

function wave = generateWave(f, t, type)
assert(isnumeric(f) && isscalar(f), 'Frequency f must be a scalar');
assert(isvector(t), 'Time vector t must be a vector');

    switch type
        case 'Sine'
            wave = sin(2*pi*f*t);
        case 'Square'
            wave = square(2*pi*f*t);
        case 'Triangle'
            wave = sawtooth(2*pi*f*t, 0.5);
    end
end

function createGUI()
    global fs sounds baseFreq;
    f = uifigure('Name', 'Synthesizer', 'KeyPressFcn', @keyboardPressed);

    % Dropdown for waveform selection
    uidropdown(f, 'Position', [20, 375, 100, 22], 'Items', {'Sine', 'Square', 'Triangle'}, 'ValueChangedFcn', @waveformChanged);


    % Labels and Sliders for EQ bands
    eqLabels = {'Low', 'Mid', 'High'};
    for i = 1:3
        % Label for each slider
        uilabel(f, 'Position', [20, 320-30*i, 100, 22], 'Text', [eqLabels{i} ' Band Gain']);
        
        % Slider for each band
        uislider(f, 'Position', [120, 345-30*i, 150, 3], 'Limits', [0.5, 1.5], 'Value', 1, 'ValueChangedFcn', @(sld, event) eqChanged(sld, i));
    end

    % Slider for adjusting base frequency
    uilabel(f, 'Position', [20, 200, 100, 22], 'Text', 'Base Frequency (Hz)');
    uislider(f, 'Position', [120, 200, 150, 3], 'Limits', [100, 1000], 'Value', baseFreq, 'ValueChangedFcn', @baseFreqChanged);

    % Resonator frequency slider
    uilabel(f, 'Position', [20, 150, 150, 22], 'Text', 'Resonator Frequency');
    uislider(f, 'Position', [180, 150, 150, 3], 'Limits', [100, 2000], 'Value', 440, 'ValueChangedFcn', @(sld, event) resonatorFreqChanged(sld.Value));

    % Resonator bandwidth slider
    uilabel(f, 'Position', [20, 100, 150, 22], 'Text', 'Resonator Bandwidth');
    uislider(f, 'Position', [180, 100, 150, 3], 'Limits', [10, 400], 'Value', 100, 'ValueChangedFcn', @(sld, event) resonatorBandwidthChanged(sld.Value));

    % Button for each note
    for i = 1:12
        uibutton(f, 'Position', [25*i, 50, 20, 20], 'Text', char('a'+i-1), 'ButtonPushedFcn', @(btn, event) playSound(i));
    end

    function keyboardPressed(src, event)
        keyMap = {'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'};  % Array of keys
        idx = find(strcmp(keyMap, event.Key));  % Use strcmp for matching
        if ~isempty(idx) && idx <= numel(sounds)
            playSound(idx);
        end
    end
end

function resonatorFreqChanged(value)
    global resonatorFreq;
    resonatorFreq = value;  % Update global resonator frequency
    disp(['Resonator Frequency Changed to: ', num2str(resonatorFreq)]);
    refreshSounds();  % Re-generate all sounds with the new resonator settings
end

function resonatorBandwidthChanged(value)
    global resonatorBandwidth;
    resonatorBandwidth = value;  % Update global resonator bandwidth
    disp(['Resonator Bandwidth Changed to: ', num2str(resonatorBandwidth)]);
    refreshSounds();  % Re-generate all sounds with the new resonator settings
end

function baseFreqChanged(sld, event)
    global baseFreq;
    baseFreq = sld.Value;  % Update the base frequency
    generateAllSounds();  % Regenerate all sounds with the new base frequency
    disp(['Base Frequency Changed to: ', num2str(baseFreq)]);  % Optional: Display the new frequency
end

function waveformChanged(dd, event)
    global waveform;
    waveform = dd.Value;
    disp(['Waveform changed to: ', waveform]);  % Debug: Confirm waveform change
    refreshSounds();
end

function eqChanged(sld, bandIndex)
    global eqGains;
    eqGains(bandIndex) = sld.Value;
    refreshSounds();
end

function refreshSounds()
    generateAllSounds();
end

function playSound(index)
    global sounds fs audioPlayers;

    % Always recreate the audioplayer to ensure it uses the latest sound data
    if length(audioPlayers) < index || isempty(audioPlayers{index}) || true
        if ~isempty(audioPlayers{index})
            stop(audioPlayers{index});  % Stop the player if it is playing
        end
        audioPlayers{index} = audioplayer(sounds{index}, fs);
    end
    
    play(audioPlayers{index});  % Play the audioplayer for the given index
end

function y = addBass(x, fs)
    % Bass boost by low-pass filtering and conservative gain
    [b, a] = butter(2, 80/(fs/2), 'low');  % Low-pass filter below 80 Hz
    y = filter(b, a, x);
    gain = 1.2;  % Reduced gain
    y = y * gain;  % Apply gain

    % Compressor to control dynamics
    threshold = 0.5;  % Threshold for compression
    ratio = 4;  % Compression ratio
    y = compressor(y, threshold, ratio, fs);
end

function y = compressor(x, threshold, ratio, fs)
    % Simple compressor function
    x_abs = abs(x);
    y = x;
    for i = 1:length(x)
        if x_abs(i) > threshold
            y(i) = threshold + (x(i) - threshold) / ratio;
        end
    end
end

function y = applyADSR(x, fs)
    attackTime = 0.01;  % 10 ms attack
    decayTime = 0.1;    % 100 ms decay
    sustainLevel = 0.7; % Sustain level at 70% of peak
    releaseTime = 0.8;  % 800 ms release time

    % Calculate samples for each phase
    attackSamples = round(attackTime * fs);
    decaySamples = round(decayTime * fs);
    releaseSamples = round(releaseTime * fs);
    totalADRSamples = attackSamples + decaySamples + releaseSamples;
    sustainSamples = max(0, length(x) - totalADRSamples);

    % Create the envelope
    attackEnv = linspace(0, 1, attackSamples);
    decayEnv = linspace(1, sustainLevel, decaySamples);
    sustainEnv = linspace(sustainLevel, sustainLevel, sustainSamples);
    releaseEnv = linspace(sustainLevel, 0, releaseSamples);
    env = [attackEnv, decayEnv, sustainEnv, releaseEnv];

    % Ensure the envelope length matches the signal length
    if length(env) > length(x)
        env = env(1:length(x));
    elseif length(env) < length(x)
        env = [env, zeros(1, length(x) - length(env))];
    end

    % Apply the envelope
    y = x .* env;
end

function y = resonator(x, fs, freq, bandwidth)
    % Frequency and bandwidth determine the resonator's characteristics
    [b, a] = iirpeak(freq/(fs/2), bandwidth/(fs/2));
    y = filter(b, a, x);
end

function y = multiBandEQ(x, fs, gains)
    % Define frequency bands (low, mid, high)
    % Ensure the highest band does not exceed or reach the Nyquist frequency
    bands = [0 150; 151 1000; 1001 fs/2 - 1];  % Subtracted 1 Hz to avoid reaching the Nyquist limit

    y = zeros(size(x));

    for i = 1:size(bands, 1)
        % Ensure that the band limits are strictly within (0,1)
        band_normalized = max(min(bands(i,:)/(fs/2), 0.999), 0.001);
        [b, a] = butter(2, band_normalized, 'bandpass');
        filtered = filter(b, a, x);
        y = y + filtered * gains(i);
    end
end

function stereoWave = monoToStereoBasic(monoWave)
    stereoWave = [monoWave; monoWave]';  % Create two identical channels
end


function pannedWave = applyPanning(monoWave, pan)
    % pan ranges from -1 (full left) to 1 (full right)
    leftVol = cos((pan + 1) * pi/4);
    rightVol = sin((pan + 1) * pi/4);
    pannedWave = [leftVol * monoWave; rightVol * monoWave]';
end


function stereoWave = monoToStereoWithPanning(monoWave, fs, noteIndex)
    % Subtle stereo panning
    pan = linspace(-0.5, 0.5, 12);  % Narrower panning range
    leftVol = cos((pan(noteIndex) + 1) * pi/4);
    rightVol = sin((pan(noteIndex) + 1) * pi/4);
    stereoWave = [leftVol * monoWave; rightVol * monoWave]';  % Create two channels
end

function y = applyFadeOut(x, fs)
    fadeDuration = 0.5;  % Fade duration in seconds
    numFadeSamples = round(fs * fadeDuration);  % Number of samples over which to apply the fade

    % Create the fade vector (linear fade)
    fadeOut = linspace(1, 0, numFadeSamples);

    % Apply the fade-out effect
    if length(x) > numFadeSamples
        y = x;
        y(end-numFadeSamples+1:end) = y(end-numFadeSamples+1:end) .* fadeOut;
    else
        % If the signal is shorter than the fade duration, apply a shorter fade
        fadeOut = linspace(1, 0, length(x));
        y = x .* fadeOut;
    end
end