/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

namespace Contoso.CommerceRuntime.Messages
{
    using System.Runtime.Serialization;
    using Microsoft.Dynamics.Commerce.Runtime.Messages;

    /// <summary>
    /// A simple response class to indicate whether a delete succeeded or not.
    /// </summary>
    [DataContract]
    public sealed class DeleteExampleEntityDataResponse : Response
    {
        /// <summary>
        /// Creates a new instance of the <see cref="DeleteExampleEntityDataResponse"/> class.
        /// </summary>
        /// <param name="success">Whether the delete succeeded.</param>
        public DeleteExampleEntityDataResponse(bool success)
        {
            this.Success = success;
        }

        /// <summary>
        /// Gets a value indicating whether the delete succeeded.
        /// </summary>
        public bool Success { get; private set; }
    }
}