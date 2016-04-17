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

param([switch]$lint)

function GetRootDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

Import-Module (Join-Path (GetRootDirectory) BuildTools.psm1) -DisableNameChecking

# First, lint everything.  If the lint fails, don't waste time running
# tests.
if ($lint) {
    Lint-Code
}
Update-Config
Try {
    Run-TestScripts
}
Finally {
    Revert-Config
}
