#!/usr/bin/env bash

kubectl label node master-node registry=enabled
kubectl apply -f registry.yml
kubectl -n local-registry get pods -o wide
