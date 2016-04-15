﻿# Copyright(c) 2016 Google Inc.
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


##############################################################################
#.SYNOPSIS
# Adds a setting to a Web.config configuration.
#
#.PARAMETER Config
# The root xml object from a Web.config or App.config file.
#
#.PARAMETER Key
# The name of the key to set.
#
#.PARAMETER Value
# The value to set.
#
#.EXAMPLE
# Add-Setting $config 'GoogleCloudSamples:ProjectId' $env:GoogleCloudSamples:ProjectId
##############################################################################
function Add-Setting($Config, [string]$Key, [string]$Value) {
    $x = Select-Xml -Xml $Config.Node -XPath "appSettings/add[@key='$Key']"
    if ($x) {
        $x.Node.value = $Value
    }
}

##############################################################################
#.SYNOPSIS
# Updates an App.config or Web.config file, pulling values from environment
# variables.
#
# .DESCRIPTION
# Don't forget to 'git checkout -- Web.config' before 'git commit'ing!
#
#.PARAMETER BookStore
# Where shall the books be stored?  Valid strings are 'mysql' and 'datastore'.
# Defaults to pulling the value from an environment variable.
#
#.PARAMETER ConfigPath
# Where is the Web.config file?
#
#.EXAMPLE
# Update-Config mysql
##############################################################################
function Update-Config([string]$BookStore = $null, [string]$ConfigPath=".\Web.config") {        
    $config = Select-Xml -Path $ConfigPath -XPath configuration
    if ($BookStore) {
        Add-Setting $config 'GoogleCloudSamples:BookStore' $BookStore
    } else {
        Add-Setting $config 'GoogleCloudSamples:BookStore' $env:GoogleCloudSamples:BookStore
    }
    Add-Setting $config 'GoogleCloudSamples:ProjectId' $env:GoogleCloudSamples:ProjectId
    Add-Setting $config 'GoogleCloudSamples:BucketName' $env:GoogleCloudSamples:BucketName
    Add-Setting $config 'GoogleCloudSamples:AuthClientId' $env:GoogleCloudSamples:AuthClientId
    Add-Setting $config 'GoogleCloudSamples:AuthClientSecret' $env:GoogleCloudSamples:AuthClientSecret
    $connectionString = Select-Xml -Xml $config.Node -XPath "connectionStrings/add[@name='LocalMySqlServer']"
    if ($connectionString) {
        if ($env:GoogleCloudSamples:ConnectionString) {
            $connectionString.Node.connectionString = $env:GoogleCloudSamples:ConnectionString;        
        } elseif ($env:Data:MySql:ConnectionString) {
            # TODO: Stop checking this old environment variable name when we've
            # updated all the scripts.
            $connectionString.Node.connectionString = $env:Data:MySql:ConnectionString;        
        }
    }
    $config.Node.OwnerDocument.Save($config.Path);
}

##############################################################################
#.SYNOPSIS
# Recursively find all the files that match a mask.
#
#.PARAMETER Path
# Start searching from where?  Defaults to the current directory.
#
#.PARAMETER Masks
# A list of masks to match against the files.
#
#.PARAMETER MaxDepth
# How deep should we look into subdirectories?  Default is no limit.
#
#.EXAMPLE
# Find-Files -Masks *.txt
##############################################################################
function Find-Files($Path = $null, [string[]]$Masks = '*', $MaxDepth = -1, $Depth=0)
{
    foreach ($item in Get-ChildItem $Path | Sort-Object -Property Mode,Name)
    {
        if ($Masks | Where {$item -like $_})
        {
            $item
        }
        if ($MaxDepth -ge 0 -and $Depth -ge $MaxDepth)
        {
            # We have reached the max depth.  Do not recurse.
        }
        elseif (Test-Path $item.FullName -PathType Container)
        {
            Find-Files $item.FullName $Masks $MaxDepth ($Depth + 1)
        }
    }
}

##############################################################################
#.SYNOPSIS
# Look for a matching file in this directory and parent directories.
#
#.PARAMETER Masks
# A list of masks to match against the files.
#
#.EXAMPLE
# UpFind-File *.txt
##############################################################################
function UpFind-File([string[]]$Masks = '*')
{    
    $dir = Get-Item .
    while (1)
    {
        foreach ($item in Get-ChildItem $dir | Sort-Object -Property Mode,Name)
        {
            if ($Masks | Where {$item -like $_})
            {
                return $item
            }
        }
        if (!$dir.parent)
        {
            return
        }
        $dir = Get-Item $dir.parent.FullName
    }    
}


##############################################################################
#.SYNOPSIS
# Runs powershell scripts and prints a summary of successes and errors.
#
#.INPUTS
# Powershell scripts.
#
#.EXAMPLE
# Find-Files -Masks *tests.ps1 | Run-TestScripts
##############################################################################
function Run-TestScripts 
{
    $rootDir = (pwd).Path
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

##############################################################################
#.SYNOPSIS
# Builds and runs .NET core web application in the current directory.
# Runs test using casperjs.
#
#.INPUTS
# Javascript test files to pass to casperjs.
##############################################################################
filter BuildAndRun-CoreTest {
    dnvm use 1.0.0-rc1-update1 -r clr
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
#.SYNOPSIS
# Runs code formatter on a project or solution.
#
#.INPUTS
# .sln and .csproj files.
#
#.EXAMPLE
# dir *.sln | Format-Code
##############################################################################
filter Format-Code {
    codeformatter.exe /rule:BraceNewLine /rule:ExplicitThis /rule:ExplicitVisibility /rule:FieldNames /rule:FormatDocument /rule:ReadonlyFields /rule:UsingLocation /nocopyright $_.FullName
    if ($LASTEXITCODE) {
        throw "codeformatter failed with exit code $LASTEXITCODE."
    }
}

##############################################################################
#.SYNOPSIS
# Runs code formatter on a project or solution.
#
#.DESCRIPTION Throws an exception if code formatter actually changed something.
#
#.INPUTS
# .sln and .csproj files.
#
#.EXAMPLE
# dir *.sln | Lint-Project
##############################################################################
filter Lint-Project {
    $_.FullName | Format-Code
    # If git reports a diff, codeformatter changed something, and that's bad.
    $diff = git diff
    if ($diff) {
        $diff
        throw "Lint failed for $_"
    }
}

##############################################################################
#.SYNOPSIS
# Builds the .sln in the current working directory.
#
#.DESCRIPTION
# Invokes nuget first, then msbuild.  Throws an exception if 
##############################################################################
function BuildSolution {
    nuget restore
    if ($LASTEXITCODE) {
        throw "Nuget failed with error code $LASTEXITCODE"
    }
    msbuild /p:Configuration=Debug
    if ($LASTEXITCODE) {
        throw "Msbuild failed with error code $LASTEXITCODE"
    }
}
