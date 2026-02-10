% This script:
% 1) Manually draw ROI for each cell on the reference frame.
% 2) Applies same ROIs to every frame of the video.
% 3) Produces a video showing each ROIs with a numeric label.
% 4) Stores the mean intensity for each ROI in each frame into a CSV file.

videoFolder = 'video folder path';  
videoPattern = '*.AVI';  

videoFiles = dir(fullfile(videoFolder, videoPattern));
if isempty(videoFiles)
    fprintf('No videos found in %s matching pattern %s\\n', videoFolder, videoPattern);
    return;
end
fprintf('Found %d videos in %s\\n', numel(videoFiles), videoFolder);

for v = 1:numel(videoFiles)
    videoName = videoFiles(v).name;
    videoFile = fullfile(videoFolder, videoName);

    %% Read the video
    vidObj = VideoReader(videoFile);
    frameCount = floor(vidObj.FrameRate * vidObj.Duration);
    fprintf('Video file: %s\n', videoFile);
    fprintf('Total frames: %d\n', frameCount);
   
    frameToSegment = 1;
    vidObj.CurrentTime = (frameToSegment - 1) / vidObj.FrameRate;
    refFrame = readFrame(vidObj);
    
    %% Draw ROIs
    figure('Name','Draw Polygons on Reference Frame');
    imshow(refFrame);
    title({'Draw polygons around each cell','(Double-click to finish each polygon)'});
    hold on;
    
    roiInfo = []; 
    cellIndex = 1;
    choice = 'Yes';
   
    while strcmpi(choice,'Yes')
        hPoly = drawpolygon('LineWidth',0.5,'Color','r');
        wait(hPoly);
        mask = createMask(hPoly);
        B = bwboundaries(mask, 'noholes');
        if isempty(B)
            warning('No boundary found for this ROI. Skipping...');
            choice = questdlg('Add another ROI (cell)?','Continue?','Yes','No','No');
            continue;
        end
        boundary = B{1}; 
    
        statsROI = regionprops(mask,'Centroid');
        if isempty(statsROI)
            warning('No centroid found for this ROI. Skipping...');
            choice = questdlg('Add another ROI (cell)?','Continue?','Yes','No','No');
            continue;
        end
        centroidVal = statsROI(1).Centroid; 
           
        roiInfo(cellIndex).mask = mask;            
        roiInfo(cellIndex).boundary = boundary;    
        roiInfo(cellIndex).centroid = centroidVal; 
        cellIndex = cellIndex + 1;    
        choice = questdlg('Add another ROI (cell)?','Continue?','Yes','No','No');
    end
    close;
    
    numCells = numel(roiInfo);
    fprintf('Total ROIs (cells) drawn: %d\n', numCells);
    
    vidObj = VideoReader(videoFile);

    %% output video
    [folderPath, baseName, ext] = fileparts(videoFile);
    if isempty(folderPath)
        folderPath = pwd; 
    end
    
    outVideoName = sprintf('%s_labeled.avi', baseName);
    outVideoPath = fullfile(folderPath, outVideoName);
    
    outVid = VideoWriter(outVideoPath, 'Motion JPEG AVI');
    outVid.FrameRate = vidObj.FrameRate;
    open(outVid);
    
    %% storing mean intensity data: Frame, ROI Index, MeanIntensity
    intensityData = {};
    
    for frameIdx = 1:frameCount
        if ~hasFrame(vidObj)
            break;
        end
        frame = readFrame(vidObj);
        grayFrame = im2double(rgb2gray(frame));
        labeledFrame = frame;
    
        for c = 1:numCells
            regionPixels = grayFrame(roiInfo(c).mask);
            meanVal = mean(regionPixels(:));
            boundary = roiInfo(c).boundary;
            xCoords = boundary(:,2);
            yCoords = boundary(:,1);
            polyXY = [xCoords, yCoords]'; 
            polyXY = polyXY(:)';         
            labeledFrame = insertShape(labeledFrame,'Polygon',polyXY,...
                'Color','yellow','LineWidth',1);
            centroidVal = roiInfo(c).centroid;
            labelStr = sprintf('Cell %d\nMean=%.2f', c, meanVal);
            labeledFrame = insertText(labeledFrame, centroidVal, labelStr,...
                'FontSize',14,'BoxColor','blue','BoxOpacity',0.6);

            intensityData = [intensityData; {frameIdx, c, meanVal}]; 
        end
    
        writeVideo(outVid, labeledFrame);
    
        if mod(frameIdx,50) == 0
            fprintf('Processed frame %d / %d\n', frameIdx, frameCount);
        end
    end
    
    close(outVid);
    fprintf('Output labeled video saved to %s\n', outVideoPath);
    
    if ~isempty(intensityData)
        varNames = {'Frame','CellID','MeanIntensity'};
        intensityTable = cell2table(intensityData, 'VariableNames', varNames);
        outCsvName = sprintf('%s_intensity.csv', baseName);
        outCsvPath = fullfile(folderPath, outCsvName);
        writetable(intensityTable, outCsvPath);
        fprintf('Mean intensity data saved to %s\n', outCsvPath);
    else
        fprintf('No intensity data to save. Possibly no ROIs.\n');
    end
end
