import os
import argparse
import numpy as np
import pandas as pd
from scipy.spatial import cKDTree


# ==================================================
# SETTINGS
# ==================================================


parser = argparse.ArgumentParser()
parser.add_argument("parent_dir", type=str)
args = parser.parse_args()
parent_dir = args.parent_dir

input_csv = os.path.join(
    parent_dir,
    "07_Individual_Marker_Analysis",
    "01_Results",
    "individual_puncta_coordinates.csv"
)

output_dir = os.path.join(
    parent_dir,
    "11_Spatial_Randomization_Analysis",
    "01_Results"
)

os.makedirs(output_dir, exist_ok=True)

output_summary_csv = os.path.join(
    output_dir,
    "marker_proximity_randomization_summary.csv"
)

output_iteration_csv = os.path.join(
    output_dir,
    "marker_proximity_randomization_iterations.csv"
)

# Main proximity threshold from Macro 4
distance_threshold_um = 0.5

# Number of randomizations
n_iterations = 5000

# Reproducibility
random_seed = 42
rng = np.random.default_rng(random_seed)


# ==================================================
# FUNCTIONS
# ==================================================

def nearest_bassoon_distances(post_coords, bassoon_coords):
    """
    For each postsynaptic punctum, calculate distance to nearest Bassoon punctum.
    """
    if len(post_coords) == 0 or len(bassoon_coords) == 0:
        return np.array([])

    tree = cKDTree(bassoon_coords)
    distances, _ = tree.query(post_coords, k=1)
    return distances


def fraction_within_threshold(post_coords, bassoon_coords, threshold_um):
    """
    Fraction of postsynaptic puncta within threshold distance of nearest Bassoon.
    """
    distances = nearest_bassoon_distances(post_coords, bassoon_coords)

    if len(distances) == 0:
        return np.nan, np.nan, np.nan, 0

    count = int(np.sum(distances <= threshold_um))
    fraction = count / len(distances)
    median_distance = float(np.median(distances))
    mean_distance = float(np.mean(distances))

    return fraction, median_distance, mean_distance, count


def randomize_points_uniform(n_points, width_um, height_um, rng):
    """
    Generate random coordinates uniformly across the rectangular ROI.
    """
    x = rng.uniform(0, width_um, n_points)
    y = rng.uniform(0, height_um, n_points)
    return np.column_stack([x, y])


def empirical_p_value_greater(observed, randomized_values):
    """
    One-sided empirical p-value:
    probability that randomized value is greater than or equal to observed.
    """
    randomized_values = np.asarray(randomized_values)
    return (np.sum(randomized_values >= observed) + 1) / (len(randomized_values) + 1)


# ==================================================
# LOAD DATA
# ==================================================

print("Loading coordinate file:")
print(input_csv)

df = pd.read_csv(input_csv)

required_cols = [
    "Region",
    "Layer",
    "ROI_ID",
    "Z_group",
    "Marker",
    "X_centroid_um",
    "Y_centroid_um",
    "ROI_width_um",
    "ROI_height_um",
    "ROI_area_um2",
]

missing = [c for c in required_cols if c not in df.columns]
if missing:
    raise ValueError(f"Missing required columns from input CSV: {missing}")

df["Marker"] = df["Marker"].astype(str)

summary_rows = []
iteration_rows = []

group_cols = ["Region", "Layer", "ROI_ID", "Z_group"]


# ==================================================
# MAIN ANALYSIS
# ==================================================

