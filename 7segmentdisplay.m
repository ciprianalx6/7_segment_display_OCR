% Open a dialog box for the user to select a video file
[file, path] = uigetfile('*.mp4', 'Select a video file');
if isequal(file, 0)
    disp('User selected Cancel');
    return; % Exit the script if the user cancels the selection
else
    videoFile = fullfile(path, file); % Construct the full file path
end

% Read the video file
videoReader = VideoReader(videoFile);

% Get the frame rate of the video
frameRate = videoReader.FrameRate;

% Calculate the number of frames to skip to get one frame per second
framesToSkip = round(frameRate); % Skip frames to get 1 frame per second

% Read the first frame to manually select the ROI
firstFrame = readFrame(videoReader);
figure;
imshow(firstFrame);
title('SELECTEAZA REGIUNEA ECRANULUI CU GRIJA, PASTREAZA UN SPATIU DE JUMATATE DE CM LA MARGINILE ZONEI');

% Allow the user to manually select the ROI
roi = drawrectangle('Label', 'ROI', 'Color', 'r');
roiPosition = round(roi.Position); % Get the position of the ROI [x, y, width, height]
close; % Close the figure after selecting the ROI

% Precompute ROI coordinates for faster access
roiX = roiPosition(1);
roiY = roiPosition(2);
roiWidth = roiPosition(3);
roiHeight = roiPosition(4);

% Create a video player to display the results
videoPlayer = vision.VideoPlayer('Name', 'Text Detection and OCR');

% Initialize frame counter
frameCounter = 0;

% Initialize a table to store the results
resultsTable = table('Size', [0, 2], 'VariableTypes', {'double', 'string'}, 'VariableNames', {'Time', 'RecognizedDigits'});

% Loop through each frame of the video
while hasFrame(videoReader)
    % Read the current frame
    img = readFrame(videoReader);
    
    % Increment frame counter
    frameCounter = frameCounter + 1;
    
    % Process only one frame per second
    if mod(frameCounter, framesToSkip) ~= 0
        continue; % Skip this frame
    end
    
    % Calculate the time in seconds
    currentTimeInSeconds = frameCounter / frameRate;
    
    % Extract the ROI from the current frame
    roiImg = img(roiY:roiY+roiHeight, roiX:roiX+roiWidth, :);
    
    % Preprocess the ROI for seven-segment display detection
    grayImg = rgb2gray(roiImg); % Convert to grayscale
    binaryImg = imbinarize(grayImg); % Binarize the image
    binaryImg = imcomplement(binaryImg); % Invert to highlight segments
    binaryImg = imopen(binaryImg, strel('rectangle', [3, 3])); % Remove small noise
    
    % Detect text regions within the ROI using CRAFT algorithm
    bbox = detectTextCRAFT(binaryImg, LinkThreshold=0.005);
    
    % Highlight detected text regions for visualization
    Iout = insertShape(img, "rectangle", [roiX, roiY, roiWidth, roiHeight], 'LineWidth', 4, 'Color', 'red');
    
    % If text regions are detected, process them
    if ~isempty(bbox)
        % Adjust the bounding box coordinates to the full image
        bbox(:, 1) = bbox(:, 1) + roiX;
        bbox(:, 2) = bbox(:, 2) + roiY;
        
        % Highlight detected text regions
        Iout = insertShape(Iout, "rectangle", bbox, 'LineWidth', 2, 'Color', 'green');
        
        % Apply OCR to recognize the digits from the ROI
        output = ocr(binaryImg, Model="seven-segment");
        
        % Display the recognized text on the frame
        recognizedText = output.Text;
        Iout = insertText(Iout, [10 10], ['Recognized Digits: ', recognizedText], 'FontSize', 20, 'BoxColor', 'yellow');
        
        % Display the time in seconds and detected number in the command window
        fprintf('Time: %.2f seconds, Detected Number: %s\n', currentTimeInSeconds, recognizedText);
        
        % Add the results to the table
        resultsTable = [resultsTable; {currentTimeInSeconds, recognizedText}];
    else
        % If no text is detected, display a message
        fprintf('Time: %.2f seconds, No text detected.\n', currentTimeInSeconds);
        
        % Add the results to the table with "No text detected"
        resultsTable = [resultsTable; {currentTimeInSeconds, "-"}];
    end
    
    % Display the frame with detected text regions and recognized digits
    step(videoPlayer, Iout);
end

% Release the video player
release(videoPlayer);

% Write the results to an Excel file
excelFileName = 'Results.xlsx';
writetable(resultsTable, excelFileName);

% Notify the user that the results have been saved
fprintf('Your values have been stored in %s\n', excelFileName);