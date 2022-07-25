/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

namespace Contoso.CommerceRuntime.PricingEngine
{
    using System.Runtime.Serialization;
    using Microsoft.Dynamics.Commerce.Runtime.ComponentModel.DataAnnotations;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;

    /// <summary>
    /// Represents a discount qualify line.
    /// </summary>
    [DataContract]
    [System.Diagnostics.CodeAnalysis.SuppressMessage("Maintainability", "DR1717:AssertTypesAreInExpectedNamespace", Justification = "Sample code")]
    public class DiscountQualifyLine : CommerceEntity
    {
        private const string RecordIdColumn = "RECID";
        private const string OfferIdColumn = "OFFERID";
        private const string QuantityColumn = "QUANTITY";
        private const string CategoryIdColumn = "CATEGORYID";
        private const string ProductIdColumn = "PRODUCTID";

        /// <summary>
        /// Initializes a new instance of the <see cref="DiscountQualifyLine"/> class.
        /// </summary>
        /// <param name="entityName">Entity name.</param>
        public DiscountQualifyLine(string entityName)
            : base(entityName)
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="DiscountQualifyLine"/> class.
        /// </summary>
        public DiscountQualifyLine()
            : base("CategoryThresholdQualifyLineView")
        {
        }

        /// <summary>Gets or sets the offer identifier.</summary>
        [DataMember]
        [Column(OfferIdColumn)]
        public string OfferId
        {
            get { return (string)this[OfferIdColumn]; }
            set { this[OfferIdColumn] = value; }
        }

        /// <summary>Gets or sets the record identifier of RETAILPERIODICDISCOUNT.</summary>
        [Key]
        [DataMember]
        [Column(RecordIdColumn)]
        public long RecordId
        {
            get { return (long)(this[RecordIdColumn] ?? 0L); }
            set { this[RecordIdColumn] = value; }
        }

        /// <summary>Gets or sets the item quantity.</summary>
        [DataMember]
        [Column(QuantityColumn)]
        public decimal Quantity
        {
            get { return (decimal)(this[QuantityColumn] ?? 0L); }
            set { this[QuantityColumn] = value; }
        }

        /// <summary>Gets or sets the category id.</summary>
        [DataMember]
        [Column(CategoryIdColumn)]
        public long CategoryId
        {
            get { return (long)(this[CategoryIdColumn] ?? 0L); }
            set { this[CategoryIdColumn] = value; }
        }

        /// <summary>Gets or sets the product id.</summary>
        [DataMember]
        [Column(ProductIdColumn)]
        public long ProductId
        {
            get { return (long)(this[ProductIdColumn] ?? 0L); }
            set { this[ProductIdColumn] = value; }
        }
    }
    }