for group_key, group_df in df.groupby(group_cols):

    region, layer, roi_id, z_group = group_key

    width_um = float(group_df["ROI_width_um"].iloc[0])
    height_um = float(group_df["ROI_height_um"].iloc[0])
    roi_area_um2 = float(group_df["ROI_area_um2"].iloc[0])

    bassoon_df = group_df[group_df["Marker"].str.contains("Bassoon", case=False, na=False)]
    psd95_df = group_df[group_df["Marker"].str.contains("PSD95", case=False, na=False)]
    gephyrin_df = group_df[group_df["Marker"].str.contains("Gephyrin", case=False, na=False)]

    bassoon_coords = bassoon_df[["X_centroid_um", "Y_centroid_um"]].to_numpy()

    marker_tables = {
        "PSD95": psd95_df,
        "Gephyrin": gephyrin_df,
    }

    for post_marker, post_df in marker_tables.items():

        post_coords = post_df[["X_centroid_um", "Y_centroid_um"]].to_numpy()

        n_bassoon = len(bassoon_coords)
        n_post = len(post_coords)

        if n_bassoon == 0 or n_post == 0:
            print(f"Skipping {region} {layer} {roi_id} Z {z_group} {post_marker}: missing points")
            continue

        observed_fraction, observed_median_distance, observed_mean_distance, observed_count = (
            fraction_within_threshold(
                post_coords,
                bassoon_coords,
                distance_threshold_um
            )
        )

        randomized_fractions = []
        randomized_medians = []
        randomized_means = []

        print(
            f"Running {n_iterations} randomizations: "
            f"{region} {layer} {roi_id} Z {z_group} {post_marker}"
        )

        for i in range(n_iterations):

            random_post_coords = randomize_points_uniform(
                n_points=n_post,
                width_um=width_um,
                height_um=height_um,
                rng=rng
            )

            rand_fraction, rand_median, rand_mean, rand_count = fraction_within_threshold(
                random_post_coords,
                bassoon_coords,
                distance_threshold_um
            )

            randomized_fractions.append(rand_fraction)
            randomized_medians.append(rand_median)
            randomized_means.append(rand_mean)

            iteration_rows.append({
                "Region": region,
                "Layer": layer,
                "ROI_ID": roi_id,
                "Z_group": z_group,
                "Post_marker": post_marker,
                "Iteration": i + 1,
                "Random_fraction_within_threshold": rand_fraction,
                "Random_percent_within_threshold": rand_fraction * 100,
                "Random_median_nearest_Bassoon_distance_um": rand_median,
                "Random_mean_nearest_Bassoon_distance_um": rand_mean,
            })

        randomized_fractions = np.array(randomized_fractions)
        randomized_medians = np.array(randomized_medians)
        randomized_means = np.array(randomized_means)

        random_mean_fraction = float(np.mean(randomized_fractions))
        random_sd_fraction = float(np.std(randomized_fractions, ddof=1))

        random_lower_95 = float(np.percentile(randomized_fractions, 2.5))
        random_upper_95 = float(np.percentile(randomized_fractions, 97.5))

        if random_mean_fraction > 0:
            enrichment = observed_fraction / random_mean_fraction
        else:
            enrichment = np.nan

        if random_sd_fraction > 0:
            z_score = (observed_fraction - random_mean_fraction) / random_sd_fraction
        else:
            z_score = np.nan

        empirical_p = empirical_p_value_greater(
            observed_fraction,
            randomized_fractions
        )

        summary_rows.append({
            "Region": region,
            "Layer": layer,
            "ROI_ID": roi_id,
            "Z_group": z_group,
            "Post_marker": post_marker,
            "Distance_threshold_um": distance_threshold_um,
            "N_iterations": n_iterations,
            "N_Bassoon": n_bassoon,
            "N_post_marker": n_post,
            "Observed_count_within_threshold": observed_count,
            "Observed_fraction_within_threshold": observed_fraction,
            "Observed_percent_within_threshold": observed_fraction * 100,
            "Observed_median_nearest_Bassoon_distance_um": observed_median_distance,
            "Observed_mean_nearest_Bassoon_distance_um": observed_mean_distance,
            "Random_mean_fraction_within_threshold": random_mean_fraction,
            "Random_mean_percent_within_threshold": random_mean_fraction * 100,
            "Random_SD_fraction_within_threshold": random_sd_fraction,
            "Random_2p5_percentile_fraction": random_lower_95,
            "Random_97p5_percentile_fraction": random_upper_95,
            "Random_2p5_percentile_percent": random_lower_95 * 100,
            "Random_97p5_percentile_percent": random_upper_95 * 100,
            "Observed_expected_enrichment": enrichment,
            "Z_score_vs_random": z_score,
            "Empirical_p_value_greater": empirical_p,
            "ROI_width_um": width_um,
            "ROI_height_um": height_um,
            "ROI_area_um2": roi_area_um2,
        })


# ==================================================
# SAVE OUTPUTS
# ==================================================

summary_df = pd.DataFrame(summary_rows)
iteration_df = pd.DataFrame(iteration_rows)

summary_df.to_csv(output_summary_csv, index=False)
iteration_df.to_csv(output_iteration_csv, index=False)

print("")
print("DONE")
print("Summary saved to:")
print(output_summary_csv)
print("Iterations saved to:")
print(output_iteration_csv)
print("")
print(summary_df)