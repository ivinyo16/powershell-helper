$VERSION = "1.0"

<#PSScriptInfo

.VERSION $VERSION

.AUTHOR ivin.lim


#>

<# 

.DESCRIPTION 
Added helper functions to be used with powershell

#> 


# Read user_variables.txt from the folder of this script
Get-Content -LiteralPath (Join-Path $PSScriptRoot 'user_variables.txt') | ForEach-Object {
    $line = $_.Trim()

    # Skip blank lines
    if (-not $line) { return }

    # Skip full-line comments that start with '#'
    if ($line -match '^\s*#') { return }

    # Split on the FIRST '=' only
    $eqIndex = $line.IndexOf('=')
    if ($eqIndex -lt 1) {
        Write-Warning "Skipping malformed line (no key=value): '$line'"
        return
    }

    $name  = $line.Substring(0, $eqIndex).Trim()
    $value = $line.Substring($eqIndex + 1).Trim()

    # Remove optional surrounding quotes from the value
    if ($value.StartsWith('"') -and $value.EndsWith('"')) {
        $value = $value.Trim('"')
    }

    # Allow inline comments after value: key=value # comment
    $value = ($value -split '\s+#', 2)[0].Trim()

    # Expand environment variables if present (e.g., %USERPROFILE% or $env:Var)
    $value = [Environment]::ExpandEnvironmentVariables($value)

    if ($name -like '*path') {
        # Append to PATH if not already present
        $currentPathParts = $env:Path -split ';' | Where-Object { $_ -and $_.Trim() }
        $alreadyThere = $currentPathParts | Where-Object { $_.Trim().ToLower() -eq $value.Trim().ToLower() }

        if (-not $alreadyThere) {
            $env:Path = ($currentPathParts + $value) -join ';'
            Write-Host "Appended to PATH: $value"
        } else {
            Write-Host "Already in PATH: $value"
        }
    }
    else {
        # Optional: create a variable for non-*path keys
        # (Use Set-Variable instead of New-Variable+Remove-Variable)
        Set-Variable -Name $name -Value $value -Scope Script
        Write-Host "Set variable: $name = $value"
    }
}


function bbbb {
    <#
        .SYNOPSIS
        Searches the current directory recursively for a given string parameter

        .DESCRIPTION
        Can add a filter option to limit search to certain filetypes as specified by -filter option
    #>
    param (
        [string]
        # Limit search to these filetypes (e.g., "*.txt"); default is "*"
        $filter = "*",

        [Parameter(Position=0, Mandatory=$true)]
        [string]
        # String to search for
        $text,

        [switch]
        # If specified, suppress output of matching line text
        $notext
    )

    Get-ChildItem -Path "." -Filter $filter -Recurse |
        Select-String -Pattern $text -CaseSensitive |
        ForEach-Object {
            $path = $_.Path
            $linenumber = $_.LineNumber
            $line = $_.Line

            if ($notext) {
                Write-Host $path":"$linenumber
            } else {
                Write-Host $path":"$linenumber"    "$line 
            }
        }
}

Function dddd
{
    <#
        .SYNOPSIS
        Searches the current directory for a file

        .DESCRIPTION
        searches recursively
    ...
    #>
    param
    (
        [Parameter(Position=0,mandatory=$true)][string]
        #file to search for
        $text
    )
    Get-ChildItem -Path "." -Include $text -Recurse -ErrorAction SilentlyContinue | % {  Write-Host $_.FullName }
}




