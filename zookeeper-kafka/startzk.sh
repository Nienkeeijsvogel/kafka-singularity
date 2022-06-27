#!/bin/bash
singularity run --writable-tmpfs --env ZOOKEEPER_CLIENT_PORT=12181 --hostname zookeeper-1 docker://confluentinc/cp-zookeeper:3.3.0-1
