// ==================================================
// 05_Marker_Pixel_Overlap_Analysis_FIXED_WORKING.ijm
// ==================================================
//
// PURPOSE:
// Pixel-based overlap analysis between binary marker masks.
//
// This macro is complementary to Macro 4.
//
// Macro 4:
//      Centroid proximity analysis
//      Main putative synapse association metric
//      Bassoon-PSD95 or Bassoon-Gephyrin within 0.5 um
//
// Macro 5:
//      Pixel-overlap analysis
//      Stricter colocalization / QC metric
//      Measures whether marker masks physically overlap
//
// --------------------------------------------------
// INPUT:
// --------------------------------------------------
//
// Parent folder/
//      06_Masks/
//          C2_Bassoon_1_3/
//          C2_Bassoon_4_6/
//          C2_Bassoon_7_9/
//          C3_Gephyrin_1_3/
//          C3_Gephyrin_4_6/
//          C3_Gephyrin_7_9/
//          C4_PSD95_1_3/
//          C4_PSD95_4_6/
//          C4_PSD95_7_9/
//
// --------------------------------------------------
// OUTPUT:
// --------------------------------------------------
//
// Parent folder/
//      10_Marker_Overlap_Analysis/
//          01_Results/
//              marker_pixel_overlap_summary_FIXED.csv
//
//          02_Overlap_Masks/
//              binary overlap masks
//
// --------------------------------------------------
// MARKER PAIRS:
// --------------------------------------------------
//
//      Bassoon vs PSD95
//      Bassoon vs Gephyrin
//      PSD95 vs Gephyrin
//
// --------------------------------------------------
// MAIN METRICS:
// --------------------------------------------------
//
// Marker_A_area_um2
// Marker_B_area_um2
// Overlap_area_um2
// Union_area_um2
//
// Percent_A_area_overlapping_B
// Percent_B_area_overlapping_A
// Percent_ROI_area_overlap
// Jaccard_index
// Dice_coefficient
//
// --------------------------------------------------
// IMPORTANT:
// --------------------------------------------------
//
// Jaccard is calculated directly from the measured areas:
//
//      Union area = A + B - Overlap
//      Jaccard = Overlap / Union
//
// This avoids the previous problem where the OR image sometimes
// produced incorrect Jaccard values.
//
// ==================================================
var logFile;

requires("1.53");

