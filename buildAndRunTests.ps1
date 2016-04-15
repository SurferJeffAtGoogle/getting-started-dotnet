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

param([switch]$lint)

function GetRootDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$rootDir = GetRootDirectory

##############################################################################
# aspnet tests.
$curDir = pwd
cd (Join-Path $rootDir "aspnet")
$env:GETTING_STARTED_DOTNET = pwd
$env:APPLICATIONHOST_CONFIG =  Get-ChildItem .\applicationhost.config
cd $curDir

# Given the name of a website in our ./applicationhost.config, return its port number.
function GetPortNumber($sitename) {
    $node = Select-Xml -Path $env:APPLICATIONHOST_CONFIG `
        -XPath "/configuration/system.applicationHost/sites/site[@name='$sitename']/bindings/binding" | 
        Select-Object -ExpandProperty Node
    $chunks = $node.bindingInformation -split ':'
    $chunks[1]
}

# Run the the website, as configured in our ./applicationhost.config file.
function RunIISExpress($sitename) {
    $argList = ('/config:"' + $env:APPLICATIONHOST_CONFIG + '"'), "/site:$sitename", "/apppool:Clr4IntegratedAppPool"
    Start-Process iisexpress.exe  -ArgumentList $argList -PassThru
}

# Run the website, then run the test javascript file with casper.
# Called by inner runTests.
function RunIISExpressTest($sitename = '', $testjs = 'test.js') {
    if ($sitename -eq '') 
    {
        $sitename = (get-item -Path ".\").Name
    }
    $port = GetPortNumber $sitename
    $webProcess = RunIISExpress $sitename
    Try
    {
        Start-Sleep -Seconds 4  # Wait for web process to start up.
        casperjs $testjs http://localhost:$port
        if ($LASTEXITCODE) {
            throw "Casperjs failed with error code $LASTEXITCODE"
        }
    }
    Finally
    {
        Stop-Process $webProcess
    }
}



##############################################################################
# main
# Leave the user in the same directory as they started.
$originalDir = Get-Location
Try
{
    # First, lint everything.  If the lint fails, don't waste time running
    # tests.
    if ($lint) {
        GetFiles -masks '*.csproj' -maxDepth 2 | RunLint
    }
    # Use Where-Object to avoid infinitely recursing, because this script
    # matches the mask.
    GetFiles -masks '*runtests*.ps1' -maxDepth 2 | Where-Object FullName -ne $PSCommandPath | RunTestScripts
}
Finally
{
    Set-Location $originalDir
}