function GetDirectorySize {

    <#
    .SYNOPSIS
    Calculates the size of a directory and optionally lists sizes of its immediate subdirectories.

    .DESCRIPTION
    This function computes the total size of all files within a specified directory. By default, it reports the logical file size (Length property).  
    If the `-enum` switch is provided, it also enumerates each immediate subdirectory and displays their sizes, sorted in descending order.  
    When `-excludeCloud` is specified, files marked as `Offline` (cloud-only placeholders such as OneDrive Files On-Demand or Dropbox Smart Sync) are excluded from the calculation.  
    Note: Hydrated cloud files may still have the `ReparsePoint` attribute but are included because their content is present on disk.

    .PARAMETER Path
    The full path to the directory whose size you want to calculate.

    .PARAMETER enum
    Switch that, when specified, lists the sizes of all immediate subdirectories under the given path.

    .PARAMETER excludeCloud
    Switch that excludes files not physically present on disk (those with the `Offline` attribute).  
    Useful for ignoring cloud-only placeholder files.

    .EXAMPLE
    GetDirectorySize -Path "C:\Data"
    Calculates the total size of all files under `C:\Data`.

    .EXAMPLE
    GetDirectorySize -Path "C:\Data" -enum
    Calculates the total size of `C:\Data` and lists sizes of its immediate subdirectories.

    .EXAMPLE
    GetDirectorySize -Path "C:\Data" -excludeCloud
    Calculates the size of `C:\Data` excluding cloud-only placeholder files.

    .EXAMPLE
    GetDirectorySize -Path "C:\Data" -enum -excludeCloud
    Calculates the size of `C:\Data`, lists subdirectory sizes, and excludes cloud-only placeholders.
    #>

    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$Path,

        [switch]$enum,

        [switch]$excludeCloud
    )

    if (-Not (Test-Path $Path)) {
        Write-Host "Path does not exist: $Path"
        return
    }

    # Filter: files only; if excludeCloud, skip Offline files
    $fileFilter = {
        -not ($_.PSIsContainer) -and
        (
            -not $excludeCloud -or
            -not ($_.Attributes -band [IO.FileAttributes]::Offline)
        )
    }

    # Gather all files under the path, respecting the filter
    $files = Get-ChildItem -Path $Path -Recurse -Force -File | Where-Object $fileFilter

    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $totalSize) { $totalSize = 0 }
    Write-Host ("Total directory size (logical): {0:N2} MB" -f ($totalSize / 1MB))

    if ($enum) {
        Write-Host "`nSubdirectory sizes (sorted by size):"

        # Enumerate immediate subdirectories; avoid traversing directory reparse points (junctions/mounts)
        $subdirSizes = Get-ChildItem -Path $Path -Directory -Force |
            Where-Object {
                # Skip directory reparse points to avoid crossing junctions/mountpoints
                -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
            } |
            ForEach-Object {
                $subdir = $_.FullName
                $subFiles = Get-ChildItem -Path $subdir -Recurse -Force -File | Where-Object $fileFilter
                $size = ($subFiles | Measure-Object -Property Length -Sum).Sum
                if ($null -eq $size) { $size = 0 }
                [PSCustomObject]@{
                    Subdirectory = $subdir
                    SizeMB       = [math]::Round($size / 1MB, 2)
                }
            }

        $subdirSizes |
            Sort-Object SizeMB -Descending |
            ForEach-Object {
                Write-Host ("{0,-50} {1,10:N2} MB" -f $_.Subdirectory, $_.SizeMB)
            }
    }
}



Function addtoPath
{
    <#
        .SYNOPSIS
        TEMPORARILY appends a specified path to the env variable PATH

        .DESCRIPTION
        only current shell terminal  will be affected
    ...
    #>
    param
    (
        [Parameter(Position=0,mandatory=$true)][string]
        #file to search for
        $text
    )
    $env:Path += ";$text"
}

Function removeLines
{
    <#
        .SYNOPSIS
        Removes a number of selected lines of a given extension file in the current directory recursviely

        .DESCRIPTION
        Removes a number of selected lines of a given extension file in the current directory recursviely
    #>
    param
    (
        [string]
        #Limit search to these filetypes(ex. "*.txt"); default is "*"
        $filter = "*",
        
        [Parameter(Position=0,mandatory=$true)][int]
        #number of lines at beginning to be skipped
        $first = 0,

        [Parameter(Position=1,mandatory=$true)][int]
        #number of lines at end to be skipped
        $last = 0
    )
    Get-ChildItem `
    -Path "." -Filter $filter -recurse | `
    % `
    { `
        get-content $_ | `
        select -Skip $first | `
        select -SkipLast $last | `
        set-content "temp.txt"; `
        if (test-path "temp.txt") `
        { `
            move "temp.txt" $_ -Force `
        } `
    }
}

Function openhelperscript
{
    <#
        .SYNOPSIS
        Opens up this file

        .DESCRIPTION
        Opens up this file
    #>
    param
    (
        [string]
        #Limit search to these filetypes(ex. "*.txt"); default is "*"
        $script = "helper.ps1"
    )

    code $PSScriptRoot/$script


}

