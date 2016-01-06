#!/bin/sh

$PYEMBEDDING/ccm.py \
    $INPUT_FILENAME \
    $OUTPUT_FILENAME \
    -v $VARX \
    -v $VARY \
    --method uniform \
    --identification-target self \
    -Emin 1 \
    -Emax 15 \
    -taumin 1 \
    -taumax 15 \
    -dt 8 \
    -maxlag 156 \
    -lagskip 1 \
    --cores 16 \
    --overwrite-output
