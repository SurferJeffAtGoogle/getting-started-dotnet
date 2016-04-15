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
# Finds all the Web.config files in subdirectories.
#
##############################################################################
function Get-Config {
    Find-Files -Masks Web.config -AntiMasks 'bin', 'packages' | Resolve-Path -Relative
}

##############################################################################
#.SYNOPSIS
# Updates Web.config files, pulling values from environment variables.
#
#.DESCRIPTION
# Don't forget to Revert-Config or Unstage-Config before 'git commit'ing!
#
#.PARAMETER BookStore
# Where shall the books be stored?  Valid strings are 'mysql' and 'datastore'.
# Defaults to pulling the value from an environment variable.
#
#.INPUTS
# Paths to Web.config.  If empty, recursively searches directories for
# Web.config files.
#
#.EXAMPLE
# Update-Config mysql
##############################################################################
filter Update-Config([string]$BookStore = $null) {        
    $configs = if ($input.Length) { $input} else { Get-Config }
    foreach($configPath in $configs) {
        $config = Select-Xml -Path $configPath -XPath configuration
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
function Revert-Config {
    $configs = if ($input.Length) { $input} else { Get-Config }
    $silent = git reset HEAD $configs
    git checkout -- $configs
    git status
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
function Unstage-Config {
    $configs = if ($input.Length) { $input} else { Get-Config }
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
#.EXAMPLE
# Find-Files -Masks *.txt
##############################################################################
function Find-Files($Path = $null, [string[]]$Masks = '*', $MaxDepth = -1,
    $Depth=0, [string[]]$AntiMasks = @())
{
    foreach ($item in Get-ChildItem $Path | Sort-Object -Property Mode,Name)
    {
        if ($Masks | Where {$item -like $_})
        {
            $item
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
# Format-Code
##############################################################################
function Format-Code {
    $projects = if ($input.Length) {$input} else {Find-Files -Masks *.csproj}
    foreach ($project in $projects) {
        codeformatter.exe /rule:BraceNewLine /rule:ExplicitThis /rule:ExplicitVisibility /rule:FieldNames /rule:FormatDocument /rule:ReadonlyFields /rule:UsingLocation /nocopyright $project.FullName
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
function Lint-Code {
    $projects = if ($input.Length) {$input} else {Find-Files -Masks *.csproj}
    foreach ($project in $projects) {
        $project| Format-Code
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
function Build-Solution {
    nuget restore
    if ($LASTEXITCODE) {
        throw "Nuget failed with error code $LASTEXITCODE"
    }
    msbuild /p:Configuration=Debug
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
function Run-IISExpressTest($SiteName = '', $ApplicationhostConfig = '', $TestJs = 'test.js') {
    if (!$SiteName) {
        $SiteName = (get-item -Path ".\").Name
    }
    if (!$ApplicationhostConfig) {
        $ApplicationhostConfig = (UpFind-File 'applicationhost.config').FullName
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
        Stop-Process $webProcess
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
    cp packages\EntityFramework.*\tools\migrate.exe bin\.
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