// ==================================================
// 04_Associate_Markers_From_Coordinates_0p5um_FINAL_WORKING.ijm
// ==================================================
//
// PURPOSE:
// Final proximity-based marker association analysis using the selected
// 0.5 um centroid-distance threshold.
//
// This macro reads the individual puncta coordinate table from Macro 3.
// It does NOT open images.
// It works only from saved puncta centroid coordinates.
//
// --------------------------------------------------
// INPUT:
// --------------------------------------------------
//
// Parent folder/
//      07_Individual_Marker_Analysis/
//          01_Results/
//              individual_puncta_coordinates.csv
//
// --------------------------------------------------
// OUTPUT:
// --------------------------------------------------
//
// Parent folder/
//      09_Marker_Association_0p5um_Final/
//          01_Results/
//              postsynaptic_to_bassoon_0p5um.csv
//              bassoon_classification_0p5um.csv
//              association_summary_0p5um.csv
//
// --------------------------------------------------
// BIOLOGICAL LOGIC:
// --------------------------------------------------
//
// Bassoon  = putative presynaptic marker-positive puncta
// PSD95    = putative excitatory postsynaptic marker-positive puncta
// Gephyrin = putative inhibitory postsynaptic marker-positive puncta
//
// Proximity rule:
//      centroid distance <= 0.5 um
//
// Putative excitatory association:
//      Bassoon + PSD95 within 0.5 um
//
// Putative inhibitory association:
//      Bassoon + Gephyrin within 0.5 um
//
// Bassoon classification:
//      PSD95_only:
//          Bassoon has >=1 PSD95 within 0.5 um and 0 Gephyrin.
//
//      Gephyrin_only:
//          Bassoon has >=1 Gephyrin within 0.5 um and 0 PSD95.
//
//      Both_PSD95_and_Gephyrin:
//          Bassoon has >=1 PSD95 and >=1 Gephyrin within 0.5 um.
//
//      Unassigned:
//          Bassoon has 0 PSD95 and 0 Gephyrin within 0.5 um.
//
// --------------------------------------------------
// IMPORTANT NOTE:
// --------------------------------------------------
//
// "Unassigned" does not mean biologically isolated.
// It means no PSD95 or Gephyrin punctum was detected within the selected
// 0.5 um proximity threshold.
//
// ==================================================

requires("1.53");