macro "05 Marker Pixel Overlap Analysis FIXED" {

    // --------------------------------------------------
    // Choose parent folder
    // --------------------------------------------------

    args = split(getArgument(), ";");
    filePath = args[0];
    parentDir = args[1];
    layerName = args[2];
    roiID = args[3];
    regionName = args[4];

    if (!endsWith(parentDir, "/")) {
        parentDir = parentDir + "/";
    }

    logFile = parentDir + "debug_log.txt";

    // debug log
    //File.saveString("filePath: " + filePath + "\nparentDir: " + parentDir, logFile);

    dirMasks = parentDir + "06_Masks/";

    if (!File.exists(dirMasks)) {
        exit("ERROR: Missing mask folder:\n" + dirMasks);
    }

    regionSafe = cleanForFilename(regionName);
    layerSafe = cleanForFilename(layerName);
    roiSafe = cleanForFilename(roiID);

    // --------------------------------------------------
    // Output folders
    // --------------------------------------------------

    dirOverlap = parentDir + "10_Marker_Overlap_Analysis/";
    dirResults = dirOverlap + "01_Results/";
    dirOverlapMasks = dirOverlap + "02_Overlap_Masks/";

    File.makeDirectory(dirOverlap);
    File.makeDirectory(dirResults);
    File.makeDirectory(dirOverlapMasks);

    summaryCSV = dirResults + "marker_pixel_overlap_summary_FIXED.csv";

    header =
        "Image_ID,Region,Layer,ROI_ID,Z_group," +
        "Marker_A,Marker_B," +
        "ROI_width_um,ROI_height_um,ROI_area_um2," +
        "Image_width_pixels,Image_height_pixels," +
        "Pixel_width_um,Pixel_height_um," +
        "Marker_A_area_um2,Marker_B_area_um2," +
        "Overlap_area_um2,Union_area_um2," +
        "Percent_A_area_overlapping_B," +
        "Percent_B_area_overlapping_A," +
        "Percent_ROI_area_overlap," +
        "Jaccard_index,Dice_coefficient," +
        "Marker_A_mask,Marker_B_mask,Overlap_mask\n";

    File.saveString(header, summaryCSV);

    File.append("----------------------------------------", logFile);
    File.append("Starting Macro 5 FIXED: pixel-overlap analysis.", logFile);
    File.append("Parent folder: " + parentDir, logFile);
    File.append("Mask folder: " + dirMasks, logFile);
    File.append("Output folder: " + dirOverlap, logFile);
    File.append("Region: " + regionName, logFile);
    File.append("Layer: " + layerName, logFile);
    File.append("ROI_ID: " + roiID, logFile);

    setBatchMode(true);

    processZGroup("1_3", dirMasks, summaryCSV, dirOverlapMasks,
                  regionName, layerName, roiID,
                  regionSafe, layerSafe, roiSafe);

    processZGroup("4_6", dirMasks, summaryCSV, dirOverlapMasks,
                  regionName, layerName, roiID,
                  regionSafe, layerSafe, roiSafe);

    processZGroup("7_9", dirMasks, summaryCSV, dirOverlapMasks,
                  regionName, layerName, roiID,
                  regionSafe, layerSafe, roiSafe);

    setBatchMode(false);

    File.append("----------------------------------------", logFile);
    File.append("DONE.", logFile);
    File.append("Fixed pixel-overlap summary:", logFile);
    File.append(summaryCSV, logFile);
    File.append("Overlap masks:", logFile);
    File.append(dirOverlapMasks, logFile);
    run("Quit");
}


// ==================================================
// FUNCTION: processZGroup
// ==================================================

function processZGroup(zGroup, dirMasks, summaryCSV, dirOverlapMasks,
                       regionName, layerName, roiID,
                       regionSafe, layerSafe, roiSafe) {

    File.append("----------------------------------------", logFile);
    File.append("Processing Z group: " + zGroup, logFile);

    bassoonDir  = dirMasks + "C2_Bassoon_"  + zGroup + "/";
    gephyrinDir = dirMasks + "C3_Gephyrin_" + zGroup + "/";
    psd95Dir    = dirMasks + "C4_PSD95_"    + zGroup + "/";

    bassoonFile  = firstTiffFile(bassoonDir);
    gephyrinFile = firstTiffFile(gephyrinDir);
    psd95File    = firstTiffFile(psd95Dir);

    if (bassoonFile == "NONE") {
        File.append("WARNING: No Bassoon mask found for Z " + zGroup, logFile);
        return;
    }

    if (gephyrinFile == "NONE") {
        File.append("WARNING: No Gephyrin mask found for Z " + zGroup, logFile);
        return;
    }

    if (psd95File == "NONE") {
        File.append("WARNING: No PSD95 mask found for Z " + zGroup, logFile);
        return;
    }

    // Main biological pairs
    analyzePair(
        bassoonDir, bassoonFile, "Bassoon", "C2",
        psd95Dir, psd95File, "PSD95", "C4",
        zGroup, summaryCSV, dirOverlapMasks,
        regionName, layerName, roiID,
        regionSafe, layerSafe, roiSafe
    );

    analyzePair(
        bassoonDir, bassoonFile, "Bassoon", "C2",
        gephyrinDir, gephyrinFile, "Gephyrin", "C3",
        zGroup, summaryCSV, dirOverlapMasks,
        regionName, layerName, roiID,
        regionSafe, layerSafe, roiSafe
    );

    // Context / QC pair
    analyzePair(
        psd95Dir, psd95File, "PSD95", "C4",
        gephyrinDir, gephyrinFile, "Gephyrin", "C3",
        zGroup, summaryCSV, dirOverlapMasks,
        regionName, layerName, roiID,
        regionSafe, layerSafe, roiSafe
    );
}