Function openuservariables
{
    <#
        .SYNOPSIS
        Opens up this file

        .DESCRIPTION
        Opens up this file
    #>
    param
    (
        [string]
        #Limit search to these filetypes(ex. "*.txt"); default is "*"
        $script = "user_variables.txt"
    )

    code $PSScriptRoot/$script


}

Function PrependNameToItems {
    param (
        [string]$DirectoryPath,
        [string]$PrependString
    )

    # Check if directory exists
    if (-Not (Test-Path $DirectoryPath)) {
        Write-Error "Directory '$DirectoryPath' does not exist."
        return
    }

    # Get all files and folders in the directory
    $items = Get-ChildItem -Path $DirectoryPath

    foreach ($item in $items) {
        $newName = $PrependString + $item.Name
        $newPath = Join-Path -Path $DirectoryPath -ChildPath $newName

        Rename-Item -Path $item.FullName -NewName $newName
        Write-Host "Renamed: $($item.Name) -> $newName"
    }
}


Function massFilerename
{
    <#
        .SYNOPSIS
        Do a bulk rename of files in the current directory.

        .DESCRIPTION
        Do a bulk rename of files in the current directory.
    #>
    param
    (
        
        [Parameter(Position=0,mandatory=$true)][string]
        #number of lines at beginning to be skipped
        $old,

        [Parameter(Position=1,mandatory=$true)][string]
        #number of lines at end to be skipped
        $new
    )
    Get-ChildItem -File | Rename-Item -NewName {$_.name -replace "$old","$new"}
}

Function checkAnsysLicense
{
    <#
        .SYNOPSIS
        as the title suggests. hardcoded UK server

        .DESCRIPTION
        as the title suggests. hardcoded UK server
    #>

    $executablePath = "C:\Program Files\ANSYS Inc\v212\SCADE\licensingclient\winx64\lmutil.exe"

    # old server
    $parameters = @('lmstat', '-c' , '1055@UKBESVR1', '-a')
    # $parameters = @('lmstat', '-c' , '1055@US-SIM-13373', '-a')
    # $parameters = @('lmstat', '-c' , '1055@10.76.64.65', '-a')
    

    & "$executablePath" $parameters

    # this also works
    # & "C:\Program Files\ANSYS Inc\v212\SCADE\licensingclient\winx64\lmutil.exe" lmstat -c 1055@UKBESVR1 -a
}

