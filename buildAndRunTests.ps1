﻿# Copyright(c) 2015 Google Inc.
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

# Recursively retrieve all the files in a directory that match one of the
# masks.
function GetFiles($path = $null, [string[]]$masks = '*', $maxDepth = 0, $depth=-1)
{
    foreach ($item in Get-ChildItem $path | Sort-Object -Property Mode,Name)
    {
        if ($masks | Where {$item -like $_})
        {
            $item
        }
        if ($maxDepth -ge 0 -and $depth -ge $maxDepth)
        {
            # We have reached the max depth.  Do not recurse.
        }
        elseif (Test-Path $item.FullName -PathType Container)
        {
            GetFiles $item.FullName $masks $maxDepth ($depth + 1)
        }
    }
}

function GetRootDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$rootDir = GetRootDirectory

# Run inner runTests.ps1 scripts.  Script names passed via pipe $input.
function RunTestScripts 
{
    # Keep running lists of successes and failures.
    # Array of strings: the relative path of the inner script.
    $successes = @()
    $failures = @()
    foreach ($script in $input) {
        Set-Location $script.Directory
        $relativePath = $script.FullName.Substring($rootDir.Length + 1, $script.FullName.Length - $rootDir.Length - 1)
        echo $relativePath
        # A script can fail two ways.
        # 1. Throw an exception.
        # 2. The last command it executed failed. 
        Try {
            Invoke-Expression (".\" + $script.Name)
            if ($LASTEXITCODE) {
                $failures += $relativePath
            } else {
                $successes += $relativePath
            }
        }
        Catch {
            echo  $_.Exception.Message
            $failures += $relativePath
        }
    }
    # Print a final summary.
    echo "==============================================================================="
    $successCount = $successes.Count
    echo "$successCount SUCCEEDED"
    echo $successes
    $failureCount = $failures.Count
    echo "$failureCount FAILED"
    echo $failures
    # Throw an exception to set ERRORLEVEL to 1 in the calling process.
    if ($failureCount) {
        throw "$failureCount FAILED"
    }
}

function AddSetting($config, [string]$key, [string]$value) {
    $x = Select-Xml -Xml $config.Node -XPath "appSettings/add[@key='$key']"
    if ($x) {
        $x.Node.value = $value
    }
}

function UpdateWebConfig([string]$bookstore) {        
    $config = Select-Xml -Path .\Web.config -XPath configuration
    AddSetting $config 'GoogleCloudSamples:BookStore' $bookstore
    AddSetting $config 'GoogleCloudSamples:ProjectId' $env:GoogleCloudSamples:ProjectId
    AddSetting $config 'GoogleCloudSamples:BucketName' $env:GoogleCloudSamples:BucketName
    AddSetting $config 'GoogleCloudSamples:AuthClientId' $env:GoogleCloudSamples:AuthClientId
    AddSetting $config 'GoogleCloudSamples:AuthClientSecret' $env:GoogleCloudSamples:AuthClientSecret
    $connectionString = Select-Xml -Xml $config.Node -XPath "connectionStrings/add[@name='LocalMySqlServer']"
    if ($env:Data:MySql:ConnectionString -and $connectionString) {
        $connectionString.Node.connectionString = $env:Data:MySql:ConnectionString;        
    }
    $config.Node.OwnerDocument.Save($config.Path);
}

##############################################################################
# core tests.

dnvm use 1.0.0-rc1-update1 -r clr

# Given a *test.js file, build the project and run the test on localhost.
filter BuildAndRunLocalTest {
    dnu restore
    dnu build
    $webProcess = Start-Process dnx web -PassThru
    Try
    {
        Start-Sleep -Seconds 4  # Wait for web process to start up.
        casperjs $_ http://localhost:5000
    }
    Finally
    {
        Stop-Process $webProcess
    }
}

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

function BuildSolution() {
    nuget restore
    if ($LASTEXITCODE) {
        throw "Nuget failed with error code $LASTEXITCODE"
    }
    msbuild /p:Configuration=Debug
    if ($LASTEXITCODE) {
        throw "Msbuild failed with error code $LASTEXITCODE"
    }
}

filter RunLint {
    codeformatter.exe /rule:BraceNewLine /rule:ExplicitThis /rule:ExplicitVisibility /rule:FieldNames /rule:FormatDocument /rule:ReadonlyFields /rule:UsingLocation /nocopyright $_.FullName
    if ($LASTEXITCODE) {
        throw "codeformatter failed with exit code $LASTEXITCODE."
    }
    # If git reports a diff, codeformatter changed something, and that's bad.
    $diff = git diff
    if ($diff) {
        $diff
        throw "Lint failed for $_"
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