macro "04 Associate Markers From Coordinates 0p5um Final" {

    // --------------------------------------------------
    // Choose parent folder
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

    inputCSV = parentDir + "07_Individual_Marker_Analysis/01_Results/individual_puncta_coordinates.csv";

    if (!File.exists(inputCSV)) {
        exit("ERROR: Could not find input CSV:\n" + inputCSV);
    }

    // --------------------------------------------------
    // Output folders
    // --------------------------------------------------

    dirFinal = parentDir + "09_Marker_Association_0p5um_Final/";
    dirResults = dirFinal + "01_Results/";

    File.makeDirectory(dirFinal);
    File.makeDirectory(dirResults);

    pairwiseCSV = dirResults + "postsynaptic_to_bassoon_0p5um.csv";
    bassoonCSV  = dirResults + "bassoon_classification_0p5um.csv";
    summaryCSV  = dirResults + "association_summary_0p5um.csv";

    // --------------------------------------------------
    // Final proximity threshold
    // --------------------------------------------------

    threshold = 0.5;

    File.append("----------------------------------------", logFile);
    File.append("Starting Macro 4 FINAL: marker association from coordinates.", logFile);
    File.append("Final threshold: " + threshold + " um", logFile);
    File.append("Input CSV:", logFile);
    File.append(inputCSV, logFile);
    File.append("Output folder:", logFile);
    File.append(dirResults, logFile);

    // --------------------------------------------------
    // Read CSV
    // --------------------------------------------------

    csvText = File.openAsString(inputCSV);
    lines = split(csvText, "\n");

    // Count valid data rows.
    n = 0;

    for (i = 1; i < lines.length; i++) {
        line = lines[i];

        if (lengthOf(line) > 10) {
            n++;
        }
    }

    if (n == 0) {
        exit("ERROR: No data rows found in:\n" + inputCSV);
    }

    // --------------------------------------------------
    // Allocate arrays
    // --------------------------------------------------

    Image_ID = newArray(n);
    Region = newArray(n);
    Layer = newArray(n);
    ROI_ID = newArray(n);
    Channel = newArray(n);
    Marker = newArray(n);
    Z_group = newArray(n);
    Particle_ID = newArray(n);

    ROI_width_um = newArray(n);
    ROI_height_um = newArray(n);
    ROI_area_um2 = newArray(n);

    X_um = newArray(n);
    Y_um = newArray(n);
    Area_um2 = newArray(n);

    // --------------------------------------------------
    // Fill arrays from Macro 3 CSV
    // --------------------------------------------------
    //
    // Expected Macro 3 column positions:
    //
    // 0  Image_ID
    // 1  Region
    // 2  Layer
    // 3  ROI_ID
    // 4  Channel
    // 5  Marker
    // 6  Z_group
    // 7  Particle_ID
    // 8  ROI_width_um
    // 9  ROI_height_um
    // 10 ROI_area_um2
    // 15 X_centroid_um
    // 16 Y_centroid_um
    // 19 Area_um2
    //
    // --------------------------------------------------

    row = 0;

    for (i = 1; i < lines.length; i++) {

        line = lines[i];

        if (lengthOf(line) <= 10) {
            continue;
        }

        cols = split(line, ",");

        if (cols.length < 20) {
            File.append("WARNING: Skipping malformed row:", logFile);
            File.append(line, logFile);
            continue;
        }

        Image_ID[row] = cols[0];
        Region[row] = cols[1];
        Layer[row] = cols[2];
        ROI_ID[row] = cols[3];
        Channel[row] = cols[4];
        Marker[row] = cols[5];
        Z_group[row] = cols[6];
        Particle_ID[row] = cols[7];

        ROI_width_um[row] = parseFloat(cols[8]);
        ROI_height_um[row] = parseFloat(cols[9]);
        ROI_area_um2[row] = parseFloat(cols[10]);

        X_um[row] = parseFloat(cols[15]);
        Y_um[row] = parseFloat(cols[16]);
        Area_um2[row] = parseFloat(cols[19]);

        row++;
    }

    n = row;

    File.append("Loaded puncta rows: " + n, logFile);

    // --------------------------------------------------
    // Write output headers
    // --------------------------------------------------

    pairwiseHeader =
        "Image_ID,Region,Layer,ROI_ID,Z_group," +
        "Postsynaptic_marker,Post_particle_ID,Post_X_um,Post_Y_um," +
        "Nearest_Bassoon_ID,Nearest_Bassoon_X_um,Nearest_Bassoon_Y_um," +
        "Distance_to_nearest_Bassoon_um," +
        "Distance_threshold_um,Associated_with_Bassoon\n";

    bassoonHeader =
        "Image_ID,Region,Layer,ROI_ID,Z_group," +
        "Bassoon_particle_ID,Bassoon_X_um,Bassoon_Y_um," +
        "Nearest_PSD95_ID,Nearest_PSD95_distance_um," +
        "Nearest_Gephyrin_ID,Nearest_Gephyrin_distance_um," +
        "PSD95_count_within_0p5um,PSD95_IDs_within_0p5um," +
        "Gephyrin_count_within_0p5um,Gephyrin_IDs_within_0p5um," +
        "Distance_threshold_um,Bassoon_class\n";

    summaryHeader =
        "Image_ID,Region,Layer,ROI_ID,Z_group," +
        "ROI_area_um2,Distance_threshold_um," +
        "Bassoon_count,PSD95_count,Gephyrin_count," +
        "PSD95_with_Bassoon_count,PSD95_with_Bassoon_fraction," +
        "PSD95_Bassoon_association_density_per_100um2," +
        "Gephyrin_with_Bassoon_count,Gephyrin_with_Bassoon_fraction," +
        "Gephyrin_Bassoon_association_density_per_100um2," +
        "Bassoon_PSD95_only_count,Bassoon_Gephyrin_only_count," +
        "Bassoon_both_PSD95_and_Gephyrin_count,Bassoon_unassigned_count," +
        "Bassoon_PSD95_only_fraction,Bassoon_Gephyrin_only_fraction," +
        "Bassoon_both_fraction,Bassoon_unassigned_fraction\n";

    File.saveString(pairwiseHeader, pairwiseCSV);
    File.saveString(bassoonHeader, bassoonCSV);
    File.saveString(summaryHeader, summaryCSV);

    // --------------------------------------------------
    // Output 1:
    // Postsynaptic marker -> nearest Bassoon
    // --------------------------------------------------

    File.append("----------------------------------------", logFile);
    File.append("Writing postsynaptic-to-Bassoon nearest-neighbor table at 0.5 um.", logFile);

    for (i = 0; i < n; i++) {

        if (Marker[i] == "PSD95" || Marker[i] == "Gephyrin") {

            nearestBassoonIndex = findNearestMarker(i, "Bassoon");
            nearestDistance = 999999999;

            nearestID = "NA";
            nearestX = "NA";
            nearestY = "NA";

            if (nearestBassoonIndex >= 0) {
                nearestDistance = distanceBetween(i, nearestBassoonIndex);
                nearestID = Particle_ID[nearestBassoonIndex];
                nearestX = X_um[nearestBassoonIndex];
                nearestY = Y_um[nearestBassoonIndex];
            }

            if (nearestBassoonIndex >= 0 && nearestDistance <= threshold) {
                associated = "yes";
            } else {
                associated = "no";
            }

            pairwiseRow =
                Image_ID[i] + "," +
                Region[i] + "," +
                Layer[i] + "," +
                ROI_ID[i] + "," +
                Z_group[i] + "," +
                Marker[i] + "," +
                Particle_ID[i] + "," +
                X_um[i] + "," +
                Y_um[i] + "," +
                nearestID + "," +
                nearestX + "," +
                nearestY + "," +
                nearestDistance + "," +
                threshold + "," +
                associated + "\n";

            File.append(pairwiseRow, pairwiseCSV);
        }
    }

    // --------------------------------------------------
    // Output 2:
    // Bassoon classification at 0.5 um
    // --------------------------------------------------

    File.append("----------------------------------------", logFile);
    File.append("Writing Bassoon classification table at 0.5 um.", logFile);

    for (i = 0; i < n; i++) {

        if (Marker[i] == "Bassoon") {

            nearestPSD95Index = findNearestMarker(i, "PSD95");
            nearestGephyrinIndex = findNearestMarker(i, "Gephyrin");

            nearestPSD95Distance = 999999999;
            nearestGephyrinDistance = 999999999;

            nearestPSD95ID = "NA";
            nearestGephyrinID = "NA";

            if (nearestPSD95Index >= 0) {
                nearestPSD95Distance = distanceBetween(i, nearestPSD95Index);
                nearestPSD95ID = Particle_ID[nearestPSD95Index];
            }

            if (nearestGephyrinIndex >= 0) {
                nearestGephyrinDistance = distanceBetween(i, nearestGephyrinIndex);
                nearestGephyrinID = Particle_ID[nearestGephyrinIndex];
            }

            psd95Count = countMarkersWithinThreshold(i, "PSD95", threshold);
            gephyrinCount = countMarkersWithinThreshold(i, "Gephyrin", threshold);

            psd95IDs = markerIDsWithinThreshold(i, "PSD95", threshold);
            gephyrinIDs = markerIDsWithinThreshold(i, "Gephyrin", threshold);

            if (psd95Count > 0 && gephyrinCount == 0) {
                bassoonClass = "PSD95_only";
            } else if (psd95Count == 0 && gephyrinCount > 0) {
                bassoonClass = "Gephyrin_only";
            } else if (psd95Count > 0 && gephyrinCount > 0) {
                bassoonClass = "Both_PSD95_and_Gephyrin";
            } else {
                bassoonClass = "Unassigned";
            }

            bassoonRow =
                Image_ID[i] + "," +
                Region[i] + "," +
                Layer[i] + "," +
                ROI_ID[i] + "," +
                Z_group[i] + "," +
                Particle_ID[i] + "," +
                X_um[i] + "," +
                Y_um[i] + "," +
                nearestPSD95ID + "," +
                nearestPSD95Distance + "," +
                nearestGephyrinID + "," +
                nearestGephyrinDistance + "," +
                psd95Count + "," +
                psd95IDs + "," +
                gephyrinCount + "," +
                gephyrinIDs + "," +
                threshold + "," +
                bassoonClass + "\n";

            File.append(bassoonRow, bassoonCSV);
        }
    }

    // --------------------------------------------------
    // Output 3:
    // Summary by Image/Region/Layer/ROI/Z_group
    // --------------------------------------------------

    File.append("----------------------------------------", logFile);
    File.append("Writing final 0.5 um association summary table.", logFile);

    for (i = 0; i < n; i++) {

        if (isFirstOccurrenceOfGroup(i)) {
            writeSummaryForGroup(i, threshold, summaryCSV);
        }
    }

    File.append("----------------------------------------", logFile);
    File.append("DONE.", logFile);
    File.append("Final 0.5 um postsynaptic-to-Bassoon table:", logFile);
    File.append(pairwiseCSV, logFile);
    File.append("Final 0.5 um Bassoon classification table:", logFile);
    File.append(bassoonCSV, logFile);
    File.append("Final 0.5 um association summary table:", logFile);
    File.append(summaryCSV, logFile);
}


