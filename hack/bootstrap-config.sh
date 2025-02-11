#!/usr/bin/env bash
# Copyright (c) 2021 SAP SE or an SAP affiliate company. All rights reserved. This file is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

cd "$(git rev-parse --show-toplevel)"

kubeconfig="${KUBECONFIG:-}"
if [ -z "$kubeconfig" ] ; then
  echo "Error: no kubeconfig given. Please set KUBECONFIG."
  exit 1
fi

docker run --rm -w /etc/ci-infra -v $PWD/config:/etc/ci-infra/config \
  -v "$kubeconfig":/etc/kubeconfig \
  gcr.io/k8s-prow/config-bootstrapper:v20211126-48cb2fc883 \
  --kubeconfig=/etc/kubeconfig \
  --source-path=.  \
  --config-path=config/prow/config.yaml \
  --plugin-config=config/prow/plugins.yaml \
  --job-config-path=config/jobs \
  --dry-run=false \
  $@
