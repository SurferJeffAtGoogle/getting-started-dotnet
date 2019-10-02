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


# [START getting_started_create_template]
# Create a new disk image based on the running aspnet server.
"Creating disk image from $($sourceInstance.disks.source)..." | Write-Host
gcloud compute images create aspnet-group-image `
  --source-disk $sourceInstance.disks.source `
  --force

# Create an instance template based on the aspnet instance already running.

gcloud compute instance-templates create aspnet-group-tmpl `
    --no-address `
    --boot-disk-auto-delete `
    --image aspnet-group-image `
    --tags "aspnet-group,$($sourceInstance.tags.items -join ',')" `
    --machine-type "$($sourceInstance.machineType.split('/')[-1])" `
    --service-account "$($sourceInstance.serviceAccounts.email)" `
    --scopes "$($sourceInstance.serviceAccounts.scopes -join ',')"
# [END getting_started_create_template]

# [START getting_started_create_group]
# Create an instance group.
gcloud compute instance-groups managed create aspnet-group `
  --base-instance-name aspnet-group `
  --size 2 `
  --template aspnet-group-tmpl `
  --zone $sourceInstance.zone
# [END getting_started_create_group]

# [START getting_started_create_health_check]
# Create a health check.
gcloud compute http-health-checks create root-health-check `
  --request-path / `
  --port 80
# [END getting_started_create_health_check]

# [START getting_started_create_backend_service]
gcloud compute backend-services create aspnet-service `
  --http-health-checks root-health-check --global
# [END getting_started_create_backend_service]

# [START getting_started_add_backend_service]
gcloud compute backend-services add-backend aspnet-service `
    --instance-group aspnet-group `
    --instance-group-zone $sourceInstance.zone `
    --global
# [END getting_started_add_backend_service]

# Create a URL map and web Proxy. The URL map will send all requests to the
# backend service defined above.

# [START getting_started_create_url_map]
gcloud compute url-maps create aspnet-map `
    --default-service aspnet-service
# [END getting_started_create_url_map]

# [START getting_started_create_http_proxy]
gcloud compute target-http-proxies create aspnet-proxy `
    --url-map aspnet-map
# [END getting_started_create_http_proxy]

# Create a global forwarding rule to send all traffic to our proxy

# [START getting_started_create_forwarding_rule]
gcloud compute forwarding-rules create aspnet-http-rule `
    --global `
    --target-http-proxy aspnet-proxy `
    --ports 80
# [END getting_started_create_forwarding_rule]