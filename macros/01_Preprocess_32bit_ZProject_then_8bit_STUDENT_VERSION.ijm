// ==================================================
// 01_Preprocess_32bit_ZProject_then_8bit_STUDENT_VERSION.ijm
// ==================================================
//
// PURPOSE:
// This macro prepares synaptic marker images for thresholding and puncta analysis.
// It starts from one open 52-slice image stack and creates channel-specific
// maximum-intensity Z projections.
//
// IMPORTANT:
// This macro does NOT threshold images.
// This macro does NOT create binary masks.
// This macro does NOT quantify puncta.
// It only prepares images for the next macro or manual thresholding step.
//
// --------------------------------------------------
// BEFORE RUNNING:
// --------------------------------------------------
//
// 1. Open the original 52-slice image in Fiji/ImageJ.
// 2. Confirm that the image has 52 slices.
// 3. Run this macro.
// 4. When prompted, select the main parent folder.
//
// Example parent folder:
//
//      L23_0001-0729-0904/
//
// Do NOT select one of the subfolders.
// Select the main folder that contains the macro and the image folders.
//
// --------------------------------------------------
// EXPECTED INPUT STACK ORGANIZATION:
// --------------------------------------------------
//
// The original image is a 52-slice stack.
// The 4 channels are stored sequentially:
//
//      C1 DAPI     = slices 1-13
//      C2 Bassoon  = slices 14-26
//      C3 Gephyrin = slices 27-39
//      C4 PSD95    = slices 40-52
//
// --------------------------------------------------
// PROCESSING LOGIC:
// --------------------------------------------------
//
// 1. Make a working duplicate of the open source image.
// 2. Keep the working copy as 32-bit.
// 3. Extract each channel as a separate 13-slice 32-bit stack.
// 4. Keep the first 9 slices from each channel as a 32-bit stack.
// 5. Make maximum-intensity projections from:
//      slices 1-3
//      slices 4-6
//      slices 7-9
// 6. Convert only the final 2D Z projections to 8-bit.
//    These 8-bit projections are used for thresholding.
//
// --------------------------------------------------
// WHY WE KEEP 32-BIT UNTIL THE FINAL PROJECTION:
// --------------------------------------------------
//
// The original image has high dynamic range.
// Converting the full stack to 8-bit too early can compress the signal
// before channel splitting and Z projection.
// This macro keeps the data 32-bit during preprocessing and converts only
// the final 2D projections to 8-bit for compatibility with thresholding.
//
// --------------------------------------------------
// OUTPUT FOLDERS CREATED BY THIS MACRO:
// --------------------------------------------------
//
//      00_Original_Stack_32bit/
//      01_Single_Channels_32bit/
//      02_Slice_Keeper_First_9_32bit/
//      03_Z_Project_1_3_8bit/
//      04_Z_Project_4_6_8bit/
//      05_Z_Project_7_9_8bit/
//
// ==================================================

requires("1.53");

