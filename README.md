# azdo-nuget-dependency-analyzer
A Powershell script to analyze NuGet dependencies' target framework NetCore compatibility across repos in an Azure DevOps organization.

Usage: `Get-NuGetDependencyNetCoreCompatibility.ps1 -OrganizationName mimeo -PAT mysupersecretpattokenfromazdo`

This will return a Hashtable with the package name, whether it has a netcore compatible TFM, and a list of repositories that include this NuGet package.

Example:
```powershell
/> $stats = .\Get-NuGetDependencyNetCoreCompatibility.ps1 -OrganizationName mimeo -PAT mysupersecretpattokenfromazdo

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