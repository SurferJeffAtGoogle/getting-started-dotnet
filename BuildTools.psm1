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
# Logical operator.
#
#.DESCRIPTION
# When anything in pipelined to the function, outputs the inputs.
# Otherwise, evaluates the script block and returns the result. 
#
#.PARAMETER ScriptBlock
# The script block to execute if $input is empty.
##############################################################################
function When-Empty($Target, $ArgList, [ScriptBlock]$ScriptBlock) {
    if ($Target) {
        @($Target) + $ArgList
    } elseif ($ArgList) {
        $ArgList
    } else {
        &$ScriptBlock
    }
}

##############################################################################
#.SYNOPSIS
# Finds all the Web.config files in subdirectories.
#
##############################################################################
filter Get-Config ($Target, $ArgList, $Mask="Web.config") {
    When-Empty $Target $ArgList {Find-Files -Masks $Mask} | Resolve-Path -Relative
}

##############################################################################
#.SYNOPSIS
# Updates Web.config files, pulling values from environment variables.
#
#.DESCRIPTION
# Don't forget to Revert-Config or Unstage-Config before 'git commit'ing!
#
#.PARAMETER Yes
# Never ask the user if they want to overwrite a modified Web.config.  Just
# overwrite it.
#
#.INPUTS
# Paths to Web.config.  If empty, recursively searches directories for
# Web.config files.
#
#.EXAMPLE
# Update-Config mysql
##############################################################################
filter Update-Config ([switch]$Yes) {        
    $configs = Get-Config $_ $args
    foreach($configPath in $configs) {
        if (-not $Yes -and (git status -s $configPath)) {
            do {
                $reply = Read-Host "$configPath is modified.  Overwrite? [Y]es, [N]o, Yes to [A]ll"
            } until ("y", "n", "a" -contains $reply)
            if ("n" -eq $reply) { continue }
            if ("a" -eq $reply) { $Yes = $true }
        }
        $config = Select-Xml -Path $configPath -XPath configuration
        Add-Setting $config 'GoogleCloudSamples:BookStore' $env:GoogleCloudSamples:BookStore
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
        $config.Path
    }
}

filter Set-Bookstore($BookStore) {
    $configs = Get-Config $_ $args
    foreach($configPath in $configs) {
        $config = Select-Xml -Path $configPath -XPath configuration
        Add-Setting $config 'GoogleCloudSamples:BookStore' $BookStore
        $config.Node.OwnerDocument.Save($config.Path)
    }
}

##############################################################################
#.SYNOPSIS
# Reverts Web.config files.
#
#.DESCRIPTION
# git must be in the current PATH.
#
#.INPUTS
# Paths to Web.config.  If empty, recursively searches directories for
# Web.config files.
##############################################################################
filter Revert-Config {
    $configs = Get-Config $_ $args
    $silent = git reset HEAD $configs
    git checkout -- $configs
}

