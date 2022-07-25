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
    using System;
    using System.Diagnostics.CodeAnalysis;
    using System.Globalization;
    using System.Runtime.Serialization;
    using Microsoft.Dynamics.Commerce.Runtime.ComponentModel.DataAnnotations;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;

    /// <summary>
    /// Represents a discount amount cap.
    /// </summary>
    [DataContract]
    [System.Diagnostics.CodeAnalysis.SuppressMessage("Maintainability", "DR1717:AssertTypesAreInExpectedNamespace", Justification = "Sample code")]
    public class DiscountAmountCap : CommerceEntity
    {
        private const string RecordIdColumn = "RECID";
        private const string OfferIdColumn = "OFFERID";
        private const string AmountCapColumn = "AMOUNTCAP";
        private const string ApplyBaseReductionColumn = "APPLYBASEREDUCTION";

        /// <summary>
        /// Initializes a new instance of the <see cref="DiscountAmountCap"/> class.
        /// </summary>
        /// <param name="entityName">Entity name.</param>
        public DiscountAmountCap(string entityName)
            : base(entityName)
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="DiscountAmountCap"/> class.
        /// </summary>
        public DiscountAmountCap()
            : base("DiscountAmountCapView")
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

        /// <summary>Gets or sets the record identifier.</summary>
        [Key]
        [DataMember]
        [Column(RecordIdColumn)]
        public long RecordId
        {
            get { return (long)(this[RecordIdColumn] ?? 0L); }
            set { this[RecordIdColumn] = value; }
        }

        /// <summary>Gets or sets the amount cap.</summary>
        [DataMember]
        [Column(AmountCapColumn)]
        public decimal AmountCap
        {
            get { return (decimal)(this[AmountCapColumn] ?? 0); }
            set { this[AmountCapColumn] = value; }
        }

        /// <summary>Gets or sets a value indicating whether this discount reduces the discount base amount.</summary>
        [DataMember]
        [Column(ApplyBaseReductionColumn)]
        [SuppressMessage("Usage", "DR1723:AssertColumnAttributeGetterUsage", Justification = "Convertion needs to be fixed.")]
        public bool ApplyBaseReduction
        {
            get { return Convert.ToBoolean(this[ApplyBaseReductionColumn], CultureInfo.InvariantCulture); }
            set { this[ApplyBaseReductionColumn] = value; }
        }
    }
}
