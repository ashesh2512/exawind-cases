# step 1 checks
SPACK_MANAGER=/lustre/orion/proj-shared/cfd116/mullowne/spack-manager/
source ${SPACK_MANAGER}/start.sh
spack-start # ensure spack-manager is going
spack env activate -d $SPACK_MANAGER/environments/exawind_rocm-5.4.3
spack load exawind

# machine specific params i.e. mesh/restart/etc
aprepro_include=template_files/${SPACK_MANAGER_MACHINE}_aprepro.txt

# step 2 parse
for i in "$@"; do
    case "$1" in
        -n=*|--name=*)
            PROBNAME="${i#*=}"
            shift # past argument=value
            ;;
        -e=*|--email=*)
            EMAIL="${i#*=}"
            shift # past argument=value
            ;;
        -t=*|--tower=*)
            TOWER="${i#*=}"
            shift # past argument=value
            ;;
        -s=*|--submit=*)
            SUBMIT="${i#*=}"
            shift # past argument=value
            ;;
        --)
            shift
            break
            ;;
    esac
done

# step 3 create dirs
if [[ -z ${PROBNAME} ]]; then
  PROBNAME=$(date "+%Y%m%d")
fi
rundir="$(pwd)/run_${PROBNAME}"
mkdir -p ${rundir}

# step 4 setup run dir
echo "Setting up run dir"
cp template_files/static_files/* ${rundir}
cp template_files/${SPACK_MANAGER_MACHINE}_static_box.txt ${rundir}/static_box.txt
spack build-env trilinos aprepro -qW --include ${aprepro_include} TOWER=${TOWER} template_files/nrel5mw_nalu.yaml ${rundir}/nrel5mw_nalu.yaml
spack build-env trilinos aprepro -qW --include ${aprepro_include} TOWER=${TOWER} template_files/NRELOffshrBsline5MW_Onshore_ElastoDyn_BDoutputs.dat ${rundir}/NRELOffshrBsline5MW_Onshore_ElastoDyn_BDoutputs.dat
# getting a weird carriage on frontier in this file for some reason
sed -i 's/\r//g' ${rundir}/NRELOffshrBsline5MW_Onshore_ElastoDyn_BDoutputs.dat
spack build-env trilinos aprepro -qW --include ${aprepro_include} template_files/nrel5mw_amr.inp ${rundir}/nrel5mw_amr.inp
spack build-env trilinos aprepro -qW --include ${aprepro_include} EMAIL=${EMAIL} NAME="fsi-${PROBNAME}" template_files/slurm_sub.sh ${rundir}/slurm_sub.sh

# step 5 run openfast
echo "Compile openfast servo"
cd $(pwd)/../5MW_Baseline/ServoData/
spack build-env openfast fc -shared -fPIC -o libdiscon.so DISCON/DISCON.F90
# run standalone openfast and copy files to run directory
echo "Run openfast to start"
set -x
cd ${rundir}
spack build-env openfast openfastcpp inp.yaml

# step 6 submit job if desired
if [ -n "${SUBMIT}" ]; then
  echo "Submit job"
  sbatch slurm_sub.sh
fi
