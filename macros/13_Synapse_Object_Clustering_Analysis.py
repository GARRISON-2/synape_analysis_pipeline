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
    "13_Synapse_Object_Clustering_Analysis",
    "01_Results"
)

os.makedirs(output_dir, exist_ok=True)

output_summary_csv = os.path.join(
    output_dir,
    "synapse_object_nearest_neighbor_clustering_summary.csv"
)

output_iteration_csv = os.path.join(
    output_dir,
    "synapse_object_nearest_neighbor_clustering_iterations.csv"
)

# Synapse-like association threshold
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


def get_bassoon_associated_postsynaptic_objects(post_coords, bassoon_coords, threshold_um):
    """
    Return postsynaptic puncta that are within threshold_um of nearest Bassoon.
    These are treated as synapse-like objects.
    """
    distances = nearest_bassoon_distances(post_coords, bassoon_coords)

    if len(distances) == 0:
        return np.empty((0, 2)), np.array([])

    associated_mask = distances <= threshold_um
    associated_coords = post_coords[associated_mask]
    associated_distances = distances[associated_mask]

    return associated_coords, associated_distances


def nearest_neighbor_distances(coords):
    """
    For each object, calculate distance to the nearest other object
    of the same synapse-like class.
    """
    if len(coords) < 2:
        return np.array([])

    tree = cKDTree(coords)

    # k=2 because the closest point is itself at distance 0.
    distances, _ = tree.query(coords, k=2)

    # distances[:, 0] = self distance
    # distances[:, 1] = nearest other object
    return distances[:, 1]


def randomize_points_uniform(n_points, width_um, height_um, rng):
    """
    Generate random coordinates uniformly across the rectangular ROI.
    """
    x = rng.uniform(0, width_um, n_points)
    y = rng.uniform(0, height_um, n_points)
    return np.column_stack([x, y])


def empirical_p_value_clustered(observed_median, randomized_medians):
    """
    One-sided empirical p-value for clustering.

    Clustered means observed median nearest-neighbor distance is
    smaller than expected from random placement.
    """
    randomized_medians = np.asarray(randomized_medians)

    return (np.sum(randomized_medians <= observed_median) + 1) / (
        len(randomized_medians) + 1
    )


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

    bassoon_df = group_df[
        group_df["Marker"].str.contains("Bassoon", case=False, na=False)
    ]

    psd95_df = group_df[
        group_df["Marker"].str.contains("PSD95", case=False, na=False)
    ]

    gephyrin_df = group_df[
        group_df["Marker"].str.contains("Gephyrin", case=False, na=False)
    ]

    bassoon_coords = bassoon_df[["X_centroid_um", "Y_centroid_um"]].to_numpy()
    psd95_coords = psd95_df[["X_centroid_um", "Y_centroid_um"]].to_numpy()
    gephyrin_coords = gephyrin_df[["X_centroid_um", "Y_centroid_um"]].to_numpy()

    synapse_classes = {
        "Excitatory_like_PSD95_near_Bassoon": psd95_coords,
        "Inhibitory_like_Gephyrin_near_Bassoon": gephyrin_coords,
    }

    for synapse_class, post_coords in synapse_classes.items():

        n_bassoon = len(bassoon_coords)
        n_post_total = len(post_coords)

        if n_bassoon == 0 or n_post_total == 0:
            print(
                f"Skipping {region} {layer} {roi_id} Z {z_group} {synapse_class}: "
                f"missing Bassoon or postsynaptic marker"
            )
            continue

        associated_coords, associated_distances_to_bassoon = (
            get_bassoon_associated_postsynaptic_objects(
                post_coords=post_coords,
                bassoon_coords=bassoon_coords,
                threshold_um=distance_threshold_um
            )
        )

        n_synapse_like_objects = len(associated_coords)

        if n_synapse_like_objects < 2:
            print(
                f"Skipping {region} {layer} {roi_id} Z {z_group} {synapse_class}: "
                f"fewer than 2 synapse-like objects"
            )
            continue

        observed_nn_distances = nearest_neighbor_distances(associated_coords)

        observed_median_nn = float(np.median(observed_nn_distances))
        observed_mean_nn = float(np.mean(observed_nn_distances))

        randomized_medians = []
        randomized_means = []

        print(
            f"Running {n_iterations} synapse-object clustering randomizations: "
            f"{region} {layer} {roi_id} Z {z_group} {synapse_class}"
        )

        for i in range(n_iterations):

            random_coords = randomize_points_uniform(
                n_points=n_synapse_like_objects,
                width_um=width_um,
                height_um=height_um,
                rng=rng
            )

            random_nn_distances = nearest_neighbor_distances(random_coords)

            rand_median = float(np.median(random_nn_distances))
            rand_mean = float(np.mean(random_nn_distances))

            randomized_medians.append(rand_median)
            randomized_means.append(rand_mean)

            iteration_rows.append({
                "Region": region,
                "Layer": layer,
                "ROI_ID": roi_id,
                "Z_group": z_group,
                "Synapse_class": synapse_class,
                "Iteration": i + 1,
                "Random_median_nearest_neighbor_distance_um": rand_median,
                "Random_mean_nearest_neighbor_distance_um": rand_mean,
            })

        randomized_medians = np.array(randomized_medians)
        randomized_means = np.array(randomized_means)

        random_mean_median_nn = float(np.mean(randomized_medians))
        random_sd_median_nn = float(np.std(randomized_medians, ddof=1))

        random_2p5_median_nn = float(np.percentile(randomized_medians, 2.5))
        random_97p5_median_nn = float(np.percentile(randomized_medians, 97.5))

        # >1 means observed synapse-like objects are closer together than random.
        clustering_enrichment = random_mean_median_nn / observed_median_nn

        if random_sd_median_nn > 0:
            z_score = (
                observed_median_nn - random_mean_median_nn
            ) / random_sd_median_nn
        else:
            z_score = np.nan

        empirical_p = empirical_p_value_clustered(
            observed_median_nn,
            randomized_medians
        )

        summary_rows.append({
            "Region": region,
            "Layer": layer,
            "ROI_ID": roi_id,
            "Z_group": z_group,
            "Synapse_class": synapse_class,
            "Distance_threshold_um": distance_threshold_um,
            "N_iterations": n_iterations,
            "N_Bassoon": n_bassoon,
            "N_post_marker_total": n_post_total,
            "N_synapse_like_objects": n_synapse_like_objects,
            "Percent_post_marker_associated_with_Bassoon": (
                n_synapse_like_objects / n_post_total * 100
            ),
            "Median_distance_to_nearest_Bassoon_um_for_synapse_like_objects": float(
                np.median(associated_distances_to_bassoon)
            ),
            "Observed_median_nearest_neighbor_distance_um": observed_median_nn,
            "Observed_mean_nearest_neighbor_distance_um": observed_mean_nn,
            "Random_mean_median_nearest_neighbor_distance_um": random_mean_median_nn,
            "Random_SD_median_nearest_neighbor_distance_um": random_sd_median_nn,
            "Random_2p5_percentile_median_nearest_neighbor_distance_um": random_2p5_median_nn,
            "Random_97p5_percentile_median_nearest_neighbor_distance_um": random_97p5_median_nn,
            "Clustering_enrichment_random_over_observed": clustering_enrichment,
            "Z_score_vs_random": z_score,
            "Empirical_p_value_clustered": empirical_p,
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