// ==================================================
// FUNCTION: sameGroup
// ==================================================
//
// Same biological/spatial analysis group means same:
//      Image_ID
//      Region
//      Layer
//      ROI_ID
//      Z_group
//
// ==================================================

function sameGroup(i, j) {

    if (Image_ID[i] != Image_ID[j]) return false;
    if (Region[i] != Region[j]) return false;
    if (Layer[i] != Layer[j]) return false;
    if (ROI_ID[i] != ROI_ID[j]) return false;
    if (Z_group[i] != Z_group[j]) return false;

    return true;
}


// ==================================================
// FUNCTION: distanceBetween
// ==================================================

function distanceBetween(i, j) {

    dx = X_um[i] - X_um[j];
    dy = Y_um[i] - Y_um[j];

    return sqrt(dx * dx + dy * dy);
}


// ==================================================
// FUNCTION: findNearestMarker
// ==================================================
//
// Finds nearest punctum of targetMarker within the same group.
// Returns array index, or -1 if none exists.
//
// ==================================================

function findNearestMarker(sourceIndex, targetMarker) {

    bestIndex = -1;
    bestDistance = 999999999;

    for (j = 0; j < n; j++) {

        if (j == sourceIndex) continue;

        if (!sameGroup(sourceIndex, j)) continue;

        if (Marker[j] != targetMarker) continue;

        d = distanceBetween(sourceIndex, j);

        if (d < bestDistance) {
            bestDistance = d;
            bestIndex = j;
        }
    }

    return bestIndex;
}


