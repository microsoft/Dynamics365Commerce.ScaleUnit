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
    using System.Runtime.Serialization;
    using Microsoft.Dynamics.Commerce.Runtime.ComponentModel.DataAnnotations;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;

    /// <summary>
    /// Represents a discount offer line filter details.
    /// </summary>
    /// <remarks>
    /// Please use DiscountAmountCap as sample for data services customization.
    /// For now, it works only with sample tests.
    /// If you want to get offer line filter work full stack, please patch data services in PricingDataServiceSample project.
    /// </remarks>
    [DataContract]
    [System.Diagnostics.CodeAnalysis.SuppressMessage("Maintainability", "DR1717:AssertTypesAreInExpectedNamespace", Justification = "Sample code")]
    public class OfferLineFilter : CommerceEntity
    {
        private const string RecordIdColumn = "RECID";
        private const string OfferIdColumn = "OFFERID";
        private const string LineNumberColumn = "LINENUM";
        private const string ValidationPeriodIdColumn = "VALIDATIONPERIODID";

        /// <summary>
        /// Initializes a new instance of the <see cref="OfferLineFilter"/> class.
        /// </summary>
        /// <param name="entityName">Entity name.</param>
        public OfferLineFilter(string entityName)
            : base(entityName)
        {
        }

        /// <summary>
        /// Initializes a new instance of the <see cref="OfferLineFilter"/> class.
        /// </summary>
        public OfferLineFilter()
            : base("OfferLineFilterView")
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

        /// <summary>
        /// Gets or sets the identifier of the discount line for this rule.
        /// </summary>
        [DataMember]
        [Column(LineNumberColumn)]
        public decimal DiscountLineNumber
        {
            get { return Convert.ToDecimal(this[LineNumberColumn] ?? 0m); }
            set { this[LineNumberColumn] = value; }
        }

        /// <summary>
        /// Gets or sets the validation period identifier if using advanced date validation.
        /// </summary>
        [DataMember]
        [Column(ValidationPeriodIdColumn)]
        public string ValidationPeriodId
        {
            get { return (string)this[ValidationPeriodIdColumn]; }
            set { this[ValidationPeriodIdColumn] = value; }
        }
    }
}
