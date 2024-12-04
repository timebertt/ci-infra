#!/bin/bash
# SPDX-FileCopyrightText: 2024 SAP SE or an SAP affiliate company and Gardener contributors
#
# SPDX-License-Identifier: Apache-2.0


# Prow deploy script
# Based on https://github.com/kubernetes/test-infra/blob/master/prow/deploy.sh

set -o errexit
set -o nounset
set -o pipefail

# See https://misc.flogisoft.com/bash/tip_colors_and_formatting

color-green() { # Green
  echo -e "\x1B[1;32m${*}\x1B[0m"
}

color-step() { # Yellow
  echo -e "\x1B[1;33m${*}\x1B[0m"
}

color-context() { # Bold blue
  echo -e "\x1B[1;34m${*}\x1B[0m"
}

color-missing() { # Yellow
  echo -e "\x1B[1;33m${*}\x1B[0m"
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if ! [ -x "$(command -v "kubectl")" ]; then
  echo "ERROR: kubectl is not present. Exiting..."
  exit 1
fi

ensure-context() {
  local context=$1
  echo -n " $(color-context "$context")"
  kubectl config get-contexts "$context" &> /dev/null && return 0
  echo ": $(color-missing MISSING), stopping..."
  return 1
}

# create temporary kubeconfig copy that we can modify (switch contexts)
# in the deploy job pod, the kubeconfig is mounted from a secret and secret mounts are read-only filesystems
temp_kubeconfig=$(mktemp)
cleanup-kubeconfig() {
  rm -f "$temp_kubeconfig"
}
trap cleanup-kubeconfig EXIT

kubectl config view --raw > "$temp_kubeconfig"
export KUBECONFIG="$temp_kubeconfig"

echo -n "$(color-step "Ensuring contexts exist"):"
ensure-context gardener-prow-trusted
ensure-context gardener-prow-build
echo " $(color-green "done")"

echo "$(color-step "Deploying prow components to gardener-prow-trusted cluster...")"
kubectl config use-context gardener-prow-trusted
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster"
echo "$(color-green "done")"

echo "$(color-step "Deploying ingress-nginx components to gardener-prow-trusted cluster...")"
kubectl config use-context gardener-prow-trusted
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/ingress-nginx"
kubectl wait --for=condition=available deployment -l app.kubernetes.io/component=controller -n ingress-nginx --timeout 2m
echo "$(color-green "done")"

echo "$(color-step "Deploying oauth2-proxy components to gardener-prow-trusted cluster...")"
kubectl config use-context gardener-prow-trusted
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/oauth2-proxy"
echo "$(color-green "done")"

echo "$(color-step "Deploying monitoring components to gardener-prow-trusted cluster...")"
kubectl config use-context gardener-prow-trusted
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/monitoring/trusted-cluster"
echo "$(color-green "done")"

echo "$(color-step "Deploying ingress-nginx components to gardener-prow-build cluster...")"
kubectl config use-context gardener-prow-build
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/ingress-nginx"
kubectl wait --for=condition=available deployment -l app.kubernetes.io/component=controller -n ingress-nginx --timeout 2m
echo "$(color-green "done")"

echo "$(color-step "Deploying monitoring components to gardener-prow-build cluster...")"
kubectl config use-context gardener-prow-build
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/monitoring/build-cluster"
echo "$(color-green "done")"

echo "$(color-step "Deploying athens components to gardener-prow-trusted cluster...")"
kubectl config use-context gardener-prow-trusted
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/athens"
echo "$(color-green "done")"

echo "$(color-step "Deploying athens components to gardener-prow-build cluster...")"
kubectl config use-context gardener-prow-build
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/athens"
echo "$(color-green "done")"

echo "$(color-step "Deploying coredns components to gardener-prow-build cluster...")"
kubectl config use-context gardener-prow-build
kubectl apply --server-side=true --force-conflicts -k "$SCRIPT_DIR/cluster/coredns"
echo "$(color-green "done")"

echo "$(color-green "SUCCESS")"
