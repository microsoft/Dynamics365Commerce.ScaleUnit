/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

namespace Contoso.CommerceRuntime.Triggers
{
    using System;
    using System.Collections.Generic;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Messages;

    /// <summary>
    /// Class that implements a post trigger for the GetCustomerDataRequest request type.
    /// </summary>
    public class DefinePosExtensionTrigger : IRequestTrigger
    {
        /// <summary>
        /// Gets the supported requests for this trigger.
        /// </summary>
        public IEnumerable<Type> SupportedRequestTypes
        {
            get
            {
                return new[] { typeof(GetExtensionPackageDefinitionsRequest) };
            }
        }

        /// <summary>
        /// Post trigger code to retrieve extension properties.
        /// </summary>
        /// <param name="request">The request.</param>
        /// <param name="response">The response.</param>
        public void OnExecuted(Request request, Response response)
        {
            ThrowIf.Null(request, "request");
            ThrowIf.Null(response, "response");

            var getExtensionsResponse = (GetExtensionPackageDefinitionsResponse)response;
            var extensionPackageDefinition = new ExtensionPackageDefinition();
            extensionPackageDefinition.Name = "Contoso.Commerce";
            extensionPackageDefinition.Publisher = "Contoso";
            extensionPackageDefinition.IsEnabled = true;

            getExtensionsResponse.ExtensionPackageDefinitions.Add(extensionPackageDefinition);
        }

        /// <summary>
        /// Pre trigger code.
        /// </summary>
        /// <param name="request">The request.</param>
        public void OnExecuting(Request request)
        {
        }
    }
}