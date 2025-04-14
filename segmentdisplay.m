
[file, path] = uigetfile('*.mp4', 'Select a video file');
if isequal(file, 0)
    disp('User selected Cancel');
    return;
else
    videoFile = fullfile(path, file); 
end


videoReader = VideoReader(videoFile);


frameRate = videoReader.FrameRate;


framesToSkip = round(frameRate); 


firstFrame = readFrame(videoReader);
figure;
imshow(firstFrame);
title('SELECTEAZA REGIUNEA ECRANULUI CU GRIJA, PASTREAZA UN SPATIU DE JUMATATE DE CM LA MARGINILE ZONEI');


roi = drawrectangle('Label', 'ROI', 'Color', 'r');
roiPosition = round(roi.Position); 
close; 


roiX = roiPosition(1);
roiY = roiPosition(2);
roiWidth = roiPosition(3);
roiHeight = roiPosition(4);


videoPlayer = vision.VideoPlayer('Name', 'Text Detection and OCR');


frameCounter = 0;


resultsTable = table('Size', [0, 2], 'VariableTypes', {'double', 'string'}, 'VariableNames', {'Time', 'RecognizedDigits'});


while hasFrame(videoReader)
    
    img = readFrame(videoReader);
    
    
    frameCounter = frameCounter + 1;
    

    if mod(frameCounter, framesToSkip) ~= 0
        continue; 
    end
    
    
    currentTimeInSeconds = frameCounter / frameRate;
    
    
    roiImg = img(roiY:roiY+roiHeight, roiX:roiX+roiWidth, :);
    
    
    grayImg = rgb2gray(roiImg); % Convert to grayscale
    binaryImg = imbinarize(grayImg); % Binarize the image
    binaryImg = imcomplement(binaryImg); % Invert to highlight segments
    binaryImg = imopen(binaryImg, strel('rectangle', [3, 3])); % Remove small noise
    
    
    bbox = detectTextCRAFT(binaryImg, LinkThreshold=0.005);
    
    
    Iout = insertShape(img, "rectangle", [roiX, roiY, roiWidth, roiHeight], 'LineWidth', 4, 'Color', 'red');
    
    
    if ~isempty(bbox)
        
        bbox(:, 1) = bbox(:, 1) + roiX;
        bbox(:, 2) = bbox(:, 2) + roiY;
        
        
        Iout = insertShape(Iout, "rectangle", bbox, 'LineWidth', 2, 'Color', 'green');
        
        
        output = ocr(binaryImg, Model="seven-segment");
        
   
        recognizedText = output.Text;
        Iout = insertText(Iout, [10 10], ['Recognized Digits: ', recognizedText], 'FontSize', 20, 'BoxColor', 'yellow');
        
        
        fprintf('Time: %.2f seconds, Detected Number: %s\n', currentTimeInSeconds, recognizedText);
        
        
        resultsTable = [resultsTable; {currentTimeInSeconds, recognizedText}];
    else
        
        fprintf('Time: %.2f seconds, No text detected.\n', currentTimeInSeconds);
        
        
        resultsTable = [resultsTable; {currentTimeInSeconds, "-"}];
    end
    
    
    step(videoPlayer, Iout);
end

release(videoPlayer);
excelFileName = 'Results.xlsx';
writetable(resultsTable, excelFileName);
fprintf('Your values have been stored in %s\n', excelFileName);
