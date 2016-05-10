#!/usr/bin/env bash
set -e

if [ $# -ne 5 ]; then
    echo "Usage: point.sh <SZ|Z> <mmaps> <secparams> <points> <nthreads>"
    exit 1
fi

if [ "$1" = "SZ" ]; then
    scheme='--sahai-zhandry'
    exts='json'
elif [ "$1" = "Z" ]; then
    scheme='--zimmerman'
    exts='acirc'
else
    echo "Error: '$1' invalid"
    exit 1
fi

for mmap in $2; do
    if [ "$mmap" != "CLT" ] && [ "$mmap" != "GGH" ]; then
        echo "Error: mmap must be either CLT or GGH"
        exit 1
    fi
done

if [ ! -d "build" ]; then
    echo "Error: build directory missing"
    echo "Are you running from the base of the repo?"
    exit 1
fi

mmaps=$2
secparams=$3
points=$4
nthreads=$5

BIN="build/bin/run-obfuscator"
DIR="obf-experiments"
CIRCUIT_DIR="$DIR/circuits"
LOG_DIR="$DIR/results"

TIME=`date +"%F__%H-%M-%S"`
mkdir -p "$LOG_DIR/point-$TIME"

echo "**************************************************************"
echo "* Running point functions: $points"
echo "* Security parameters: $secparams"
echo "* Multilinear maps: $mmaps"
echo "* Scheme: $1"
echo "**************************************************************"
echo ""

for secparam in $secparams; do
    echo "** security parameter: $secparam"
    for point in $points; do
        for ext in $exts; do
            circuit="point-$point.$ext"
            echo "**** circuit: $circuit"
            for mmap in $mmaps; do
                echo "****** multilinear map: $mmap"
                dir="$LOG_DIR/point-$TIME/$secparam/$point/$circuit/$mmap"
                mkdir -p $dir
                obf=$circuit.obf.$secparam
                eval=`sed -n 1p $CIRCUIT_DIR/$circuit | awk '{ print $3 }'`

                # obfuscate
                $BIN obf \
                     --load $CIRCUIT_DIR/$circuit \
                     --secparam $secparam \
                     --mlm $mmap \
                     $scheme --nthreads $nthreads \
                     --verbose 2> $dir/obf-time.log
                # get size of obfuscation
                du --bytes $CIRCUIT_DIR/$obf/* > $dir/obf-size.log
                # evaluate
                $BIN obf \
                     --load-obf $CIRCUIT_DIR/$obf \
                     --eval $eval \
                     --mlm $mmap \
                     $scheme \
                     --verbose 2> $dir/eval-time.log
                # cleanup
                rm -rf $CIRCUIT_DIR/$circuit.obf.$secparam
            done
        done
    done
done

zip -q -r results-$TIME.zip $LOG_DIR
