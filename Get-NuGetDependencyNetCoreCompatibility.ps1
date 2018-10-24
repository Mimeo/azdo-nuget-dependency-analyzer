[CmdletBinding()]
Param(
    # Azure DevOps Organization Name
    [Parameter(Mandatory = $true)]
    [string]$OrganizationName,

    # Azure DevOps PAT
    [Parameter(Mandatory = $true)]
    [string]$PAT,

    [Parameter(Mandatory = $false)]
    [int]$Count = 1000
)

Function GetAzureDevopsRequestHeader {
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$($PAT)"))
    $headers = @{ Authorization = "Basic $token" }

    return $headers
}

Function FindPackageConfigFiles {

    Write-Verbose "Gathering repository data from Azure DevOps..."
    # NOTE this is limited to 1000. Consider adding some paging logic to get all hits.
    $packageSearchRequestBody = "{
        'searchText': 'file:packages.config',
        '`$skip': 0,
        '`$top' : $Count,
        'filters': {
        
        },
        '`$orderBy': [
        {
            'field': 'filename',
            'sortOrder': 'ASC'
        }
        ],
        'includeFacets': true
    }"

    $headers = GetAzureDevopsRequestHeader
    $url = "https://almsearch.dev.azure.com/$OrganizationName/_apis/search/codesearchresults?api-version=4.1-preview.1"
    $response = Invoke-RestMethod -UseBasicParsing -Uri $url -Method POST -Headers $headers -Body $packageSearchRequestBody -ContentType "application/json"

    if ($response -eq $null) {
        throw "There was an error fetching packages.config files"
    }

    return $response.results
}

Function FetchPackageConfig {
    Param(
        [string]$Organization, 
        [string]$RepositoryId, 
        [string]$BlobId
    )

    $url = [System.Uri]::EscapeUriString("https://dev.azure.com/$Organization/_apis/git/repositories/$RepositoryId/blobs/$($BlobId)?api-version=4.1-preview.1")
    write-verbose $url

    $headers = GetAzureDevopsRequestHeader
    $packageContents = Invoke-RestMethod -UseBasicParsing -Uri $url -Method GET -Headers $headers -ContentType "application/xml"

    if ($packageContents.GetType().Name -ne "XmlDocument") {
        $packageXml = New-Object xml
        $packageXml.LoadXml($packageContents.Substring($packageContents.IndexOf("<")))
    } else {
        $packageXml = $packageContents
    }

    return $packageXml
}

Function AnalyzePackage {
    Param(
        [xml]$Package,
        [ref]$PackageData,
        [string]$Project,
        [string]$Repository
    )

    $repo = @{
        project = $Project;
        repository = $Repository
    }

    if ($Package.packages.package.Count -gt 0) {
        $Package.packages.package | % {
            if (!$PackageData.Value.ContainsKey($_.id)) {
                $PackageData.Value.Add($_.id, (New-Object System.Collections.ArrayList)) | Out-Null
            }
            
            if(!$PackageData.Value[$_.id].repository -or !$PackageData.Value[$_.id].repository.Contains($repo.repository)) {
                $PackageData.Value[$_.id].Add($repo) | Out-Null
            }
        }
    }
}

Function CheckNetCoreCompatibility {
    Param(
        [string]$Package
    )

    # Test if nuget.exe is on the path
    if ((Get-Command "nuget.exe" -ErrorAction SilentlyContinue) -eq $null) {
        throw "Please install nuget.exe"
        // todo install nuget.exe into the temp folder
    }

    # download package
    &nuget.exe install $Package -NonInteractive -DirectDownload -NoCache | Out-Null
    $libs =  gci lib -Recurse  | where {$_.psiscontainer} | gci -Directory

    # crack open package and enumate \libs
    $isNetCoreCompat = (gci lib -Recurse  | where {$_.psiscontainer} | gci | where -Property Name -match "netstandard|netcore" ).Count -gt 0

    # clean up folder
    gci | rm -Recurse -Force -ErrorAction SilentlyContinue

    return $isNetCoreCompat
}

# Create a temp working directory
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid())
New-Item -ItemType Directory -Path $workDir | Out-Null
Set-Location $workDir

try {
    # First find all of the packages.config files across all projects/repos in the organization
    $searchResults = FindPackageConfigFiles

    Write-Verbose "Fetching packages.config data..."

    $packageData = @{}
    $searchResults | % { 
        write-verbose $_
        $packageSpec = FetchPackageConfig -Organization $OrganizationName -RepositoryId $_.repository.id -BlobId $_.contentId
        AnalyzePackage -Package $packageSpec -PackageData ([ref]$packageData) -Project $_.project.name -Repository $_.repository.name        
    }

    Write-Verbose "Analyzing package compatibility..."

    $packageCompatibiltyData = @{}
    $packageData.Keys | % {
        $netcore = CheckNetCoreCompatibility -Package $_
        $p = [PSCustomObject]@{
            netcore = $netcore
            projects = $packageData[$_]
        }

        $packageCompatibiltyData.Add($_, $p)
    }

    return $packageCompatibiltyData
} 
finally {
    Set-Location $currentDir
}