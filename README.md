# azdo-nuget-dependency-analyzer
A Powershell script to analyze NuGet dependencies' target framework NetCore compatibility across repos in an Azure DevOps organization.

```powershell
Get-NuGetDependencyNetCoreCompatibility.ps1 
    [-OrganizationName] <string>
    [-PAT] <string>
    [-Count] <int>
    [-ExportToCsv] <string>

```

### Description
The **Get-NuGeDependencyNetCoreCompatibility** script analyzes the `package.config` files, across all projects and all repositories in a given organization in Azure DevOps, for packages with .NET Core compatible Target Frameworks (TFM). This can be used to help assess whether a project's dependencies would prevent migration to .NET Core. 

By default, the script will return the results in a Hashtable for manipulation by other scripts. However, using the `ExportToCsv` option would be much easier for humans to work with.

### Examples

**Example 1: Retrieve results for 3 
repositories in a CSV**

```powershell
/> .\Get-NuGetDependencyNetCoreCompatibility.ps1 -OrganizationName Contoso -PAT mysupersecretpattokenfromazdo -Count 3 -ExportToCsv $env:TEMP\foo.csv

/> type $env:TEMP\foo.csv
Package,Supports NetCore,Project,Repository
WindowsAzure.Storage,True,Main WebSite,Contoso Web Service
Microsoft.AspNet.WebPages,False,Main WebSite,Contoso Web Service
StackExchange.Redis.Extensions.Core,True,Backend Tools,Spinny Admin
```
This will fetch the data from 3 repositories from the `Contoso` organization in Azure DevOps and save the results in CSV format to `$env:TEMP\foo.csv`. 

The results in this example show that the Azure DevOps project "Main WebSite" has a repository named "Contoso Web Service" that is dependent on the WindowsAzure.Storage package, which does have a .NET Core compatible TFM. However, the repo also has a dependency on Microsoft.ASpNet.WebPages NuGet package which does not have a .NET Core TFM. This could be a potential migration blocker.

**Example 2: Retrieve results in a Hashtable**
```powershell
/> $stats = .\Get-NuGetDependencyNetCoreCompatibility.ps1 -OrganizationName Fabrikam -PAT mysupersecretpattokenfromazdo

/> $stats
Name                           Value
----                           -----
Microsoft.AspNet.WebPages      @{netcore=False; projects=System.Collections.ArrayList}
Microsoft.Data.OData           @{netcore=True; projects=System.Collections.ArrayList}
Microsoft.ApplicationInsigh... @{netcore=True; projects=System.Collections.ArrayList}
Microsoft.AspNet.Razor         @{netcore=False; projects=System.Collections.ArrayList}
WebGrease                      @{netcore=True; projects=System.Collections.ArrayList}

/> $stats.Keys | % { if($stats[$_].netcore -eq $false){write-host "$_
 $($stats[$_].projects.repository)"}}

Microsoft.AspNet.WebPages My Fancy Web Project
Microsoft.AspNet.Razor My Fancy Web Project
bootstrap Contoso Printing Service
Microsoft.Web.Infrastructure My Fancy Web Project
```

The example is the default case to retrieve all resuls in a `Hashtable` object. The `Value` is a `PSCustomObject`. The `netcore` property of the object is a `boolean` indicating if the package has a .NET Core TFM. The `projects` property is an `ArrayList` of `PSCustomObject`s with `project` and `repository` properties, indicating the Azure DevOps project name and repository name respecitively.

### Required Parameters
`-Organization` <br/>
*Type: [string]* <br/>
*Default Value: None* <br/>
The Azure DevOps organization name to query.

`-PAT` <br/>
*Type: [string]* <br/>
*Default Value: None* <br/>
The Azure DevOps personal access token that has source code access for the projects and repositories within the organization.

### Optional Parameters
`-Count` <br/>
*Type: [int]* <br/>
*Default Value: 1000* <br/>
Number of repositories to analyze. The default value is set to the Azure DevOps API max of 1000 repositories.

`-ExportToCsv` <br/>
*Type: [string]* <br/>
*Default Value: None* <br/>
The path for the CSV output file.

### Notes
* When specifying `ExportToCsv`, a Powershell progress bar will be displayed in the console.*
