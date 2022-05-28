#!/bin/bash
singularity build consumer:latest.sif docker-daemon://consumer:latest
singularity run --env TZ=Europe/Amsterdam consumer:latest.sif