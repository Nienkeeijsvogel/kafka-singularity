#!/bin/bash
singularity run --writable-tmpfs --env-file env1 --hostname zookeeper-1 docker://confluentinc/cp-zookeeper:3.3.0-1