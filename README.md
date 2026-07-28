# Synapse Analysis Pipeline
Python TKinter application for running [CruzMartinsLab's](https://github.com/CruzMartinLab) synapse analysis pipeline.


## Setup

After cloning the repository, the python environment can be set up using conda. Navigate to the repo directory and create the conda environment.
(If conda is not installed, instructions for setting it up can be found [here](https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html))

```bash
$ conda env create -f environment.yml
```

Fiji is also a requirement. If not already installed, setup information can be found [here](https://imagej.net/software/fiji/).

Before running the pipeline, ensure you have formatted an input/output directory with the following structure( The directory naming can be different, as long as the structure is as follows):

```
├── output_dir/      
│   ├── full_stack_img_dir/ 
│   │   └── L23_0001.tif
│   │   └── L23_0002.tif
│   │   └── ...
```

NOTE - Even if you are only running a single .tif through the pipeline,it is still recommended to structure it like this.

## Usage

Run the following conda command to activate the corresponding environment.
```bash
$ conda activate syn_pl
```  

Then run the python application.
```bash
$ python run_pipeline.py
```

The application will then prompt for the full path to your installed fiji installation. (Windows will be .exe, Mac will be .app)

Then input the full path to the output folder
```
<Path>/output_dir
```
Followed by the full path to the folder containing the tifs.
```
<Path>/full_stack_img_dir
```