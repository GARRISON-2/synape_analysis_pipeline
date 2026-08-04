#!/bin/bash
set -e

echo "============================================"
echo "  Synapse Analysis Pipeline - Setup"
echo "============================================"
echo ""

# --------------------------------------------------
# Check for Conda
# --------------------------------------------------

if ! command -v conda &> /dev/null; then
    echo "Conda not found. Installing Miniconda..."
    echo ""

    # detect architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh"
        echo "Detected Apple Silicon (M1/M2/M3)"
    else
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh"
        echo "Detected Intel Mac"
    fi

    # download and install miniconda
    curl -sO "$MINICONDA_URL"
    bash Miniconda3-latest-*.sh -b -p "$HOME/miniconda3"
    rm Miniconda3-latest-*.sh

    # add conda to path for this session
    export PATH="$HOME/miniconda3/bin:$PATH"

    # initialise conda for future terminal sessions
    conda init zsh
    conda init bash

    echo ""
    echo "Miniconda installed successfully."
else
    echo "Conda found: $(conda --version)"
fi

echo ""

# --------------------------------------------------
# Create environment from yml
# --------------------------------------------------

ENV_NAME=$(grep "^name:" environment.yml | cut -d' ' -f2)

if conda env list | grep -q "^$ENV_NAME "; then
    echo "Environment '$ENV_NAME' already exists — updating..."
    conda env update -f environment.yml --prune
else
    echo "Creating environment '$ENV_NAME'..."
    conda env create -f environment.yml
fi

echo ""

# --------------------------------------------------
# Make main script executable
# --------------------------------------------------

chmod +x run_pipeline.py

# --------------------------------------------------
# Done
# --------------------------------------------------

echo "============================================"
echo "  Setup complete!"
echo ""
echo "  To run the pipeline:"
echo "  1. Open Terminal"
echo "  2. Run: conda activate $ENV_NAME"
echo "  3. Run: python run_pipeline.py"
echo "============================================"
echo ""