##############################################################################
#.SYNOPSIS
# Unstages Web.config files.
#
#.DESCRIPTION
# git must be in the current PATH.
#
#.INPUTS
# Paths to Web.config.  If empty, recursively searches directories for
# Web.config files.
##############################################################################
filter Unstage-Config {
    $configs = Get-Config $_ $args
    git reset HEAD $configs
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
#.PARAMETER AntiMasks
# Stop recursing when we reach a directory with a matching name.
#
#.EXAMPLE
# Find-Files -Masks *.txt
##############################################################################
function Find-Files($Path = $null, [string[]]$Masks = '*', $MaxDepth = -1,
    $Depth=0, [string[]]$AntiMasks = @('bin', 'obj', 'packages', '.git'))
{
    foreach ($item in Get-ChildItem $Path | Sort-Object -Property Mode,Name)
    {
        if ($Masks | Where {$item -like $_})
        {
            $item.FullName
        }
        if ($AntiMasks | Where {$item -like $_})
        {
            # Do not recurse.
        }
        elseif ($MaxDepth -ge 0 -and $Depth -ge $MaxDepth)
        {
            # We have reached the max depth.  Do not recurse.
        }
        elseif (Test-Path $item.FullName -PathType Container)
        {
            Find-Files $item.FullName $Masks $MaxDepth ($Depth + 1) $AntiMasks
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
                return $item.FullName
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
# Run-Tests
##############################################################################
function Run-TestScripts
{
    $scripts = When-Empty -ArgList ($input + $args) -ScriptBlock { Find-Files -Masks '*runtests*.ps1' } | Get-Item
    $rootDir = pwd
    # Keep running lists of successes and failures.
    # Array of strings: the relative path of the inner script.
    $successes = @()
    $failures = @()
    $separator = $null
    foreach ($script in $scripts) {
        $relativePath = Resolve-Path -Relative $script.FullName
        echo $separator
        $separator = "-" * 79
        echo $relativePath
        Set-Location $script.Directory
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
        Finally {
            Set-Location $rootDir
        }
    }
    # Print a final summary.
    echo ("=" * 79)
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
# Format-Code
##############################################################################
filter Format-Code {
    $projects = When-Empty $_ $args { Find-Files -Masks *.csproj }
    foreach ($project in $projects) {
        codeformatter.exe /rule:BraceNewLine /rule:ExplicitThis /rule:ExplicitVisibility /rule:FieldNames /rule:FormatDocument /rule:ReadonlyFields /rule:UsingLocation /nocopyright $project
        if ($LASTEXITCODE) {
            $project.FullName
            throw "codeformatter failed with exit code $LASTEXITCODE."
        }
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
# Lint-Project
##############################################################################
filter Lint-Code {
    $projects = When-Empty $_ $args { Find-Files -Masks *.csproj }
    foreach ($project in $projects) {
        @($project) | Format-Code
        # If git reports a diff, codeformatter changed something, and that's bad.
        $diff = git diff
        if ($diff) {
            $diff
            throw "Lint failed for $_"
        }
    }
}

##############################################################################
#.SYNOPSIS
# Builds the .sln in the current working directory.
#
#.DESCRIPTION
# Invokes nuget first, then msbuild.  Throws an exception if nuget or the
# build fails.
##############################################################################
function Build-Solution($solution) {
    nuget restore $solution
    if ($LASTEXITCODE) {
        throw "Nuget failed with error code $LASTEXITCODE"
    }
    msbuild /p:Configuration=Debug $solution
    if ($LASTEXITCODE) {
        throw "Msbuild failed with error code $LASTEXITCODE"
    }
}

##############################################################################
#.SYNOPSIS
# Gets the port number for an IISExpress web site.
#
#.PARAMETER SiteName
# The name of the website, as listed in applicationhost.config
#
#.PARAMETER ApplicationhostConfig
# The path to applicationhost.config.
#
#.OUTPUTS
# The port number where the web site is specified to run.
##############################################################################
function Get-PortNumber($SiteName, $ApplicationhostConfig) {
    $node = Select-Xml -Path $ApplicationhostConfig `
        -XPath "/configuration/system.applicationHost/sites/site[@name='$SiteName']/bindings/binding" | 
        Select-Object -ExpandProperty Node
    $chunks = $node.bindingInformation -split ':'
    $chunks[1]
}

##############################################################################
#.SYNOPSIS
# Runs IISExpress for a web site.
#
#.PARAMETER SiteName
# The name of the website, as listed in applicationhost.config
#
#.PARAMETER ApplicationhostConfig
# The path to applicationhost.config.
#
#.OUTPUTS
# The process object
##############################################################################
function Run-IISExpress($SiteName, $ApplicationhostConfig) {
    if (!$SiteName) {
        $SiteName = (get-item -Path ".\").Name
    }
    if (!$ApplicationhostConfig) {
        $ApplicationhostConfig = UpFind-File 'applicationhost.config'
    }
    # Applicationhost.config expects the environment variable
    # GETTING_STARTED_DOTNET to point to the same directory containing
    # applicationhost.config.
    $env:GETTING_STARTED_DOTNET = (Get-Item $ApplicationhostConfig).DirectoryName
    $argList = ('/config:"' + $ApplicationhostConfig + '"'), "/site:$SiteName", "/apppool:Clr4IntegratedAppPool"
    Start-Process iisexpress.exe  -ArgumentList $argList -PassThru
}

##############################################################################
#.SYNOPSIS
# Run the website, then run the test javascript file with casper.
#
#.DESCRIPTION
# Throws an exception if the test fails.
#
#.PARAMETER SiteName
# The name of the website, as listed in applicationhost.config.
#
#.PARAMETER ApplicationhostConfig
# The path to applicationhost.config.  If not
# specified, searches parent directories for the file.
#
##############################################################################
function Run-IISExpressTest($SiteName = '', $ApplicationhostConfig = '', 
    $TestJs = 'test.js', [switch]$LeaveRunning = $false) {
    if (!$SiteName) {
        $SiteName = (get-item -Path ".\").Name
    }
    if (!$ApplicationhostConfig) {
        $ApplicationhostConfig = UpFind-File 'applicationhost.config'
    }

    $port = Get-PortNumber $SiteName $ApplicationhostConfig
    $webProcess = Run-IISExpress $SiteName $ApplicationhostConfig
    Try
    {
        Start-Sleep -Seconds 4  # Wait for web process to start up.
        casperjs $TestJs http://localhost:$port
        if ($LASTEXITCODE) {
            throw "Casperjs failed with error code $LASTEXITCODE"
        }
    }
    Finally
    {
        if (!$LeaveRunning) {
            Stop-Process $webProcess
        }
    }
}

##############################################################################
#.SYNOPSIS
# Migrate the database.
#
#.DESCRIPTION
# Must be called from a directory with a .csproj and Web.config.
#
#.PARAMETER DllName
# The name of the built binary.  Defaults to the current directory name.
##############################################################################
function Migrate-Database($DllName = '') {
    if (!$DllName) {
        $DllName =  (get-item .).Name + ".dll"
    }
    cp (Join-Path (UpFind-File packages) EntityFramework.*\tools\migrate.exe) bin\.
    $originalDir = pwd
    Try {
        cd bin
        .\migrate.exe $dllName /startupConfigurationFile="..\Web.config"
        if ($LASTEXITCODE) {
            throw "migrate.exe failed with error code $LASTEXITCODE"
        }
    }
    Finally {
        cd $originalDir
    }
}