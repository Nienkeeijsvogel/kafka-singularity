#!/bin/bash
sudo singularity exec --env TZ=Europe/Amsterdam singcons.sif python3 /code/consumer.py
