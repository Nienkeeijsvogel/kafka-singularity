#!/bin/bash
singularity run --hostname kafka-1 --env KAFKA_ZOOKEEPER_CONNECT=localhost:12181 --env KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:19092 --writable-tmpfs docker://confluentinc/cp-kafka:4.1.2-2