// ==================================================
// FUNCTION: analyzePair
// ==================================================

function analyzePair(dirA, fileA, markerA, channelA,
                     dirB, fileB, markerB, channelB,
                     zGroup, summaryCSV, dirOverlapMasks,
                     regionName, layerName, roiID,
                     regionSafe, layerSafe, roiSafe) {

    // --------------------------------------------------
    // Open marker A mask
    // --------------------------------------------------

    open(dirA + fileA);
    titleA = getTitle();
    run("8-bit");
    setOption("BlackBackground", true);

    // --------------------------------------------------
    // Open marker B mask
    // --------------------------------------------------

    open(dirB + fileB);
    titleB = getTitle();
    run("8-bit");
    setOption("BlackBackground", true);

    // --------------------------------------------------
    // Check dimensions and calibration
    // --------------------------------------------------

    selectWindow(titleA);
    widthA = getWidth();
    heightA = getHeight();
    getPixelSize(unitA, pixelWidthA, pixelHeightA, voxelDepthA);

    selectWindow(titleB);
    widthB = getWidth();
    heightB = getHeight();
    getPixelSize(unitB, pixelWidthB, pixelHeightB, voxelDepthB);

    if (widthA != widthB || heightA != heightB) {
        exit("ERROR: Mask dimensions do not match for " + markerA + " vs " + markerB + " Z " + zGroup);
    }

    // In this dataset, Fiji may label the unit as pixels even though
    // the numeric calibration is the correct micron/pixel value.
    pixelWidthUm = pixelWidthA;
    pixelHeightUm = pixelHeightA;

    imageWidthPixels = widthA;
    imageHeightPixels = heightA;

    ROI_width_um = imageWidthPixels * pixelWidthUm;
    ROI_height_um = imageHeightPixels * pixelHeightUm;
    ROI_area_um2 = ROI_width_um * ROI_height_um;

    pixelArea_um2 = pixelWidthUm * pixelHeightUm;

    // --------------------------------------------------
    // Calculate marker-positive areas
    // --------------------------------------------------

    areaA = positiveAreaUm2(titleA, pixelArea_um2);
    areaB = positiveAreaUm2(titleB, pixelArea_um2);

    // --------------------------------------------------
    // Create overlap mask: A AND B
    // --------------------------------------------------

    imageCalculator("AND create", titleA, titleB);
    overlapTitle = getTitle();

    overlapArea = positiveAreaUm2(overlapTitle, pixelArea_um2);

    // --------------------------------------------------
    // Calculate union area directly
    // --------------------------------------------------
    //
    // This avoids the previous OR-image problem.
    //
    // Union = A + B - Overlap
    //
    // --------------------------------------------------

    unionArea = areaA + areaB - overlapArea;

    // --------------------------------------------------
    // Calculate overlap metrics
    // --------------------------------------------------

    if (areaA > 0) {
        percentAoverlapB = (overlapArea / areaA) * 100;
    } else {
        percentAoverlapB = 0;
    }

    if (areaB > 0) {
        percentBoverlapA = (overlapArea / areaB) * 100;
    } else {
        percentBoverlapA = 0;
    }

    if (ROI_area_um2 > 0) {
        percentROIoverlap = (overlapArea / ROI_area_um2) * 100;
    } else {
        percentROIoverlap = 0;
    }

    if (unionArea > 0) {
        jaccard = overlapArea / unionArea;
    } else {
        jaccard = 0;
    }

    if ((areaA + areaB) > 0) {
        dice = (2 * overlapArea) / (areaA + areaB);
    } else {
        dice = 0;
    }

    imageID = getImageIDFromMaskName(removeExtension(fileA), channelA, markerA, zGroup);

    // --------------------------------------------------
    // Save overlap mask
    // --------------------------------------------------

    overlapMaskName =
        imageID + "_" +
        regionSafe + "_" +
        layerSafe + "_" +
        roiSafe + "_" +
        markerA + "_vs_" + markerB + "_" +
        zGroup + "_PIXEL_OVERLAP_MASK.tif";

    selectWindow(overlapTitle);
    saveAs("Tiff", dirOverlapMasks + overlapMaskName);

    // --------------------------------------------------
    // Write CSV row
    // --------------------------------------------------

    row =
        imageID + "," +
        regionName + "," +
        layerName + "," +
        roiID + "," +
        zGroup + "," +
        markerA + "," +
        markerB + "," +
        ROI_width_um + "," +
        ROI_height_um + "," +
        ROI_area_um2 + "," +
        imageWidthPixels + "," +
        imageHeightPixels + "," +
        pixelWidthUm + "," +
        pixelHeightUm + "," +
        areaA + "," +
        areaB + "," +
        overlapArea + "," +
        unionArea + "," +
        percentAoverlapB + "," +
        percentBoverlapA + "," +
        percentROIoverlap + "," +
        jaccard + "," +
        dice + "," +
        fileA + "," +
        fileB + "," +
        overlapMaskName + "\n";

    File.append(row, summaryCSV);

    File.append(markerA + " vs " + markerB + " | Z " + zGroup, logFile);
    File.append("  " + markerA + " area: " + areaA + " um^2", logFile);
    File.append("  " + markerB + " area: " + areaB + " um^2", logFile);
    File.append("  overlap area: " + overlapArea + " um^2", logFile);
    File.append("  union area: " + unionArea + " um^2", logFile);
    File.append("  % " + markerA + " overlapping " + markerB + ": " + percentAoverlapB, logFile);
    File.append("  % " + markerB + " overlapping " + markerA + ": " + percentBoverlapA, logFile);
    File.append("  Jaccard: " + jaccard, logFile);
    File.append("  Dice: " + dice, logFile);

    // --------------------------------------------------
    // Close images
    // --------------------------------------------------

    if (isOpen(overlapTitle)) {
        selectWindow(overlapTitle);
        close();
    }

    if (isOpen(titleB)) {
        selectWindow(titleB);
        close();
    }

    if (isOpen(titleA)) {
        selectWindow(titleA);
        close();
    }
}