macro "01 Preprocess 32bit ZProject then 8bit" {

    // --------------------------------------------------
    // Check that an image is open
    // --------------------------------------------------

    args = split(getArgument(), ";");
    filePath = args[0];
    parentDir = args[1];

    if (!endsWith(parentDir, "/")) {
        parentDir = parentDir + "/";
    }

    if (nImages == 0) {
        if (filePath == "") {
            exit("ERROR: No image open and no path argument provided.");
        }
        open(filePath);
    }

    logFile = parentDir + "debug_log.txt";

    // debug log
    File.saveString("filePath: " + filePath + "\nparentDir: " + parentDir, logFile);

    // --------------------------------------------------
    // Store information about the currently open image
    // --------------------------------------------------

    sourceID = getImageID();
    sourceTitle = getTitle();
    baseName = removeExtension(sourceTitle);

    File.append("----------------------------------------", logFile);

    totalSlices = nSlices();

    if (totalSlices != 52) {
        exit("ERROR: This image has " + totalSlices + " slices, not 52. Expected 52 slices.");
    }

    // --------------------------------------------------
    // Ask user to choose the main parent folder
    // --------------------------------------------------

    // parentDir = getDirectory("Choose the main parent folder, e.g. L23_0001-0729-0904");

    // --------------------------------------------------
    // Define output folders
    // --------------------------------------------------

    

    dirOriginal32 = parentDir + "00_Original_Stack_32bit/";
    dirChannels32 = parentDir + "01_Single_Channels_32bit/";
    dirFirst9_32 = parentDir + "02_Slice_Keeper_First_9_32bit/";
    dirZ13_8 = parentDir + "03_Z_Project_1_3_8bit/";
    dirZ46_8 = parentDir + "04_Z_Project_4_6_8bit/";
    dirZ79_8 = parentDir + "05_Z_Project_7_9_8bit/";

    // --------------------------------------------------
    // Create output folders if they do not already exist
    // --------------------------------------------------

    File.makeDirectory(dirOriginal32);
    File.makeDirectory(dirChannels32);
    File.makeDirectory(dirFirst9_32);
    File.makeDirectory(dirZ13_8);
    File.makeDirectory(dirZ46_8);
    File.makeDirectory(dirZ79_8);

    // --------------------------------------------------
    // Print basic information to the Log window
    // --------------------------------------------------

    File.append("----------------------------------------", logFile);
    File.append("Processing open image: " + sourceTitle, logFile);
    File.append("Base name: " + baseName, logFile);
    File.append("Total slices: " + totalSlices, logFile);
    File.append("Output parent folder: " + parentDir, logFile);

    setBatchMode(true);

    // --------------------------------------------------
    // Make a working duplicate of the open image
    // This keeps the original source image untouched.
    // --------------------------------------------------

    selectImage(sourceID);
    run("Select None");

    workTitle = baseName + "_WORK_32bit";
    run("Duplicate...", "title=[" + workTitle + "] duplicate");

    workID = getImageID();

    // Ensure working copy is 32-bit.
    // This preserves high dynamic range during preprocessing.
    run("32-bit");

    // Save the 32-bit full stack copy.
    saveAs("Tiff", dirOriginal32 + baseName + "_32bit_full_stack.tif");

    // --------------------------------------------------
    // Process each channel based on known slice ranges
    // --------------------------------------------------

    processOneChannel(workID, baseName, "C1", "DAPI",     1, 13, dirChannels32, dirFirst9_32, dirZ13_8, dirZ46_8, dirZ79_8);
    processOneChannel(workID, baseName, "C2", "Bassoon", 14, 26, dirChannels32, dirFirst9_32, dirZ13_8, dirZ46_8, dirZ79_8);
    processOneChannel(workID, baseName, "C3", "Gephyrin",27, 39, dirChannels32, dirFirst9_32, dirZ13_8, dirZ46_8, dirZ79_8);
    processOneChannel(workID, baseName, "C4", "PSD95",   40, 52, dirChannels32, dirFirst9_32, dirZ13_8, dirZ46_8, dirZ79_8);

    // --------------------------------------------------
    // Close working duplicate
    // --------------------------------------------------

    selectImage(workID);
    close();

    setBatchMode(false);

    // --------------------------------------------------
    // Final log message
    // --------------------------------------------------

    File.append("----------------------------------------", logFile);
    File.append("DONE.", logFile);
    File.append("32-bit full stack saved to: " + dirOriginal32, logFile);
    File.append("32-bit single channels saved to: " + dirChannels32, logFile);
    File.append("32-bit first-9 stacks saved to: " + dirFirst9_32, logFile);
    File.append("8-bit Z projections 1-3 saved to: " + dirZ13_8, logFile);
    File.append("8-bit Z projections 4-6 saved to: " + dirZ46_8, logFile);
    File.append("8-bit Z projections 7-9 saved to: " + dirZ79_8, logFile);
}


// ==================================================
// FUNCTION: processOneChannel
// ==================================================
//
// This function processes one channel at a time.
//
// Inputs:
//      workID       = image ID of the working 32-bit full stack
//      baseName     = image name without .tif extension
//      channelName  = C1, C2, C3, or C4
//      markerName   = DAPI, Bassoon, Gephyrin, or PSD95
//      startSlice   = first slice of that channel in the 52-slice stack
//      endSlice     = last slice of that channel in the 52-slice stack
//
// Outputs:
//      13-slice 32-bit channel stack
//      first-9-slice 32-bit stack
//      three 8-bit max projections
//
// ==================================================

