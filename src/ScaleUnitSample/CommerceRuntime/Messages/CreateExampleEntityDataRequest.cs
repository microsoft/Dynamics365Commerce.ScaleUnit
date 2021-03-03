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
    /// A simple request class to create an Example Entity in the database.
    /// </summary>
    [DataContract]
    public sealed class CreateExampleEntityDataRequest : Request
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="CreateExampleEntityDataRequest"/> class.
        /// </summary>
        /// <param name="entityData">An example entity with its fields populated with the values to be stored.</param>
        public CreateExampleEntityDataRequest(ExampleEntity entityData)
        {
            this.EntityData = entityData;
        }

        /// <summary>
        /// Gets an Example Entity instance with its fields set with the values to be stored.
        /// </summary>
        [DataMember]
        public ExampleEntity EntityData { get; private set; }
    }
}