// ==================================================
// FUNCTION: countMarkersWithinThreshold
// ==================================================
//
// Counts how many targetMarker puncta are within the threshold
// from the source punctum, within the same group.
//
// ==================================================

function countMarkersWithinThreshold(sourceIndex, targetMarker, threshold) {

    count = 0;

    for (j = 0; j < n; j++) {

        if (j == sourceIndex) continue;

        if (!sameGroup(sourceIndex, j)) continue;

        if (Marker[j] != targetMarker) continue;

        d = distanceBetween(sourceIndex, j);

        if (d <= threshold) {
            count++;
        }
    }

    return count;
}


// ==================================================
// FUNCTION: markerIDsWithinThreshold
// ==================================================
//
// Returns IDs separated by semicolons.
// Semicolon is used to avoid breaking CSV format.
//
// ==================================================

function markerIDsWithinThreshold(sourceIndex, targetMarker, threshold) {

    ids = "none";
    first = true;

    for (j = 0; j < n; j++) {

        if (j == sourceIndex) continue;

        if (!sameGroup(sourceIndex, j)) continue;

        if (Marker[j] != targetMarker) continue;

        d = distanceBetween(sourceIndex, j);

        if (d <= threshold) {

            if (first) {
                ids = Particle_ID[j];
                first = false;
            } else {
                ids = ids + ";" + Particle_ID[j];
            }
        }
    }

    return ids;
}


// ==================================================
// FUNCTION: isFirstOccurrenceOfGroup
// ==================================================
//
// Used to write one summary row per group.
//
// ==================================================

function isFirstOccurrenceOfGroup(i) {

    for (j = 0; j < i; j++) {

        if (sameGroup(i, j)) {
            return false;
        }
    }

    return true;
}


// ==================================================
// FUNCTION: writeSummaryForGroup
// ==================================================

