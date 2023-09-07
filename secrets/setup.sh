# create a secret for jcnr license and root password  
kubectl apply -f ./jcnr-secrets.yaml

# add label key1=jcnr to eks worker nodes
kubectl label nodes $(kubectl get nodes -o json | jq -r .items[0].metadata.name) key1=jcnr --overwrite
