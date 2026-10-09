#!/bin/bash
#PBS -N fetch_cmap
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev_transfer"
#PBS -A VERF-DEV
#PBS -l walltime=02:00:00
#PBS -l place=shared,select=1:ncpus=1:mem=18GB
#PBS -l debug=true

cd "${PBS_O_WORKDIR:-$PWD}"

export CMAP_VERSION="enh"                                     # Optional: switch to std
export OUT_DIR="SFS_VERIF_DATA/verifying_truths/CMAP/monthly" # Optional path override

bash fetch_cmap.sh 199101 202609




