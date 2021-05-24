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
    using Contoso.CommerceRuntime.Entities.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Messages;

    /// <summary>
    /// A simple request class to update the values on an example entity. 
    /// </summary>
    [DataContract]
    public sealed class UpdateExampleEntityDataRequest : Request
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="UpdateExampleEntityDataRequest"/> class.
        /// </summary>
        /// <param name="entityKey">A unique key identifying an Example Entity record to update.</param>
        /// <param name="updatedEntity">An example entity with update fields.</param>
        public UpdateExampleEntityDataRequest(long entityKey, ExampleEntity updatedEntity)
        {
            this.ExampleEntityKey = entityKey;
            this.UpdatedExampleEntity = updatedEntity;
        }

        /// <summary>
        /// Gets the unique ID specifying the Example Entity record to update.
        /// </summary>
        public long ExampleEntityKey { get; private set; }

        /// <summary>
        /// Gets an Example Entity instance with any updates applied to it.
        /// </summary>
        [DataMember]
        public ExampleEntity UpdatedExampleEntity { get; private set; }
    }
}