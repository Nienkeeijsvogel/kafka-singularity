#!/bin/bash
singularity build producer:latest.sif docker-daemon://producer:latest
docker image rm producer:latest
sudo singularity run --env TZ=Europe/Amsterdam producer:latest.sif