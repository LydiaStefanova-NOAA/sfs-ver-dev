#!/bin/bash
#PBS -N make_clim_sfs
#PBS -j oe
#PBS -S /bin/bash
#PBS -q dev
#PBS -A VERF-DEV
#PBS -l walltime=02:00:00
#PBS -l place=shared,select=1:ncpus=1:mem=18GB
#PBS -l debug=true


cd "$PBS_O_WORKDIR"

export HOMEevs=/lfs/h2/emc/vpppg/noscrub/$USER/EVS
source $HOMEevs/versions/run.ver
module reset
module load prod_envir/${prod_envir_ver}
source $HOMEevs/dev/modulefiles/seasonal/seasonal_prep.sh

echo "Starting SFS Climatology Calculation at $(date)"


#python /lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/sfs-ver-dev/make_clim_CORe.py  HGT500 TMP850 UGRD850 VGRD850 UGRD200 VGRD200 MSLP TSKIN T2M
python /lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/sfs-ver-dev/make_clim_CORe.py PRES 

echo "Finished at $(date)"
