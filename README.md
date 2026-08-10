# Synapse Analysis Pipeline
Python TKinter application for running [CruzMartinsLab's](https://github.com/CruzMartinLab) synapse analysis pipeline.


## Setup
```bash
git clone https://github.com/Cruz-Martin-Lab/synape_analysis_pipeline.git

cd synapse_analsys_pipeline
```  

### For Windows users:
```
.\win_setup.bat
```
Or double click win_setup.bat in file explorer.

### For Mac users:
```
chmod +x setup.sh

./mac_setup.sh
```
<br>


Fiji is also a requirement. If not already installed, setup information can be found [here](https://imagej.net/software/fiji/).

Before running the pipeline, ensure you have formatted an input/output directory with the following structure( The directory naming can be different, as long as the structure is as follows):

```
├── output_dir/      
│   ├── full_stack_img_dir/ 
│   │   └── L00_0001.tif
│   │   └── L00_0002.tif
│   │   └── ...
```

NOTE - Even if you are only running a single .tif through the pipeline,it is still recommended to structure it like this.

## Usage
To run the python application.
```bash
conda activate syn_pl

python run_pipeline.py
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