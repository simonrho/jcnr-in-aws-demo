ssh -i ./my-ssh-key.pem ec2-user@$(kubectl get node -o json | jq -r '.items[0].status.addresses[-1].address') $@
