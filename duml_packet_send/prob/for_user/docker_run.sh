#!/bin/bash
docker build -t packet-2 .
docker run -dp 9003:9003/udp packet-2
