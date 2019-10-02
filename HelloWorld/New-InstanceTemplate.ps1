# Copyright (c) 2019 Google LLC.
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

<#
.SYNOPSIS
Creates a compute engine instance template from aspnet-*.
#>

# Find the aspnet instance already running.
$sourceInstance = gcloud compute instances list --filter='name:aspnet-*' `
    --sort-by ~NAME --limit 1 --format json | convertfrom-json

# Create a new disk image based on the running aspnet server.
gcloud compute images create aspnet-group-image `
  --source-disk $sourceInstance.disks.source `
  --force

# Create an instance template based on the aspnet instance already running.
$scopes = $sourceInstance.serviceAccounts.scopes -join ','
$machineType = $sourceInstance.machineType.split('/')[-1]
$serviceAccount = $sourceInstance.serviceAccounts.email

gcloud compute instance-templates create aspnet-group-tmpl `
    --no-address `
    --boot-disk-auto-delete `
    --create-disk=image=aspnet-group-image,auto-delete=yes `
    --labels=aspnet=1 `
    --machine-type=$machineType `
    --service-account=$serviceAccount `
    --scopes=$scopes



