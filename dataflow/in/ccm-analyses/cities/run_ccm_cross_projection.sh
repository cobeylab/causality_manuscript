#!/bin/sh

$PYEMBEDDING/ccm.py \
    $INPUT_FILENAME \
    $OUTPUT_FILENAME \
    -v $VARX \
    -v $VARY \
    --method projection \
    --identification-target cross \
    -dt 8 \
    -maxlag 156 \
    -lagskip 1 \
    --cores 16 \
    --overwrite-output \
    --bootstraps 100
