#!/bin/bash
sudo singularity exec --env TZ=Europe/Amsterdam singprod.sif python3 /code/producer.py
