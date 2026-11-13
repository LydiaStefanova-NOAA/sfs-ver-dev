#!/bin/bash
#PBS -N fetch_CORe
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev_transfer"
#PBS -A VERF-DEV
#PBS -l walltime=01:30:00
#PBS -l place=shared,select=1:ncpus=4:mem=18GB
#PBS -l debug=true

cd "${PBS_O_WORKDIR:-$PWD}"

source /lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/EVS/setenv.sh
#bash fetch_CORe.sh -v "HGT500 TMP850 UGRD850 VGRD850 UGRD200 VGRD200 MSLP TSKIN T2M" -s 199101 -e 202610
bash fetch_CORe.sh -v "PRSSFC" -s 199101 -e 202610
