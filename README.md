---
page_type: sample
languages:
  - csharp
products:
  - dynamics-365
  - dynamics-commerce
name: Extend Headless Commerce APIs.
description: This repo contains the sample code on how to extend the Dynamics 365 Headless Commerce engine - APIs, Commerce runtime and Database.
---

# Headless Commerce samples and Reference packages from GitHub and public feed

This readme file explains how to run the Headless Commerce extension samples and consume the reference package from the public feed for Dynamics 365 Commerce extension development.

This repo contains code samples, templates, and tools that are required to extend or customize existing Commerce functionality, samples are published into different repos in GitHub based on the Commerce extension components. This topic applies to Dynamics 365 commerce application version 10.0.16 or greater. For earlier version refer this [doc](https://docs.microsoft.com/en-us/dynamics365/commerce/dev-itpro/retail-sdk/retail-sdk-overview).

## Dynamics365Commerce.ScaleUnit repo

This repo contains the sample code for how to customize the Commerce runtime (CRT), Headless Commerce APIs and channel database.

The samples in the repo are organized by Dynamics 365 Commerce application release, each branch in the repo points to an application release of Dynamics 365 Commerce, use the right release branch based on your go-live version.

Note: The repo contains only samples, so its not required to clone this repo.

| Release branch name                                                                          | version | Application release version |
| -------------------------------------------------------------------------------------------- | ------- | --------------------------- |
| [Release/9.38](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/tree/release/9.38) | 9.38.\* | 10.0.28                     |
| [Release/9.39](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/tree/release/9.39) | 9.39.\* | 10.0.29                     |
| [Release/9.40](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/tree/release/9.40) | 9.40.\* | 10.0.30                     |
| [Release/9.41](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/tree/release/9.41) | 9.41.\* | 10.0.31                     |
| [Release/9.42](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit/tree/release/9.42) | 9.42.\* | 10.0.32                     |

**Extension repository:**

Extension code or repository if required can download and consume the samples and templates from [microsoft](https://github.com/microsoft)/[Dynamics365Commerce.ScaleUnit](https://github.com/microsoft/Dynamics365Commerce.ScaleUnit), the sample scale unit repo contains nuget.config, repo.props, CustomizationPackage.props and build pipelines script which provide guidance on how extension can setup the repo metadata files.

### Dynamics365Commerce.ScaleUnit repo folders and projects

| Folder                                                                   | Project                                                                                                                    | Description                                                                                                                                          |
|--------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Channel Database](./src/ScaleUnitSample/ChannelDatabase)                | [ChannelDatabase.csproj](./src/ScaleUnitSample/ChannelDatabase/ChannelDatabase.csproj)                                     | This project contains samples on how to create Commerce Runtime database extensions.                                                                 |
| [CommerceRuntime](./src/ScaleUnitSample/CommerceRuntime)                 | [CommerceRuntime.csproj](./src/ScaleUnitSample/CommerceRuntime/CommerceRuntime.csproj)                                     | Controller – Sample code for how to implement new RS APIs.Entities, Messages and RequestHandlers – Sample code for how to implement new CRT service. |
| [ScaleUnit](./src/ScaleUnitSample/ScaleUnit)                             | [ScaleUnit.csproj](./src/ScaleUnitSample/ScaleUnit/ScaleUnit.csproj)                                                       | Sample project on how to generate the CSU                                                                                                            |
| [ScaleUnit.Installer](./src/ScaleUnitSample/Installer)                   | [ScaleUnit.csproj](./src/ScaleUnitSample/Installer/ScaleUnit.Installer.csproj)                                             | Sample project on how to generate the CSU installer.                                                                                                 |
| [POS](./src/ScaleUnitSample/POS)                                         | [POS.csproj](./src/ScaleUnitSample/POS/POS.csproj)                                                                         | Contains samples on how to create POS extensions.                                                                                                    |
| [TypeScriptProxyGenerator](./src/ScaleUnitSample/CommerceProxyGenerator) | [TypeScriptProxyGenerator.csproj](./src/ScaleUnitSample/CommerceProxyGenerator/TypeScript/TypeScriptProxyGenerator.csproj) | Contains a sample on how to generate typescript extension proxies for Commerce Applications.                                                       |
| [CSharpProxyGenerator](./src/ScaleUnitSample/CommerceProxyGenerator)     | [CSharpProxyGenerator.csproj](./src/ScaleUnitSample/CommerceProxyGenerator/CSharp/CSharpProxyGenerator.csproj)             | Contains a sample on how to generate C# extension proxies for Commerce Applications.                                                          |

Samples for instore components like Modern POS, Cloud POS, Hardware station and Cloud scale unit – Self hosted are published in the [Dynamics365Commerce.InStore](https://github.com/microsoft/Dynamics365Commerce.InStore) repo.

Readme file inside the Commerce Runtime, ChannelDatabase and ScaleUnit contain more details on how to run the samples.

If you don't need POS or other samples from the repo, exclude the corresponding projects from the solution.

**Download reference packages for creating Commerce extension APIs and consuming messages, request, entities, and contracts:**

Commerce contracts, messages, entities, and request packages are published in this public feedfor commerce extension code to consume and customize existing functionalities or build new functionalities for Dynamics 365 Commerce product.

Consume the commerce packages from this [location](https://pkgs.dev.azure.com/commerce-partner/Registry/_packaging/dynamics365-commerce/nuget/v3/index.json), extension can add package source location in the nuget.config of their extension project file.

```xml
<packageSources>
    <add key="dynamics365-commerce" value="https://pkgs.dev.azure.com/commerce-partner/Registry/_packaging/dynamics365-commerce/nuget/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
</packageSources>
```

**Commerce packages available in the public feed:**

| Package name                                                          | Description                                                                                                                                                   |
| --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Microsoft.Dynamics.Commerce.Sdk.ChannelDatabase                       | This package is required to generate the DB packages with CSU.                                                                                                |
| Microsoft.Dynamics.Commerce.Sdk.Runtime                               | This package contains all commerce runtime libraries                                                                                                          |
| Microsoft.Dynamics.Commerce.Sdk.ScaleUnit                             | This package is required to generate the CSU package for deployment.                                                                                          |
| Microsoft.Dynamics.Commerce.Sdk.Installers.ScaleUnit                  | This package is required to generate the ScaleUnit package for deployment                                                                                     |
| Microsoft.Dynamics.Commerce.Sdk.HardwareAndPeripherals                | This package contains all commerce Hardware station and peripherals libraries                                                                                 |
| Microsoft.Dynamics.Commerce.Sdk.Installers                            | This package contains all the installers libraries                                                                                                            |
| Microsoft.Dynamics.Commerce.Sdk.Installers.HardwareStation            | This package is required to generate the Hardware station package for deployment                                                                              |
| Microsoft.Dynamics.Commerce.Sdk.Pos                                   | This package contains all POS libraries                                                                                                                       |
| Microsoft.Dynamics.Commerce.Sdk.Installers.ModernPos                  | This package is required to generate the POS extension installer for deployment                                                                               |
| Microsoft.Dynamics.Commerce.Diagnostics                               | This package contains all the diagnostic libraries                                                                                                            |
| Microsoft.Dynamics.Commerce.Runtime.Data                              | This package contains all data contract libraries                                                                                                             |
| Microsoft.Dynamics.Commerce.Runtime.DataServices.Messages             | This package contains all data services message libraries                                                                                                     |
| Microsoft.Dynamics.Commerce.Runtime.Entities                          | This package contains all commerce entities definition                                                                                                        |
| Microsoft.Dynamics.Commerce.Runtime.Framework                         | This package contains all commerce framework libraries                                                                                                        |
| Microsoft.Dynamics.Commerce.Runtime.Hosting.Contracts                 | This package contains all commerce controller libraries                                                                                                       |
| Microsoft.Dynamics.Commerce.Runtime.Messages                          | This package contains all commerce runtime messages libraries                                                                                                 |
| Microsoft.Dynamics.Commerce.Runtime.RealtimeServices.Messages         | This package contains all the commerce real runtime libraries                                                                                                 |
| Microsoft.Dynamics.Commerce.Runtime.Services.Messages                 | This package contains all the commerce service messages libraries                                                                                             |
| Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine.Contracts  | This package contains all the Commerce Pricing Engine contracts                                                                                               |
| Microsoft.Dynamics.Commerce.HardwareStation.Core                      | This package contains all the HWS libraries                                                                                                                   |
| Microsoft.Dynamics.Commerce.HardwareStation.PeripheralRequests        | This package contains all the HWS peripherals request libraries                                                                                               |
| Microsoft.Dynamics.Commerce.HardwareStation.Peripherals.Contracts     | This package contains all the HWS peripherals contracts libraries                                                                                             |
| Microsoft.Dynamics.Commerce.HardwareStation.Peripherals.Entities      | This package contains all the HWS peripherals entities libraries                                                                                              |
| Microsoft.Dynamics.Commerce.Installers.Framework                      | This package contains all the installers framework libraries                                                                                                  |
| Microsoft.Dynamics.Commerce.KeyVault.Contracts                        | This package contains all the key vault contract libraries                                                                                                    |
| Microsoft.Dynamics.Commerce.PaymentSDK.Extensions.Portable            | This package contains all the payment extension libraries                                                                                                     |
| Microsoft.Dynamics.Commerce.PaymentSDK.Portable                       | This package contains all the payment libraries                                                                                                               |
| Microsoft.Dynamics.Commerce.Runtime.FIF.Connector.Messages            | This package contains all the FIF connector libraries                                                                                                         |
| Microsoft.Dynamics.Commerce.Runtime.FIF.DocumentProvider.Messages     | This package contains all the FIF document provider libraries                                                                                                 |
| Microsoft.Dynamics.Commerce.Installers.Framework.DatabaseExtensions   | This package contains all the database installer framework libraries                                                                                          |
| Microsoft.Dynamics.Commerce.Tools.DbUtilities                         | This package contains all the DB utilities libraries                                                                                                          |
| Microsoft.Dynamics.Commerce.Tools.ExtensionsProxyGenerator.AspNetCore | This package contains all the extensions proxy generator utilities                                                                                            |
| Microsoft.Dynamics.Commerce.Proxy.ScaleUnit                           | This package contains all the proxies class for extension applications to consume the Headless Commerce APIs in online mode (connected to Headless Commerce). |

**Package versioning:**

| Package version  | Application release      |
| ---------------- | ------------------------ |
| 9.38.x.x-preview | 10.0.28 PEAP release     |
| 9.38.x.x         | 10.0.28 Customer preview |
| 9.38.x.x         | 10.0.28 GA               |
| 9.39.x.x-preview | 10.0.29 PEAP release     |
| 9.39.x.x         | 10.0.29 Customer preview |
| 9.39.x.x         | 10.0.29 GA               |
| 9.40.x.x-preview | 10.0.30 PEAP release     |
| 9.40.x.x         | 10.0.30 Customer preview |
| 9.40.x.x         | 10.0.30 GA               |
| 9.41.x.x-preview | 10.0.31 PEAP release     |
| 9.41.x.x         | 10.0.31 Customer preview |
| 9.41.x.x         | 10.0.31 GA               |
| 9.42.x.x-preview | 10.0.32 PEAP release     |
| 9.42.x.x         | 10.0.32 Customer preview |
| 9.42.x.x         | 10.0.32 GA               |

Extension project can consume the correct version by adding the package reference to the project with full version number or use wild card to always get the latest version, recommend option is to use the full version number and update the version based on your go-live version.

```xml
<PackageReference Include="Microsoft.Dynamics.Commerce.Sdk.Runtime" Version="9.39.x.x" />
```

Or

```xml
<PackageReference Include="Microsoft.Dynamics.Commerce.Sdk.Runtime" Version="9.39.*" />
```

Or

```xml
// Available in Visual Studio version 16.6, NuGet version 5.6, .NET Core SDK version 3.1.300
<PackageReference Include="Microsoft.Dynamics.Commerce.Sdk.Runtime" Version="9.39.*-*" />
```

With every hotfix and new application release, new version of the package will be published in the same public feed, consume the right package version based on the version required for your go-live. Consuming the higher version of the package than your go-live application version may result in runtime and deployment failures.

**Setup Azure DevOps pipeline for build automation and package generation:**

[Set up a build pipeline for the independent-packaging SDK](https://docs.microsoft.com/en-us/dynamics365/commerce/dev-itpro/build-pipeline)

**Best practice and branching strategies:**

Detailed information on git branching strategy refer [Git branching strategy](https://docs.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops) doc.

The following branching strategies are based on the way we use Git here at Microsoft. For more information, see [How we use Git at Microsoft](https://docs.microsoft.com/en-us/azure/devops/learn/devops-at-microsoft/use-git-microsoft).

Keep your branch strategy simple. Build your strategy from these three concepts:

- Use feature branches for all new features and bug fixes.
- Merge feature branches into the main branch using pull requests.
- Keep a high quality, up-to-date main branch.

**Create a new feature branch for development and bug fixes:**

Create a new feature main branch for our extension, follow the proper naming convention (refer the [Git branching doc for sample naming convention](https://docs.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops#name-your-feature-branches-by-convention))

**Create a new development branch:**

Create a private branch for the development:

```text
- git checkout -b private/{username}/{feature/description}
```

Add and commit new changes to the development branch using git -add . and git commit -m&quot; commit message.&quot;

After the development is completed, tested, and validated push the changes to the main branch by doing git push \&lt;remote\&gt; \&lt;branch\&gt;

```text
- git push origin {private branch name}
```

**Create a release branch after development:**

After the development changes pushed into the main branch, create a new release branch, and create the deployable packages from the release branch.

```text
- git checkout -b release/x.x.x
```

Merge the changes from the release branch back to main branch if any changes done in the release branch.

```text
- git checkout master git merge release/x.x.x
```

**Extension hotfix branch:**

Like release branch, create hotfix branch for extension from main branch and release the fix and later merge the changes back to the main branch.

**Merge new release branch to main and development branch:**

After a new version of the samples released, if required merge your development branch with the new branch. The repo contains only samples, so it&#39;s not required to always get the updated changes from the branch.

```text
- git checkout master git merge release/x.x.x
```
