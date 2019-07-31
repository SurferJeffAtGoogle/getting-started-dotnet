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

# Collect some details about the project that we'll need later.
$gceIpAddress = "104.197.30.64"

$pubxmlPath = 'Properties\PublishProfiles\ComputeEngine.pubxml'
$pubxml = [xml] (Get-Content $pubxmlPath)

if ([String]::IsNullOrWhiteSpace($pubxml.Project.PropertyGroup.MSDeployServiceURL))
{
    $pubxml.Project.PropertyGroup.MSDeployServiceURL = `
        Read-Host -Prompt "Enter your Compute Engine instance's public IP address"
    $pubxml.Project.PropertyGroup.SiteUrlToLaunchAfterPublish = `
        "http://${$pubxml.Project.PropertyGroup.MSDeployServiceURL}/"
    $writeXml = $true
}

if ([String]::IsNullOrWhiteSpace($pubxml.Project.PropertyGroup.UserName))
{
    $pubxml.Project.PropertyGroup.UserName = `
        Read-Host -Prompt "Enter username for ${$pubxml.Project.PropertyGroup.MSDeployServiceURL}"
    $writeXml = $true
}

if ($writeXml)
{
    $pubxml.Save($pubxmlPath)
}

$password = Read-Host -Prompt "Enter password for ${$pubxml.Project.PropertyGroup.MSDeployServiceURL}\${$pubxml.Project.PropertyGroup.UserName}" -AsSecureString | ConvertFrom-SecureString

# Build the application locally.
dotnet publish -c Release /p:PublishProfile=Properties\PublishProfiles\ComputeEngine.pubxml /p:Password=$password