// ==================================================
// FUNCTION: positiveAreaUm2
// ==================================================
//
// Assumes binary mask:
//      background = 0
//      positive pixels = 255
//
// Positive pixels are estimated from mean intensity:
//
//      positive_pixels = mean / 255 * total_pixels
//
// ==================================================

function positiveAreaUm2(title, pixelArea_um2) {

    selectWindow(title);

    getStatistics(area, mean, min, max, std);

    totalPixels = getWidth() * getHeight();

    positivePixels = (mean / 255.0) * totalPixels;

    positiveArea = positivePixels * pixelArea_um2;

    return positiveArea;
}


// ==================================================
// FUNCTION: firstTiffFile
// ==================================================

function firstTiffFile(folder) {

    if (!File.exists(folder)) {
        return "NONE";
    }

    fileList = getFileList(folder);

    for (i = 0; i < fileList.length; i++) {

        fileName = fileList[i];

        if (endsWith(fileName, ".tif") || endsWith(fileName, ".tiff")) {
            return fileName;
        }
    }

    return "NONE";
}


// ==================================================
// FUNCTION: getImageIDFromMaskName
// ==================================================

function getImageIDFromMaskName(baseName, channel, marker, zGroup) {

    pattern = "_" + channel + "_" + marker + "_" + zGroup;

    idx = indexOf(baseName, pattern);

    if (idx >= 0) {
        return substring(baseName, 0, idx);
    } else {
        return baseName;
    }
}


// ==================================================
// FUNCTION: removeExtension
// ==================================================

function removeExtension(name) {

    dot = lastIndexOf(name, ".");

    if (dot == -1) {
        return name;
    } else {
        return substring(name, 0, dot);
    }
}


// ==================================================
// FUNCTION: cleanForFilename
// ==================================================

function cleanForFilename(text) {

    text = replace(text, "/", "_");
    text = replace(text, " ", "_");
    text = replace(text, ":", "_");
    text = replace(text, ";", "_");
    text = replace(text, ",", "_");

    return text;
}