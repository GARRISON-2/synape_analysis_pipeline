from pathlib import Path
import subprocess
import tkinter as tk
import argparse
import csv

"""
Author: GA
Description: Creates tkinter app instance to run synapse analysis pipeline.
             Each visual aspect is handled in the classes starting with form.
             The bulk of the computation is managed by processNextFile.
"""

class App:
    def __init__(self, root, debug):
        self.root = root     
        self.debug = debug 
        self.headless = not debug
        self.root.geometry("750x450")
        self._APP_HOME = Path(__file__).resolve().parent
        self._APP_DATA = self._APP_HOME / '.app_data'
        self.fiji_path = ""
        self.macro_paths = [
            self._APP_HOME / "macros" / "01_Preprocess_32bit_ZProject_then_8bit_STUDENT_VERSION.ijm",
            self._APP_HOME / "macros" / "02_Make_Masks_From_Z_Projects_WORKING.ijm",
            self._APP_HOME / "macros" / "03_Analyze_Individual_Marker_Puncta_WITH_ROI_AREA_WORKING.ijm",
            self._APP_HOME / "macros" / "04_Associate_Markers_From_Coordinates_0p5um_FINAL_WORKING.ijm",
            self._APP_HOME / "macros" / "05_Marker_Pixel_Overlap_Analysis_WORKING.ijm",
            self._APP_HOME / "macros" / "06_Spatial_Randomization_Analysis.py",
            self._APP_HOME / "macros" / "12_Spatial_Clustering_Analysis.py",
            self._APP_HOME / "macros" / "13_Synapse_Object_Clustering_Analysis.py",
        ]

        tk.Label(self.root, 
                 text="Synapse Analysis Pipeline", 
                 font=("Arial", 16, "bold")).pack(pady=10)

        # set content frame to be cleared and reformed as needed
        self.content_frame = tk.Frame(self.root)
        self.content_frame.pack(fill="both", expand=True)

        # check for existing fiji path in app data first, and handle accordingly
        self.checkFiji()


    def checkFiji(self):
        data_dict = {}

        # if the fiji path has not already been set
        if not self.fiji_path:
            try:
                with open(self._APP_DATA, 'r', encoding="utf-8") as ap:
                    csv_reader = csv.DictReader(ap, delimiter='\t')
                    for row in csv_reader:
                        key = row.pop('id')  
                        data_dict[key] = row

            except FileNotFoundError:
                with open(self._APP_DATA, 'w', encoding="utf-8") as ap:
                    ap.write("id\tvalue")

            if "fiji_path" in data_dict:
                self.fiji_path = data_dict["fiji_path"]["value"]
            else:
                self.formFijiWindow()
                return

        # verify the path points to a real executable file
        if not Path(self.fiji_path).is_file():
            self.fiji_path = ""  # reset so checkFiji doesn't skip the form next time
            self.clearScreen()
            tk.Label(self.content_frame,
                    text="File not found. Please locate Fiji again.\nEnsure path points to the executable, not a directory.",
                    fg="red").pack(pady=5)
            self.root.update()
            self.formFijiWindow(show_form=False)  # don't clear screen, just add form below error
            return

        # do a test run with --version to confirm Fiji actually launches correctly
        try:
            result = subprocess.run(
                [self.fiji_path, "--version"],
                capture_output=True, text=True, timeout=15
            )
            if result.returncode != 0:
                raise RuntimeError(f"Fiji returned non-zero exit code")

            # success
            self.formWindow1()

        except subprocess.TimeoutExpired:
            self.fiji_path = ""  # reset path
            self.clearScreen()
            tk.Label(self.content_frame,
                    text="Fiji timed out on launch. Please locate it again.",
                    fg="red").pack(pady=5)
            self.root.update()
            self.formFijiWindow(show_form=False)

        except (RuntimeError, OSError):
            self.fiji_path = ""  # reset path
            self.clearScreen()
            tk.Label(self.content_frame,
                    text="Fiji could not be launched. Please locate it again.",
                    fg="red").pack(pady=5)
            self.root.update()
            self.formFijiWindow(show_form=False)


    def clearScreen(self):
        for widget in self.content_frame.winfo_children():
            widget.destroy()


    def formFijiWindow(self, show_form=True):
        if show_form:
            self.clearScreen()  # only clear if not showing below an error

        inner_frame = tk.Frame(self.content_frame)
        inner_frame.pack(pady=20)

        tk.Label(inner_frame, text="Fiji file Path:").pack(side="left", padx=5)
        fs_path_entry = tk.Entry(inner_frame, width=35)
        fs_path_entry.pack(side="left", padx=5)    
        
        tk.Button(self.content_frame, 
                text="Submit", 
                command=lambda: self.submitFijiDir(fs_path_entry)).pack(pady=5)


    def formROIWindow(self):
        self.clearScreen()

        tk.Label(self.content_frame, text="Layer, e.g. L1 or L2_3:").pack(padx=10, pady=5)
        self.layer_entry = tk.Entry(self.content_frame, width=20)
        self.layer_entry.insert(0, "L2_3")
        self.layer_entry.pack(padx=10, pady=5)

        tk.Label(self.content_frame, text="ROI ID, e.g. ROI_01:").pack(padx=10, pady=5)
        self.roi_entry = tk.Entry(self.content_frame, width=20)
        self.roi_entry.insert(0, "ROI_01")
        self.roi_entry.pack(padx=10, pady=5)

        tk.Label(self.content_frame, text="Region, optional, e.g. ACC:").pack(padx=10, pady=5)
        self.region_entry = tk.Entry(self.content_frame, width=20)
        self.region_entry.insert(0, "ACC")
        self.region_entry.pack(padx=10, pady=5)

        tk.Button(self.content_frame, text="OK", width=8,
                command=self.submitROI).pack(pady=10)


    def formStepDoneWindow(self, text: str):
        # clear screen before forming window
        self.clearScreen()

        tk.Label(self.content_frame, 
            text=text, 
            font=("Arial", 12)).pack(pady=20)
        self.root.update()


    def formWindow1(self):
        # clear screen before forming window
        self.clearScreen()

        inner_frame = tk.Frame(self.content_frame)
        inner_frame.pack(pady=20)

        tk.Label(inner_frame, text="Output Folder Path:").pack(side="left", padx=5)
        fs_path_entry = tk.Entry(inner_frame, width=35)
        fs_path_entry.pack(side="left", padx=5)    
        
        tk.Button(self.content_frame, 
                  text="Submit", 
                  command=lambda: self.submitOutDir(fs_path_entry)).pack(pady=5)
        

    def formWindow2(self):
        # clear screen before forming window
        self.clearScreen()

        inner_frame = tk.Frame(self.content_frame)
        inner_frame.pack(pady=20)

        tk.Label(inner_frame, text="Full Stack Img Dir:").pack(side="left", padx=5)
        fs_path_entry = tk.Entry(inner_frame, width=35)
        fs_path_entry.pack(side="left", padx=5)    
        
        tk.Button(self.content_frame, 
                  text="Submit", 
                  command=lambda: self.submitFSDir(fs_path_entry)).pack(pady=5)


    def processNextFile(self):

        # check if all files have already been ran
        if self.cur_index >= len(self.fs_path_list):
            self.pipelineComplete()
            return
        
        # grab the current unprocessed file
        current_file = self.fs_path_list[self.cur_index]

        # create parent output dir for current file
        cur_out_dir = current_file.parent.parent / (current_file.stem + "_outputs") 
        cur_out_dir.mkdir(parents=True, exist_ok=True)
        self.out_dir = self.toFijiPath(str(cur_out_dir))
        
        tk.Label(self.content_frame,
                text=f"Processing {current_file.name} ({self.cur_index + 1} of {len(self.fs_path_list)})",
                font=("Arial", 12)).pack(pady=20)
        self.root.update()
    
        
        # run the pipeline on the current file
        self.runIJMScript(self.macro_paths[0].as_posix(), 
                          run_text=f"Running 01: {self.macro_paths[0].name}",
                          arg = f"{self.fs_path_list[self.cur_index]};{self.out_dir}",
                          done_text="Step 01 Ran",
                          headless=self.headless) # step 1
        
        self.runIJMScript(self.macro_paths[1].as_posix(), 
                          arg = f"{self.fs_path_list[self.cur_index]};{self.out_dir}",
                          run_text=f"Running 02: {self.macro_paths[1].name}",
                          done_text="Step 02 Ran",
                          headless=False) # step 2
        
        # prompt for ROIs and initiate next steps when done
        self.formROIWindow()


    def pipelineComplete(self):
        tk.Label(self.content_frame,
                text="Pipeline complete!",
                font=("Arial", 12)).pack(pady=20)


    def resolveFijiPath(self, path):
        p = Path(path)
        if p.suffix == ".app":
            # try common executable locations inside the bundle
            for candidate in [
                p / "Contents/MacOS/ImageJ-macosx-arm64",
                p / "Contents/MacOS/ImageJ-macosx",
            ]:
                if candidate.is_file():
                    return str(candidate)
        return path


    def runIJMScript(self, macro_path: str, arg: str, run_text: str, done_text: str, headless=True):
        tk.Label(self.content_frame, 
                 text=run_text, 
                 font=("Arial", 12)).pack(pady=20)
        self.root.update()

        if headless:
            cmd = [self.fiji_path, 
                    "--headless", 
                    "-macro", macro_path,
                    arg
                    ]
        else:
            cmd = [self.fiji_path, 
                    "-macro", macro_path,
                    arg
                    ]
            

        print("Running:", cmd)
        result = subprocess.run(cmd, capture_output=False, text=True)
        print("STDOUT:", result.stdout)
        print("STDERR:", result.stderr)
        print("Return code:", result.returncode)

        self.clearScreen()
        self.formStepDoneWindow(done_text)


    def runPythonScript(self, macro_path: str, run_text: str, done_text: str):
        tk.Label(self.content_frame, 
                 text=run_text, 
                 font=("Arial", 12)).pack(pady=20)
        self.root.update()

        cmd = ["python", 
               macro_path,
               self.out_dir
                ]
            

        print("Running:", cmd)
        result = subprocess.run(cmd, capture_output=True, text=True)
        print("STDOUT:", result.stdout)
        print("STDERR:", result.stderr)
        print("Return code:", result.returncode)

        self.clearScreen()
        self.formStepDoneWindow(done_text)

        pass


    def runPostManualSteps(self):
        self.runIJMScript(self.macro_paths[2].as_posix(), 
                    run_text=f"Running 03: {self.macro_paths[2].name}",
                    arg = ";".join([
                        str(self.fs_path_list[self.cur_index]),
                        self.out_dir,
                        self.roi_data["layer"],
                        self.roi_data["roi_id"],
                        self.roi_data["region"]
                    ]),
                    done_text="Step 03 Ran",
                    headless=False) # step 3
        
        self.runIJMScript(self.macro_paths[3].as_posix(), 
                          run_text=f"Running 04: {self.macro_paths[3].name}",
                          arg = f"{self.fs_path_list[self.cur_index]};{self.out_dir}",
                          done_text="Step 04 Ran",
                          headless=self.headless) # step 4
        
        self.runIJMScript(self.macro_paths[4].as_posix(), 
                          run_text=f"Running 05: {self.macro_paths[4].name}",
                          arg = ";".join([
                                str(self.fs_path_list[self.cur_index]),
                                self.out_dir,
                                self.roi_data["layer"],
                                self.roi_data["roi_id"],
                                self.roi_data["region"]
                            ]),
                          done_text=f"Step 05 Ran",
                          headless=self.headless) # step 5

        
        # run python scripts
        for f in self.macro_paths[5:]:
            if f.suffix == ".py":
                self.runPythonScript(f,
                                    run_text=f"Running {f.name[:2]}: {f.name}",
                                    done_text=f"Step {f.name[:2]} Ran",
                )


        # prepare for next tif file
        self.cur_index += 1
        self.clearScreen()
        self.processNextFile()


    def submitFijiDir(self, entry: str):
        # get the user input and strip white space and quots
        user_input = entry.get().strip().strip('"').strip("'")

        user_input = self.resolveFijiPath(user_input)

        data_dict = {}
        # save the verified path to app data file for future sessions
        data_dict["fiji_path"] = {"value": user_input}
        with open(self._APP_DATA, 'w', encoding="utf-8", newline='') as ap:
            
            writer = csv.DictWriter(ap, fieldnames=["id", "value"], delimiter='\t')
            writer.writeheader()

            for key, val in data_dict.items():
                writer.writerow({"id": key, **val})

        self.fiji_path = user_input
        self.checkFiji()


    def submitFSDir(self, entry: str):
        user_input = entry.get().strip().strip('"').strip("'")  # strip whitespace and quotes
        user_input = self.toFijiPath(user_input)

        if not Path(user_input).is_dir():
            # show inline error rather than crashing
            tk.Label(self.content_frame, 
                    text=f"Dirextory Path: {user_input} not found. Please check and try again.", 
                    fg="red").pack()
            return
        
        # ensure string has trailing slash for compatibility with ijm scripts
        if not str(user_input).endswith("/"):
            user_input = str(user_input) + "/"

        # grab all tif files in dir
        files = list(Path(user_input).glob("*.tif"))

        if len(files) == 0:
            tk.Label(self.content_frame, 
                        text=f"No tif files found in: {user_input} Please check and try again.", 
                        fg="red").pack()
            return

        self.fs_path_list = files
        self.cur_index = 0 
        self.processNextFile()


    def submitOutDir(self, entry: str):
        user_input = entry.get().strip().strip('"').strip("'")  # strip whitespace and quotes
        user_input = self.toFijiPath(user_input)

        if not Path(user_input).is_dir():
            # show inline error rather than crashing
            tk.Label(self.content_frame, 
                    text=f"Directory Path: {user_input} not found. Please check and try again.", 
                    fg="red").pack()
            return

        self.out_dir = user_input
        self.formWindow2()


    def submitROI(self):
        self.roi_data = {
            "layer": self.layer_entry.get().strip(),
            "roi_id": self.roi_entry.get().strip(),
            "region": self.region_entry.get().strip()
        }
        self.clearScreen()

        # resume pipeline
        self.runPostManualSteps()


    def toFijiPath(self, path: str):

        # fiji should be able to handle either or fine, but better to convert for safety
        path = str(path).replace("\\", "/")

        # ensure string has trailing slash for compatibility with ijm scripts
        if not str(path).endswith("/"):
            path = str(path) + "/"

        return path


def main():
    parser = argparse.ArgumentParser(description="Synapse Analysis Pipeline")
    parser.add_argument("--debug", 
                        action="store_true", 
                        help="Run in debug mode — Fiji windows stay open, verbose output")
    args = parser.parse_args()

    root = tk.Tk()
    app = App(root, debug=args.debug)
    root.mainloop()

if __name__ == "__main__":
    main()