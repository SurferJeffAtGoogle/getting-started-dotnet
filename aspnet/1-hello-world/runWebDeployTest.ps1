# Copyright(c) 2016 Google Inc.
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
Import-Module ..\..\BuildTools.psm1 -DisableNameChecking
Add-PSSnapin WDeploySnapin3.0

New-WDPublishSettings -AllowUntrusted -ComputerName 104.154.45.60 -UserId root -Password YadaYada -FileName www.publishsettings -Site "Default Web Site" -SiteUrl "http://104.154.45.60/" -AgentType WMSvc

$argList = [string[]]@(
    "-verb:sync",
    "-source:contentPath='C:\Users\Jeffrey Rennie\gitrepos\getting-started-dotnet\aspnet\1-hello-world\tmp'",
    "-dest:auto,publishSettings='C:\Users\Jeffrey Rennie\gitrepos\getting-started-dotnet\aspnet\1-hello-world\www.publishsettings'")

$proc = Start-Process msdeploy -ArgumentList $argList -Wait -NoNewWindow -RedirectStandardError stderr.txt -RedirectStandardOutput stdout.txt
Get-Content stdout.txt
$errors = Get-Content stderr.txt -Raw
if ($errors) {
    $errors | Write-Error
}
