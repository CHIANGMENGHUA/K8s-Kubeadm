kubectl apply -f registry.yaml
docker tag batch-processing-demo:0.0.1-SNAPSHOT 192.168.56.10:32000/batch-processing-demo:0.0.1-SNAPSHOT
docker push 192.168.56.10:32000/batch-processing-demo:0.0.1-SNAPSHOT