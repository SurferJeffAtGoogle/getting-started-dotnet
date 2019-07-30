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

# Build the application locally.
dotnet publish -c Release

$binPath = (Get-Item .\bin\Release\netcoreapp2.2\publish).FullName
$computerName = $gceIpAddress # "https://$gceIpAddress/msdeploy.axd?site=Default%20Web%20Site"
$userName = Read-Host -Prompt "Enter user name for ${gceIpAddress}"
$password = Read-Host -Prompt "Enter password for ${gceIpAddress}\${userName}" -AsSecureString | ConvertFrom-SecureString
msdeploy -verb:sync -source:contentPath=`"$binPath`" `
    -dest:auto,ComputerName=`"$computerName`",UserName=`"$userName`",Password=`"$password`",AuthType=Basic


