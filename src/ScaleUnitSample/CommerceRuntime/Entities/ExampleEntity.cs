/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

namespace Contoso.CommerceRuntime.Entities.DataModel
{
    using System.Runtime.Serialization;
    using Microsoft.Dynamics.Commerce.Runtime.ComponentModel.DataAnnotations;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using SystemAnnotations = System.ComponentModel.DataAnnotations;

    /// <summary>
    /// Defines a simple class that holds information about opening and closing times for a particular day.
    /// </summary>
    public class ExampleEntity : CommerceEntity
    {
        private const string ExampleIntColumn = "EXAMPLEINT";
        private const string ExampleStringColumn = "EXAMPLESTRING";
        private const string IdColumn = "EXAMPLEID";

        /// <summary>
        /// Initializes a new instance of the <see cref="ExampleEntity"/> class.
        /// </summary>
        public ExampleEntity()
            : base("Example")
        {
        }

        /// <summary>
        /// Gets or sets a property containing an int value.
        /// </summary>
        [DataMember]
        [Column(ExampleIntColumn)]
        public int IntData
        {
            get { return (int)this[ExampleIntColumn]; }
            set { this[ExampleIntColumn] = value; }
        }

        /// <summary>
        /// Gets or sets a property containing a string value.
        /// </summary>
        [DataMember]
        [Column(ExampleStringColumn)]
        public string StringData
        {
            get { return (string)this[ExampleStringColumn]; }
            set { this[ExampleStringColumn] = value; }
        }

        /// <summary>
        /// Gets or sets the id.
        /// </summary>
        /// <remarks>
        /// Fields named "Id" are automatically treated as the entity key.
        /// If a name other than Id is preferred, <see cref="System.ComponentModel.DataAnnotations.KeyAttribute"/>
        /// can be used like it is here to annotate a given field as the entity key.
        /// </remarks>
        [SystemAnnotations.Key]
        [DataMember]
        [Column(IdColumn)]
        public long UnusualEntityId
        {
            get { return (long)this[IdColumn]; }
            set { this[IdColumn] = value; }
        }
    }
}