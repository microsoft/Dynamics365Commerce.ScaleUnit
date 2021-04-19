
---
page_type: sample
languages:
- csharp
products:
- Dynamics 365 Commerce
name: Extend Headless commerce engine (CRT/RS)
description: This repo contains the sample code on how to extend the Dynamics 365 Headless Commerce engine - Retail Server, Commerce runtime and Database.
---

**Download Retail SDK samples and Reference packages from GitHub and NuGet feed:**

This document explains to how to get Retail SDK samples from GitHub and reference package from the public NuGet feed.

The Retail SDK includes the code samples, templates, and tools that are required to extend or customize existing Commerce functionality, SDK code samples is published into different repos in GitHub based on the Commerce extension components. This topic applies to Retail SDK version 10.0.16 or greater. To get the SDK for earlier version, please refer this [doc](https://docs.microsoft.com/en-us/dynamics365/commerce/dev-itpro/retail-sdk/retail-sdk-overview).

**Commerce.ScaleUnit repo:**

This repo contains the sample code for how to customize the Commerce runtime (CRT), Retail server (RS) and channel database.

Clone or download the Commerce scale unit (CSU) repo from [microsoft](https://github.com/microsoft)/[Dynamics365Commerce.ScaleUnit](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit).

The repo will contain multiple branches for each release, please use the right release branch based on your go-live version. Note: The repo contains only samples, so its not really required to clone this repo.

| Release branch name                                                                          | version | Application release version |
| -------------------------------------------------------------------------------------------- | ------- | --------------------------- |
| [Release/9.26](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/tree/release/9.26) | 9.26.\* | 10.0.16                     |
| [Release/9.27](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/tree/release/9.26) | 9.27.\* | 10.0.17                     |

To clone a specific release branch, use the following command:

git clone --single-branch --branch release/9.26 [https://github.com/microsoft/Dynamics365Commerce.ScaleUnit.git](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit.git)

This will clone the release/9.26 into your current directory.

The **Commerce.ScaleUnit repo** folders and projects:

| Folder           | Project                                                                                                                                       | Contents                                                                                                                                             | Description                                   |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| Channel Database | ChannelDatabase.csproj                                                                                                                        | Contoso.ExampleTable.ChannelDatabase.sql                                                                                                             | Sample database extension.                    |
| CommerceRuntime  | [CommerceRuntime.csproj](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/blob/release/9.26/CommerceRuntime/CommerceRuntime.csproj) | Controller – Sample code for how to implement new RS APIs.Entities, Messages and RequestHandlers – Sample code for how to implement new CRT service. | Sample CRT extensions.                        |
| ScaleUnit        | [ScaleUnit.csproj](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/blob/release/9.26/ScaleUnit/ScaleUnit.csproj)                   | Project required to generate the CSU package.                                                                                                        | Project required to generate the CSU package. |

**Note:** Repos for instore components like Modern POS, Cloud POS, Hardware station and Retail scale unit and other samples will be available in later releases.

**Download reference packages for creating Commerce APIs and consuming messages, request, entities, and contracts:**

Commerce contracts, messages, entities, and request packages are published in this public feed for commerce extension code to consume and customize existing functionalities or build new functionalities for Dynamics 365 Commerce product.

Consume the commerce packages from this [location](https://pkgs.dev.azure.com/commerce-partner/Registry/_packaging/dynamics365-commerce/nuget/v3/index.json), extension can add package source location in the nuget.config of their extension project file.

```
<packageSources>
	<add key="dynamics365-commerce" value="https://pkgs.dev.azure.com/commerce-partner/Registry/_packaging/dynamics365-commerce/nuget/v3/index.json" />
	<add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
</packageSources>
```

**Commerce packages available in the public feed:**

| Package name                            | Dependencies                            | Description |
| --------------------------------------- | --------------------------------------- | ----------- |
| Microsoft.Dynamics.Commerce.Sdk.Runtime | Microsoft.Dynamics.Commerce.Diagnostics |

Microsoft.Dynamics.Commerce.Runtime.Data
Microsoft.Dynamics.Commerce.Runtime.DataServices.Messages
Microsoft.Dynamics.Commerce.Runtime.Entities
Microsoft.Dynamics.Commerce.Runtime.Framework
Microsoft.Dynamics.Commerce.Runtime.Hosting.Contracts
Microsoft.Dynamics.Commerce.Runtime.Messages
Microsoft.Dynamics.Commerce.Runtime.RealtimeServices.Messages
Microsoft.Dynamics.Commerce.Runtime.Services.Messages | This meta package which contains all the required packages for doing the CRT and Retail server extension. All the required Commerce contracts, messages, request/response, entities are included in this package. |
| Microsoft.Dynamics.Commerce.Sdk.ScaleUnit | CSU Packaging dependencies. | This package is required to generate the CSU package for deployment. |
| Microsoft.Dynamics.Commerce.Sdk.ChannelDatabase | Channel database packaging dependencies. | This package is required to generate the DB packages with CSU.
|

**Package versioning:**

| Package version  | Application release      |
| ---------------- | ------------------------ |
| 9.26.x.x-preview | 10.0.16 PEAP release     |
| 9.26.x.x         | 10.0.16 Customer preview |
| 9.26.x.x         | 10.0.16 GA               |

Extension project can consume the correct version by adding the package reference to the project with full version number or use wild card to always get the latest version, recommend option is to use the full version number and update the version based on your go-live version.

```
<PackageReference Include="Microsoft.Dynamics.Commerce.Sdk.Runtime" Version="9.26.x.x" />
```

Or

```
<PackageReference Include="Microsoft.Dynamics.Commerce.Sdk.Runtime" Version="9.26.*" />
```

With every hotfix and new application release, new version of the package will be published in the same public feed, consume the right package version based on the version required for your go-live. Consuming the higher version of the package than your go-live application version may result in runtime and deployment failures.

**Setup Azure DevOps pipeline for build automation and package generation:**

- Information will be added later.

**Best practice and branching strategies:**

Detailed information on git branching strategy refer [Git branching strategy](https://docs.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops) doc.

The following branching strategies are based on the way we use Git here at Microsoft. For more information, see [How we use Git at Microsoft](https://docs.microsoft.com/en-us/azure/devops/learn/devops-at-microsoft/use-git-microsoft).

Keep your branch strategy simple. Build your strategy from these three concepts:

- Use feature branches for all new features and bug fixes.
- Merge feature branches into the main branch using pull requests.
- Keep a high quality, up-to-date main branch.

**Create a new feature branch for development and bug fixes:**

Create a new feature branch based of commerce release/x.x.x branch, Clone the Commerce release/x.x.x branch and then create a new branch based on that, Follow the proper naming convention (refer the [Git branching doc for sample naming convention](https://docs.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops#name-your-feature-branches-by-convention))

**Command to clone and create a new branch:**

- git clone --single-branch --branch release/9.26 [https://github.com/microsoft/Dynamics365Commerce.ScaleUnit.git](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit.git)

- git checkout -b private/{username}/{feature/description}

Add and commit new changes to the development branch using git -add . and git commit -m&quot; commit message.&quot;

After the development is completed, tested, and validated push the changes to the main branch by doing git push \&lt;remote\&gt; \&lt;branch\&gt;

- git push origin {private branch name}

**Create a release branch after development:**

After the development changes pushed into the main branch, create a new release branch, and create the deployable packages from the release branch.

- Git checkout -b release/x.x.x

Merge the changes from the release branch back to main branch if any changes done in the release branch.

```

- git checkout master git merge release/x.x.x

```

**Extension hotfix branch:**

Like release branch, create hotfix branch for extension from main branch and release the fix and later merge the changes back to the main branch.

**Merge new SDK release branch to main and development branch:**

After a new version of the SDK samples released, if required branch it with your new branch. The SDK contains only samples, so it&#39;s not required to always get the updated changes from the new SDK release branch.

```

- git checkout master git merge release/x.x.x

```
