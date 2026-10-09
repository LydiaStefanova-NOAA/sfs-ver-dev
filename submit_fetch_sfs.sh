#!/bin/bash
#PBS -N fetch_sfs
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev_transfer"
#PBS -A VERF-DEV
#PBS -l walltime=02:00:00
#PBS -l place=shared,select=1:ncpus=4:mem=18GB
#PBS -l debug=true

# Change to the directory from which qsub was submitted
cd "${PBS_O_WORKDIR:-$PWD}"

MAX_JOBS=4
REFC_BASE="/NCEPDEV/emc-global/5year/Yangxing.Zheng/URSA/scratch/SFSbeta2.0_C192mx025_reforecast_Sep01_CPCICS"
FCST_BASE="/NCEPDEV/emc-global/5year/Yangxing.Zheng/WCOSS2/scratch/SFSbeta2.0_C192mx025_NRT_forecast_Sep01_CPCICS"
BASE_DIR="SFS_VERIF_DATA"

bash fetch_sfs.sh 199109 202609
