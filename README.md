# README #

## Update local permissions ##
I have worked with Modern Powershell (7.x) which isn't installed by default.

See [setup](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows)

## Update local permissions ##
Windows by default disallows running powershell scripts, to allow locally created
update execution policies to for custom scripts
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

check status:
```
Get-ExecutionPolicy -List
```

if wanting to revert back
```
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser
```

## add startup script ##

Find startup file that is runs everytime powershell session starts. This may not exist yet.
Use following command to find path of supposed startup shell file:
```
echo $profile
```

ex. 
``
C:\Users\Ivin Lim\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1``

Create this file at this specific location. Creating directory when necessary (or copy template found in repo, change accordingly)
Inside file add following
```
Import-module  "C:\Users\John\powershell-helper\helper.ps1"
```
where path would depend on where helper.ps1 is found in your local setup.