function writeSummaryForGroup(groupIndex, threshold, summaryCSV) {

    bassoonCount = 0;
    psd95Count = 0;
    gephyrinCount = 0;

    psd95WithBassoon = 0;
    gephyrinWithBassoon = 0;

    bassoonPSD95Only = 0;
    bassoonGephyrinOnly = 0;
    bassoonBoth = 0;
    bassoonUnassigned = 0;

    roiArea = ROI_area_um2[groupIndex];

    // --------------------------------------------------
    // Count marker totals and postsynaptic associations
    // --------------------------------------------------

    for (i = 0; i < n; i++) {

        if (!sameGroup(groupIndex, i)) continue;

        if (Marker[i] == "Bassoon") {
            bassoonCount++;
        }

        if (Marker[i] == "PSD95") {
            psd95Count++;

            nearestBassoonIndex = findNearestMarker(i, "Bassoon");

            if (nearestBassoonIndex >= 0) {
                d = distanceBetween(i, nearestBassoonIndex);

                if (d <= threshold) {
                    psd95WithBassoon++;
                }
            }
        }

        if (Marker[i] == "Gephyrin") {
            gephyrinCount++;

            nearestBassoonIndex = findNearestMarker(i, "Bassoon");

            if (nearestBassoonIndex >= 0) {
                d = distanceBetween(i, nearestBassoonIndex);

                if (d <= threshold) {
                    gephyrinWithBassoon++;
                }
            }
        }
    }

    // --------------------------------------------------
    // Bassoon classification counts
    // --------------------------------------------------

    for (i = 0; i < n; i++) {

        if (!sameGroup(groupIndex, i)) continue;

        if (Marker[i] != "Bassoon") continue;

        psd95CountNear = countMarkersWithinThreshold(i, "PSD95", threshold);
        gephyrinCountNear = countMarkersWithinThreshold(i, "Gephyrin", threshold);

        if (psd95CountNear > 0 && gephyrinCountNear == 0) {
            bassoonPSD95Only++;
        } else if (psd95CountNear == 0 && gephyrinCountNear > 0) {
            bassoonGephyrinOnly++;
        } else if (psd95CountNear > 0 && gephyrinCountNear > 0) {
            bassoonBoth++;
        } else {
            bassoonUnassigned++;
        }
    }

    // --------------------------------------------------
    // Fractions and densities
    // --------------------------------------------------

    if (psd95Count > 0) {
        psd95WithBassoonFraction = psd95WithBassoon / psd95Count;
    } else {
        psd95WithBassoonFraction = 0;
    }

    if (gephyrinCount > 0) {
        gephyrinWithBassoonFraction = gephyrinWithBassoon / gephyrinCount;
    } else {
        gephyrinWithBassoonFraction = 0;
    }

    psd95BassoonDensityPer100 = (psd95WithBassoon / roiArea) * 100;
    gephyrinBassoonDensityPer100 = (gephyrinWithBassoon / roiArea) * 100;

    if (bassoonCount > 0) {
        bassoonPSD95OnlyFraction = bassoonPSD95Only / bassoonCount;
        bassoonGephyrinOnlyFraction = bassoonGephyrinOnly / bassoonCount;
        bassoonBothFraction = bassoonBoth / bassoonCount;
        bassoonUnassignedFraction = bassoonUnassigned / bassoonCount;
    } else {
        bassoonPSD95OnlyFraction = 0;
        bassoonGephyrinOnlyFraction = 0;
        bassoonBothFraction = 0;
        bassoonUnassignedFraction = 0;
    }

    summaryRow =
        Image_ID[groupIndex] + "," +
        Region[groupIndex] + "," +
        Layer[groupIndex] + "," +
        ROI_ID[groupIndex] + "," +
        Z_group[groupIndex] + "," +
        roiArea + "," +
        threshold + "," +
        bassoonCount + "," +
        psd95Count + "," +
        gephyrinCount + "," +
        psd95WithBassoon + "," +
        psd95WithBassoonFraction + "," +
        psd95BassoonDensityPer100 + "," +
        gephyrinWithBassoon + "," +
        gephyrinWithBassoonFraction + "," +
        gephyrinBassoonDensityPer100 + "," +
        bassoonPSD95Only + "," +
        bassoonGephyrinOnly + "," +
        bassoonBoth + "," +
        bassoonUnassigned + "," +
        bassoonPSD95OnlyFraction + "," +
        bassoonGephyrinOnlyFraction + "," +
        bassoonBothFraction + "," +
        bassoonUnassignedFraction + "\n";

    File.append(summaryRow, summaryCSV);
}