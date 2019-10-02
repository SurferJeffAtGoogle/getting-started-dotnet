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
Cleans up all resources created by other scripts.
#>

$sourceInstance = gcloud compute instances list --filter='name:aspnet-*' `
    --sort-by ~NAME --limit 1 --format json | convertfrom-json

gcloud -q compute forwarding-rules delete aspnet-http-rule --global
gcloud -q compute target-http-proxies delete aspnet-proxy
gcloud -q compute url-maps delete aspnet-map
gcloud -q compute backend-services delete aspnet-service --global

gcloud -q compute http-health-checks delete root-health-check
gcloud -q compute instance-groups managed delete aspnet-group `
  --zone $sourceInstance.zone
gcloud -q compute instance-templates delete aspnet-group-tmpl
gcloud -q compute images delete aspnet-group-image
