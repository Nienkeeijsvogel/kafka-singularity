#!/bin/bash
sudo singularity run --hostname kafka-1 --env-file envkafka --writable-tmpfs docker://confluentinc/cp-kafka:4.1.2-2