# Introduction

This sample demonstrates how to create E-Commerce proxies for your commerce runtime extension.
The sample consists of 2 projects:

1.  [E-CommerceProxyGenerator](./E-CommerceProxyGenerator.csproj): Generates proxies for a given dll. The dll generated from the 'CommerceRuntime' project is used as a sample. You can use a different dll in your project.
2.  [CommerceRuntime](../CommerceRuntime): Contains the entities and controller for the extension.

# Building Sample

To build the sample, open and build the solution.
Once the solution is built successfully, validate if the following two files got generated in your 'E-CommerceProxyGenerator' project:

1. 'DataService\DataActionExtension.g.ts': This file contains all the data actions extensions that can be used to call the APIs defined in your Commerce Runtime Controller.
2. 'DataService\DataServiceEntities.g.ts': This file contains all entity classes defined in your Commerce Runtime Extension.

# Consume files in E-Commerce App

Once the DataActionExtension.g.ts and DataServiceEntities.g.ts files are generated, you can manually move them to your [E-Commerce App](https://github.com/microsoft/Msdyn365.Commerce.Online). Eg: "Msdyn365.Commerce.Online\src\actions\extensions".

You can also uncomment the 'CopyGeneratedContracts' target section in the [E-CommerceProxyGenerator.csproj](./E-CommerceProxyGenerator.csproj#L18-L25) file to do this automatically for you.
