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
    /// A simple request used to delete an example entity from the database.
    /// </summary>
    [DataContract]
    public sealed class DeleteExampleEntityDataRequest : Request
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="DeleteExampleEntityDataRequest"/> class.
        /// </summary>
        /// <param name="entityKey">A unique key identifying an Example Entity record to delete.</param>
        public DeleteExampleEntityDataRequest(long entityKey)
        {
            this.ExampleEntityKey = entityKey;
        }

        /// <summary>
        /// Gets the unique ID specifying the Example Entity record to delete.
        /// </summary>
        public long ExampleEntityKey { get; private set; }
    }
}