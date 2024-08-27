$ErrorActionPreference = 'Stop'

$zipContentFolderName = "apache-tomcat-9.0.93"
$serviceBat = Split-Path -parent $MyInvocation.MyCommand.Definition |
    Join-Path -ChildPath $zipContentFolderName |
    Join-Path -ChildPath bin |
    Join-Path -ChildPath service

Start-Process -FilePath $serviceBat -ArgumentList remove -Wait -NoNewWindow
Write-Debug "`$? = $?"
Write-Debug "last exit code = $LastExitCode"

Uninstall-ChocolateyEnvironmentVariable -VariableName CATALINA_BASE
Uninstall-ChocolateyEnvironmentVariable -VariableName CATALINA_HOME
