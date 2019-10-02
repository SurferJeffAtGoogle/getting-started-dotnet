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

# Create an instance template based on the aspnet instance already running.
gcloud compute instance-groups managed create aspnet-group `
    --base-instance-name aspnet-group `
    --size 2 `
    --template aspnet-group-tmpl `
    --zone=us-central1-f
