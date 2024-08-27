$ErrorActionPreference = 'Stop'

# Define URLs
$releaseTagsUrl = 'https://api.github.com/repos/apache/tomcat/git/refs/tags'
$baseUrl = 'https://archive.apache.org/dist/tomcat'
$preReleaseSuffix = '-M\d+$'
$UrlFormat = "{0}/tomcat-{1}/v{2}/bin/apache-tomcat-{2}-windows-{3}.zip{4}"

function global:au_GetLatest {
    param ()

    $headers = @{}
    $pat = $Env:github_api_key
    if ($pat) {
        $headers.Add("Authorization", "token $pat")
    }

    try {
        $tags = Invoke-RestMethod -Uri $releaseTagsUrl -Headers $headers
        # Strip out any pre-release versions
        $tags = $tags.where{$_.ref -NotMatch $preReleaseSuffix}
        $i = 0
        $versionValid = $false
        $versionInfo = @{}

        # Find the most up to date version that is not a pre-release version
        do {
            $i++
            $tagNum = $i * -1
            $version = $tags[$tagNum].ref.Substring(10) # last tag; remove prefix "refs/tags/"
            $majorVersion = $version.Split(".") | Select-Object -First 1

            $checksum32Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x86', '.sha512'
            $checksum64Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x64', '.sha512'
            $zip32Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x86', ''
            $zip64Url = $UrlFormat -f $baseUrl, $majorVersion, $version, 'x64', ''

            If ($majorVersion -eq 9) {
                # Ensure that the version has binaries
                $versionValid = au_TestVersionExists -checksumUrl $checksum32Url

                If ($versionValid) {
                    $versionInfo = @{
                        Version = $version
                        MajorVersion = $majorVersion
                        URL32 = $zip32Url
                        Checksum32Url = $checksum32Url
                        ChecksumType32 = 'sha512'
                        URL64 = $zip64Url
                        Checksum64Url = $checksum64Url
                        ChecksumType64 = 'sha512'
                    }
                }
            }
        } while (-Not $versionValid)

        Write-Host "Debug: Latest Version Info: $($versionInfo | ConvertTo-Json)"

        return $versionInfo
    } catch {
        Write-Warning "Failed to fetch tags from GitHub: $_"
        return $null
    }
}

function au_TestVersionExists($checksumUrl) {
    $validVersion = $false

    try {
        # First we create the request.
        $HTTP_Request = [System.Net.WebRequest]::Create($checksumUrl)
        $pat = $Env:github_api_key
        if ($pat) {
            $HTTP_Request.Headers.Add("Authorization", "token $pat")
        }

        # We then get a response from the site.
        $HTTP_Response = $HTTP_Request.GetResponse()

        # We then get the HTTP code as an integer.
        $HTTP_Status = [int]$HTTP_Response.StatusCode

        If ($HTTP_Status -eq 200) {
            $validVersion = $true
        }

        # Finally, we clean up the http request by closing it.
        If ($null -eq $HTTP_Response) { } 
        Else { $HTTP_Response.Close() }
    } catch {
        $validVersion = $false
    }

    return $validVersion
}

function global:au_BeforeUpdate { Get-RemoteFiles -Purge -NoSuffix -Algorithm sha512 }

function global:au_SearchReplace {
    param (
        [Hashtable]$Latest
    )

    if (-not $Latest) {
        Write-Warning "No valid version information found."
        return
    }

    $filename32 = Split-Path -Path $Latest.URL32 -Leaf
    $filename64 = Split-Path -Path $Latest.URL64 -Leaf
    $folderName = "apache-tomcat-{0}" -f $Latest.Version
    @{
        'tools\VERIFICATION.txt' = @{
            '^SHA-512 of 32-bit:.*' = 'SHA-512 of 32-bit: {0}' -f $Latest.Checksum32
            '^SHA-512 of 64-bit:.*' = 'SHA-512 of 64-bit: {0}' -f $Latest.Checksum64
            '^32-bit:.*' = '32-bit: {0}' -f $Latest.Checksum32Url
            '^64-bit:.*' = '64-bit: {0}' -f $Latest.Checksum64Url
        }
        'tools\chocolateyInstall.ps1' = @{
            '[$]filename32 =.*' = '$filename32 = "{0}"' -f $filename32
            '[$]filename64 =.*' = '$filename64 = "{0}"' -f $filename64
            '[$]zipContentFolderName =.*'= '$zipContentFolderName = "{0}"' -f $folderName
        }
        'tools\chocolateyUninstall.ps1' = @{
            '[$]zipContentFolderName =.*'= '$zipContentFolderName = "{0}"' -f $folderName
        }
    }
}

# Invoke au_GetLatest function with the optional PAT
$latestInfo = au_GetLatest

if ($latestInfo) {
    # Update the package if latest version info is fetched
    Update-Package -ChecksumFor none
} else {
    Write-Warning "Skipping package update due to failed fetch of latest version."
}
