#!/bin/bash
# build-vlx.sh
# Author: Chenxi Li <chenxili@kth.se>, Ilari Korhonen <ilarik@kth.se>
# Copyright (C) 2025 KTH Royal Institute of Technology, All Rights Reserved


set -eo pipefail


CONDA_PATH="/home/ubuntu/miniconda3/bin/conda"
VLX_BRANCH="master"
ENV_DIR="/tmp/vlx"
export CONDA_PKGS_CHANNELS_ACCEPT=1

# --- Parse arguments ---
while getopts "b:e:h" current_opt; do
    case ${current_opt} in 
        h)
            echo "Usage: $0 [-h] [-b branch] [-e environment directory]"
            exit 0
            ;;
        b)
            if [[ ${OPTARG} == -* ]]; then
                echo "Error: -b requires a branch name" >&2
                exit 1
            fi
            VLX_BRANCH=${OPTARG}
            ;;
        e)
            if [[ ${OPTARG} == -* ]]; then
                echo "Error: -o requires an environment output path" >&2
                exit 1
            fi
            ENV_DIR=${OPTARG}
            ;;
        \?)
            echo "Invalid option: -${OPTARG}" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1)) 


# --- Load conda --- since conda activate was set before

mkdir -p ~/miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
rm ~/miniconda3/miniconda.sh

source ~/miniconda3/bin/activate
conda init --all
source ~/.bashrc

source "${CONDA_PATH}/bin/activate"

SRC_DIR="$(mktemp -d)/VeloxChem"

if [ ! -d "${SRC_DIR}" ]; then
    echo "Cloning VeloxChem sources..."
    git clone https://github.com/VeloxChem/VeloxChem "${SRC_DIR}"
fi

echo "Checking out branch: ${VLX_BRANCH}"
(
    cd "${SRC_DIR}"
    git fetch origin
    git checkout "${VLX_BRANCH}"
    git pull
)


if [ ! -d "${ENV_DIR}" ]; then
    echo "Creating conda environment at ${ENV_DIR}..."
    conda env create -p "${ENV_DIR}" -f "${SRC_DIR}/openblas_env.yml"
else
    echo "Updating existing conda environment at ${ENV_DIR}..."
    conda env update -p "${ENV_DIR}" -f "${SRC_DIR}/openblas_env.yml" --prune
fi

conda activate "${ENV_DIR}"

# --- Check Eigen headers ---
if [ ! -d "$CONDA_PREFIX/include/eigen3" ]; then
    echo "Error: Eigen headers not found in $CONDA_PREFIX/include/eigen3" >&2
    exit 1
fi

# --- Build and install ---
LOGFILE="${SRC_DIR}/install.log"
echo "Building VeloxChem (log: $LOGFILE)..."
(
    cd "${SRC_DIR}"
    export SKBUILD_CONFIGURE_OPTIONS="-DVLX_LA_VENDOR=OpenBLAS -DEIGEN3_INCLUDE_DIR=$CONDA_PREFIX/include/eigen3"
    VLX_NUM_BUILD_JOBS=$(( $(getconf _NPROCESSORS_ONLN) - 2 ))
    pip install --no-build-isolation -v . >"$LOGFILE" 2>&1
)
echo "VeloxChem installation completed successfully."
echo "Check $LOGFILE for build details."