function processOneChannel(workID, baseName, channelName, markerName, startSlice, endSlice,
                           dirChannels32, dirFirst9_32, dirZ13_8, dirZ46_8, dirZ79_8) {

    selectImage(workID);
    run("Select None");

    // --------------------------------------------------
    // Extract full 13-slice channel as 32-bit
    // --------------------------------------------------

    channelFileName = baseName + "_" + channelName + "_" + markerName + "_1_13_32bit";
    channelTitle = channelFileName;

    run("Duplicate...", "title=[" + channelTitle + "] duplicate range=" + startSlice + "-" + endSlice);

    channelID = getImageID();

    run("32-bit");
    saveAs("Tiff", dirChannels32 + channelFileName + ".tif");

    // --------------------------------------------------
    // Keep only the first 9 slices from this channel
    // --------------------------------------------------

    selectImage(channelID);
    run("Select None");

    first9FileName = baseName + "_" + channelName + "_" + markerName + "_1_9_32bit";
    first9Title = first9FileName;

    run("Duplicate...", "title=[" + first9Title + "] duplicate range=1-9");

    first9ID = getImageID();

    run("32-bit");
    saveAs("Tiff", dirFirst9_32 + first9FileName + ".tif");

    // --------------------------------------------------
    // Make max projections from the first 9 slices
    // --------------------------------------------------

    makeMaxProjection8bit(first9ID, baseName, channelName, markerName, 1, 3, "1_3", dirZ13_8);
    makeMaxProjection8bit(first9ID, baseName, channelName, markerName, 4, 6, "4_6", dirZ46_8);
    makeMaxProjection8bit(first9ID, baseName, channelName, markerName, 7, 9, "7_9", dirZ79_8);

    // --------------------------------------------------
    // Close temporary channel images
    // --------------------------------------------------

    selectImage(first9ID);
    close();

    selectImage(channelID);
    close();

    selectImage(workID);
}


// ==================================================
// FUNCTION: makeMaxProjection8bit
// ==================================================
//
// This function creates one max-intensity projection.
// The projection is made from 32-bit data.
// Only after projection is the final 2D image converted to 8-bit.
//
// This is important because thresholding works best on 8-bit images,
// but early 8-bit conversion can compress the original signal.
//
// ==================================================

function makeMaxProjection8bit(first9ID, baseName, channelName, markerName, startSlice, endSlice, zLabel, outputDir) {

    selectImage(first9ID);
    run("Select None");

    // --------------------------------------------------
    // Duplicate only the slices needed for this projection
    // Example: slices 1-3, 4-6, or 7-9
    // --------------------------------------------------

    tempTitle = baseName + "_" + channelName + "_" + markerName + "_" + zLabel + "_temp32";

    run("Duplicate...", "title=[" + tempTitle + "] duplicate range=" + startSlice + "-" + endSlice);

    tempID = getImageID();

    run("32-bit");

    // --------------------------------------------------
    // Create max-intensity projection from the selected slices
    // --------------------------------------------------

    run("Z Project...", "projection=[Max Intensity]");

    projectionID = getImageID();

    finalTitle = baseName + "_" + channelName + "_" + markerName + "_" + zLabel + "_MAX_8bit";

    rename(finalTitle);

    // --------------------------------------------------
    // Convert only the final 2D projected image to 8-bit.
    // This 8-bit image will be used for thresholding/mask generation.
    // --------------------------------------------------

    setOption("ScaleConversions", true);
    run("8-bit");

    saveAs("Tiff", outputDir + finalTitle + ".tif");

    // --------------------------------------------------
    // Close temporary images and return to first-9 stack
    // --------------------------------------------------

    selectImage(projectionID);
    close();

    selectImage(tempID);
    close();

    selectImage(first9ID);
}


// ==================================================
// FUNCTION: removeExtension
// ==================================================
//
// Removes the file extension from the image title.
// Example:
//      L23_0001-0729-0904.tif
// becomes:
//      L23_0001-0729-0904
//
// ==================================================

function removeExtension(name) {
    dot = lastIndexOf(name, ".");

    if (dot == -1) {
        return name;
    } else {
        return substring(name, 0, dot);
    }
}