function ScadeRemoveLicenseFeature {
<#
.SYNOPSIS
Removes a SCADE license feature using lmutil lmremove.

.DESCRIPTION
Runs 'lmutil lmremove' with the specified feature name against a fixed license server.
User, hostname, and display can be supplied. If not supplied, defaults are used.

.PARAMETER Feature
Name of the feature to remove (required in Run parameter set).

.PARAMETER User
User name associated with the license checkout. Defaults to 'IvinLim' if not provided.

.PARAMETER Hostname
Hostname where the license is checked out. Defaults to the current machine name.

.PARAMETER Display
Display identifier (often same as hostname on Windows). Defaults to the current machine name.

.PARAMETER Help
Show inline usage information. When specified, no other parameters are required.
#>
    [CmdletBinding(DefaultParameterSetName = 'Run')]
    param (
        # Help parameter set: no other params are required
        [Parameter(Mandatory = $false, ParameterSetName = 'Help')]
        [Alias('h','?')]
        [switch]$Help,

        # Run parameter set: Feature is mandatory
        [Parameter(Mandatory = $true, ParameterSetName = 'Run')]
        [string]$Feature,

        [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
        [string]$User = 'IvinLim',

        [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
        [string]$Hostname = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false, ParameterSetName = 'Run')]
        [string]$Display = $env:COMPUTERNAME
    )

    # If we're in the Help parameter set, print usage and exit before any other validation
    if ($PSCmdlet.ParameterSetName -eq 'Help') {
        Write-Host "`nUsage: ScadeRemoveLicenseFeature -Feature <featureName> [-User <name>] [-Hostname <host>] [-Display <display>] [-Help]`n"
        Write-Host "Description:"
        Write-Host "  Runs 'lmutil lmremove' with the specified feature name."
        Write-Host "  Default User = 'IvinLim'; Hostname/Display default to this machine."
        Write-Host "`nParameters:"
        Write-Host "  -Feature   [string]   Name of the feature to remove (required in Run set)"
        Write-Host "  -User      [string]   Username tied to the checkout (optional; default: IvinLim)"
        Write-Host "  -Hostname  [string]   Hostname of the checkout (optional; default: current machine)"
        Write-Host "  -Display   [string]   Display identifier (optional; default: current machine)"
        Write-Host "  -Help      [switch]   Show this help message (no other params required)"
        return
    }

    # --- Execution path (Run parameter set) ---
    $executablePath = "C:\Program Files\ANSYS Inc\v212\SCADE\licensingclient\winx64\lmutil.exe"
    $LicenseServer = "1055@UKBESVR1"

    $Arguments = @(
        "lmremove"
        "-c", $LicenseServer
        $Feature
        $User
        $Hostname
        $Display
    )

    Write-Host "Running command:`n  `"$executablePath`" $($Arguments -join ' ')"
    Start-Process -FilePath $executablePath -ArgumentList $Arguments -NoNewWindow -Wait
}

Function createDayDirectory
{
    <#
        .SYNOPSIS
        automatically create directory in temp folder, for personal usage

        .DESCRIPTION
        automatically create directory in temp folder, for personal usage
    #>

    $date_today = Get-Date -format "yyyy_MM_dd"
    # Write-Host "date today $date_today"
    $newfolderpath = "C:/temp/$date_today"
    # Write-Host "newfolderpath $newfolderpath"

    if (Test-Path -Path $newfolderpath) {
        # "Path exists!"
    } else {
        mkdir $newfolderpath > $null
        "created $newfolderpath folder"
    }

}

function Run-MergeToolWithTraces {
    # Prompt user to select a folder
    # $folder = (New-Object -ComObject Shell.Application).BrowseForFolder(0, "Select folder containing .trc files", 0).Self.Path

    # if (-not $folder) {
    #     Write-Host "No folder selected. Exiting."
    #     return
    # }

    
    param 
    (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )

    if (-not (Test-Path $FolderPath)) 
    {
        Write-Host "The specified folder path does not exist: $FolderPath"
        return
    }



    # Get all .trc files in the selected folder
    # $traceFiles = Get-ChildItem -Path $FolderPath -Filter *.trc | Select-Object -ExpandProperty Name

    #change to relative path
$traceFiles = Get-ChildItem -Path $FolderPath -Filter *.trc -File | ForEach-Object {
    $relativePath = Resolve-Path -Relative $_.FullName
    $relativePath
}



    if ($traceFiles.Count -eq 0) {
        Write-Host "No .trc files found in the selected folder."
        return
    }


    # Enclose each file name in quotes
     $quotedFiles = $traceFiles | ForEach-Object { "`"$($_)`"" }

    # Construct the command
    $command = "TraceMerge_64.exe " + ($quotedFiles -join ' ')

    # Output the command (or run it if you prefer)
    Write-Host "Generated command:"
    Write-Host $command

    # Optionally, run the command
    Invoke-Expression $command
}

function Convert-TraceFile {
    param (
        [string]$InputFile,
        [string]$OutputFile = "output_trace_file.trc"
    )

    Get-Content $InputFile | ForEach-Object {
        if ($_ -like ";*") {
            # Preserve comment lines
            $_
        } else {
            $columns = $_ -split " "
            if ($columns.Length -ge 3) {
                # $columns[1] = "{0:N3}" -f [float]$columns[1]
                $columns[1] = "$($columns[1]).000"
                "$($columns[0]) $($columns[1])            $($columns[2..($columns.Length - 1)] -join ' ')"
            } else {
                $_
            }
        }
    } | Set-Content $OutputFile
}

function Process-TraceFilesInDirectory {
    param (
        [string]$InputDirectory
    )

    # Ensure the Convert-TraceFile function is available
    if (-not (Get-Command Convert-TraceFile -ErrorAction SilentlyContinue)) {
        Write-Error "Convert-TraceFile function is not defined in the current session."
        return
    }

    # Create Output directory if it doesn't exist
    $OutputDirectory = Join-Path $InputDirectory "Output"
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
    }

    # Process each .trc file in the directory
    Get-ChildItem -Path $InputDirectory -File -Filter *.trc | ForEach-Object {
        $inputFile = $_.FullName
        # $outputFileName = \"$($_.BaseName)_processed$($_.Extension)\"
        $outputFileName = "$($_.BaseName)_processed$($_.Extension)"
        $outputFile = Join-Path $OutputDirectory $outputFileName

        Write-Host $outputFile

        Convert-TraceFile -InputFile $inputFile -OutputFile $outputFile
        Write-Host \"Processed: $($_.Name) -> $outputFileName\"
    }
}

