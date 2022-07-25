This project contains samples on how to create POS extensions, 

[POS Extension Overview](https://docs.microsoft.com/en-us/dynamics365/commerce/dev-itpro/pos-extension/pos-extension-getting-started)

Steps to run the sample:

1.	If you are using Modern POS (MPOS), install the MPOS using the Sealed MPOS installer available in LCS, these samples will not work with legacy MPOS installers.
2.	To install the Sealed MPOS installer follow the steps documented [here]( https://docs.microsoft.com/en-us/dynamics365/commerce/dev-itpro/enhanced-mass-deployment#modern-pos), if you are using Cloud POS (CPOS) then it’s not required to install the MPOS.
3.	Before running the POS samples, install the [development environment prerequisites to build the POS samples.](https://docs.microsoft.com/en-us/dynamics365/commerce/dev-itpro/pos-extension/pos-extension-getting-started#prerequisites).
4.	Build the POS sample, output installer package will be created.
5.	Run the extension installer generated using command prompt.

   Ex: C:\ModernPos.Installer\bin\Debug\net472> .\ModernPos.Installer.exe install

6.	After you've finished installing the extension, close Modern POS if it's running. Then, to load the extension, open Modern POS by using the Install/Update Modern POS icon on the desktop. The extensions .appx file will be installed. The previous steps copy the .appx file and other files to the correct location.
7.	Validate the extension scenarios, search for a product in the POS search header bar, POS will navigate to the POS search view, you should see the Custom Navigate to Full System Example View app bar button and clicking that button POS should navigate to a custom view.

Detailed MPOS and CPOS deployment and packaging steps are documented [here]( https://docs.microsoft.com/en-us/dynamics365/commerce/dev-itpro/pos-extension/mpos-extension-packaging). 

