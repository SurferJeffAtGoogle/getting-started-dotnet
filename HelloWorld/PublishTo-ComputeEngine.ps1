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

$pubxmlPath = (Get-Item 'Properties\PublishProfiles\ComputeEngine.pubxml').FullName
$pubxml = [xml] (Get-Content $pubxmlPath)

$ip = $pubxml.Project.PropertyGroup.MSDeployServiceURL
if ([String]::IsNullOrWhiteSpace($ip))
{
    $ip = Read-Host -Prompt "Enter your Compute Engine instance's public IP address"
    $pubxml.Project.PropertyGroup.MSDeployServiceURL = "$ip"        
    $pubxml.Project.PropertyGroup.SiteUrlToLaunchAfterPublish = "http://$ip/"
    $writeXml = $true
}

$username = $pubxml.Project.PropertyGroup.UserName
if ([String]::IsNullOrWhiteSpace($username))
{
    $username = Read-Host -Prompt "Enter username for $ip"
    $pubxml.Project.PropertyGroup.UserName = "$username"
    $writeXml = $true
}

if ($writeXml)
{
    $pubxml.Save($pubxmlPath)
}

$password = Read-Host -Prompt "Enter password for ${ip}\$username" -AsSecureString | ConvertFrom-SecureString
$password
# Build the application locally.
dotnet publish -c Release /p:PublishProfile=Properties\PublishProfiles\ComputeEngine.pubxml /p:Password=$password