function List-Python
{
    <#
    .SYNOPSIS
    This will list all Python-related executables available in your system path.

    .DESCRIPTION
    This will list all Python-related executables available in your system path.
    #>
     Get-Command python* | Select-Object Name, Source
}

function Switch-Python {

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("3.7", "3.8", "3.9", "3.10", "3.11", "3.12")]
    [string]$Version
)

# Define paths to Python installations
$pythonPaths = @{
    "3.7"  = "C:\Python37"
    "3.8"  = "C:\Python38"
    "3.9"  = "C:\Python39"
    "3.10" = "C:\Users\Ivin Lim\AppData\Local\Programs\Python\Python310"
    "3.11" = "C:\Python311"
    "3.12" = "C:\Users\Ivin Lim\AppData\Local\Programs\Python\Python312"
}

if ($pythonPaths.ContainsKey($Version)) {
    $selectedPath = $pythonPaths[$Version]
    if (Test-Path "$selectedPath\python.exe") {
        $env:Path = "$selectedPath;$env:Path"
        $env:Path = "$selectedPath\Scripts;$env:Path"
        Write-Host "✅ Switched to Python $Version at $selectedPath"
        & "$selectedPath\python.exe" --version
    } else {
        Write-Host "❌ Python executable not found at $selectedPath"
    }
} else {
    Write-Host "❌ Python version $Version is not configured."
}

}


function SvnCleanUnversioned {

    <#
    .SYNOPSIS
        Deletes unversioned files and directories from an SVN working copy.

    .DESCRIPTION
        This function mimics the behavior of `git clean -fd` for Subversion (SVN).
        It uses `svn status --no-ignore` to identify unversioned items (marked with '?'),
        and then deletes them from the working directory.

    .PARAMETER Path
        The path to the SVN working copy. Defaults to the current directory.

    .PARAMETER Force
        If specified, skips the confirmation prompt and deletes unversioned items immediately.

    .EXAMPLE
        Clean-SvnUnversioned
        Prompts to delete unversioned items in the current directory.

    .EXAMPLE
        Clean-SvnUnversioned -Path "C:\Projects\MyRepo" -Force
        Deletes unversioned items in the specified directory without confirmation.

    .NOTES
        Use with caution. This will permanently delete files and directories not tracked by SVN.
    #>

    param (
        [string]$Path = ".",     # Default path is current directory
        [switch]$Force           # If specified, skips confirmation prompt
    )

    # Change to the specified SVN working directory
    Set-Location $Path

    # Run 'svn status --no-ignore' to list all files, including ignored ones
    # Filter lines starting with '?' which indicate unversioned files/directories
    $unversionedItems = svn status --no-ignore | Where-Object { $_ -match '^\?' } | ForEach-Object {
        # Split the line and extract the file path (second part)
        ($_ -split '\s+', 2)[1]
    }

    # If no unversioned items are found, exit early
    if ($unversionedItems.Count -eq 0) {
        Write-Host "No unversioned items found."
        return
    }

    # Display the list of unversioned items
    Write-Host "Unversioned items found:"
    $unversionedItems | ForEach-Object { Write-Host $_ }

    # If -Force is not used, prompt the user for confirmation
    if (-not $Force) {
        $confirm = Read-Host "Do you want to delete these items? (y/n)"
        if ($confirm -ne 'y') {
            Write-Host "Operation cancelled."
            return
        }
    }

    # Delete each unversioned item (file or directory)
    $unversionedItems | ForEach-Object {
        Remove-Item $_ -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Unversioned items deleted."
}

Function githash {
        <#
    .SYNOPSIS
        git hash commit small version

    #>
    git rev-parse --short HEAD
}

Function gitPruneAndDeleteLocalBranches {
            <#
    .SYNOPSIS
        delete local branches that are pruned(no remote branch)

    #>
    git fetch --prune
    git branch -vv | Where-Object { $_ -match 'gone\]' } | ForEach-Object { $_.Trim().Split()[0] } | ForEach-Object { git branch -d $_ }

}


createDayDirectory
Write-Host "loaded custom scripts version: $VERSION"
Write-Host "path: " $PSScriptRoot