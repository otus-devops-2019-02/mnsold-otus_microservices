#!/bin/bash

case "$1" in
  start)
        sudo minikube start --kubernetes-version v1.12.0 --vm-driver none --extra-config=kubelet.resolv-conf=/run/systemd/resolve/resolv.conf --cpus 2 --memory 4096
        sudo chown -R $USER $HOME/.kube /home/mnsold/.minikube/
        ;;
  stop)
        minikube stop
        ;;

  status)
        minikube status
        ;;
  delete)
       minikube delete
       ;;
  *)
        echo "Usage: $SCRIPTNAME {start|stop|delete}" >&2
        exit 3
        ;;
esac

