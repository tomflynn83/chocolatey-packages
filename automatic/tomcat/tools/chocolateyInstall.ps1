$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -parent $MyInvocation.MyCommand.Definition

$filename32 = "apache-tomcat-9.0.93-windows-x86.zip"
$filename64 = "apache-tomcat-9.0.93-windows-x64.zip"
$zipContentFolderName = "apache-tomcat-9.0.93"

$packageArgs = @{
    packageName = $env:ChocolateyPackageName
    destination = $toolsDir
    fileFullPath = Join-Path -Path $toolsDir -ChildPath $filename32
    fileFullPath64 = Join-Path -Path $toolsDir -ChildPath $filename64
}
Get-ChocolateyUnzip @packageArgs

$tomcatHome = Join-Path -Path $toolsDir -ChildPath $zipContentFolderName

if (Test-ProcessAdminRights) {
    $dataDir = $env:ProgramData
    $scope = 'Machine'
} else {
    $dataDir = $env:LocalAppData
    $scope = 'User'
}

$tomcatBase = Join-Path -Path $dataDir -ChildPath Tomcat9
Install-ChocolateyEnvironmentVariable -VariableName CATALINA_BASE -VariableValue $tomcatBase -Scope $scope
Install-ChocolateyEnvironmentVariable -VariableName CATALINA_HOME -VariableValue $tomcatHome -Scope $scope

if (Test-Path -Path $tomcatBase -ErrorAction SilentlyContinue) {
    Write-Debug "using configuration at $tomcatBase."
    foreach ($folder in 'conf', 'logs', 'temp', 'webapps', 'work') {
        Remove-Item -Recurse -Path "$tomcatHome\$folder"
    }
} else {
    Write-Verbose 'initializing configurations...'
    New-Item -Path $tomcatBase -ItemType directory
    foreach ($folder in 'conf', 'logs', 'temp', 'webapps', 'work') {
        Move-Item -Path "$tomcatHome\$folder" -Destination $tomcatBase
    }
}

if (! (Test-ProcessAdminRights)) {
    Write-Verbose 'Admin right not granted; system service not installed.'
} elseif (! (Test-Path -Path env:JAVA_HOME) -or ! (Get-Command -Name javac)) {
    Write-Warning 'Java not installed; system service not installed.'
} else {
    $service = Get-Service -Name Tomcat9 -ErrorAction SilentlyContinue
    if ($service.Length -gt 0) {
        &"$tomcatHome\bin\service" uninstall
    }

    &"$tomcatHome\bin\service" install
    Write-Debug "`$? = $?"
    Write-Debug "last exit code = $LastExitCode"
}

if (Split-Path -Path $toolsDir -Parent | Join-Path -ChildPath options.xml |Test-Path) {
    Write-Warning 'You are migrating from 8.5.12 or earlier version. Please check package description, or discuss with package maintainer.'
}
