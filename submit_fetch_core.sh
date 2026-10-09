#!/bin/bash
#PBS -N fetch_core
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev_transfer"
#PBS -A VERF-DEV
#PBS -l walltime=02:00:00
#PBS -l place=shared,select=1:ncpus=1:mem=18GB
#PBS -l debug=true

cd "${PBS_O_WORKDIR:-$PWD}"


bash fetch_core.sh HGT500 199101 202609




