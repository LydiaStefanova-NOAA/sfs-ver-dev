#!/bin/bash
#PBS -N fetch_ghcncams
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev_transfer"
#PBS -A VERF-DEV
#PBS -l walltime=02:00:00
#PBS -l place=shared,select=1:ncpus=1:mem=18GB
#PBS -l debug=true

cd "${PBS_O_WORKDIR:-$PWD}"

export OUT_DIR="SFS_VERIF_DATA/verifying_truths/GHCNCAMS/monthly" # Optional path override

bash fetch_ghcncams.sh 199101 202609




