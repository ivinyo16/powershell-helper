$VERSION = "1.0"

<#PSScriptInfo

.VERSION $VERSION

.AUTHOR ivin.lim@zeroavia.com

.COMPANYNAME Zeroavia

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.PRIVATEDATA

#>

<# 

.DESCRIPTION 
Added helper functions to be used with powershell

#> 

Get-Content $PSScriptRoot/user_variables.txt | Foreach-Object{
    
    if(!$_)
    {
        continue
    }

    $var = $_.Split('=')
    New-Variable -Name $var[0] -Value $var[1]

    if( $var[0] -like "#*" )
    {
        return
    }

    if( $var[0] -like "*path" )
    {
        $env:Path += ";"+$var[1]
    }

    Remove-Variable $var[0]

}

Function bbbb
{
    <#
        .SYNOPSIS
        Searches the current directory recursively for a given string parameter

        .DESCRIPTION
        Can add a filter option to limit search to certain filetypes as specfied by -filter option
    ...
    #>
    param
    (
        [string]
        #Limit search to these filetypes(ex. "*.txt"); default is "*"
        $filter = "*",
        
        [Parameter(Position=0,mandatory=$true)][string]
        #String to search for
        $text
    )
    Get-ChildItem `
    -Path "." -Filter $filter -recurse | `
    Select-String -pattern $text -CaseSensitive | `
    % `
    { `
        $path = $_.path; `
        $linenumber = $_.linenumber; `
        $line = $_.line; `
        Write-Host $path":"$linenumber"    "$line `
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

Function getDirectorySize
{
    <#
        .SYNOPSIS
        Get Size of directory

        .DESCRIPTION
        Get Size of directory
    ...
    #>
    param
    (
        [Parameter(Position=0,mandatory=$true)][string]
        #file to search for
        $text
    )
    $size = (Get-ChildItem -Path $text -Recurse -Force | Measure-Object -Property Length -Sum).Sum
    Write-Host "Directory size: $($size / 1MB) MB"
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

    $parameters = @('lmstat', '-c' , '1055@UKBESVR1', '-a')

    & "$executablePath" $parameters

    # this also works
    # & "C:\Program Files\ANSYS Inc\v212\SCADE\licensingclient\winx64\lmutil.exe" lmstat -c 1055@UKBESVR1 -a
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

createDayDirectory
Write-Host "loaded custom scripts version: $VERSION"
Write-Host "path: " $PSScriptRoot