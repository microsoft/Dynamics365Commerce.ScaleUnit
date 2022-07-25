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
    using System.Collections.Generic;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine.DiscountData;

    /// <summary>
    /// Discount loader for threshold discounts which uses the gross amount for total threshold calculation.
    /// </summary>
    /// <remarks>
    /// See <see href="https://blogs.msdn.microsoft.com/retaillife/2017/05/05/dynamics-retail-discount-extensibility-multiple-isvs/">discount package for extensibility</see>.
    /// </remarks>
    public class DiscountPackageGrossAmountThreshold : IDiscountPackage
    {

        private DiscountPackageThreshold discountPackage;

        /// <summary>
        /// Initializes a new instance of the <see cref="DiscountPackageGrossAmountThreshold" /> class.
        /// </summary>
        /// <param name="discountType">Retail discount type.</param>
        public DiscountPackageGrossAmountThreshold(ExtensiblePeriodicDiscountOfferType discountType)
        {
            this.discountPackage = new DiscountPackageThreshold(discountType);
        }

        /// <summary>Gets the discount type.</summary>
        public ExtensiblePeriodicDiscountOfferType DiscountOfferType
        {
            get { return this.discountPackage.DiscountOfferType; }
        }

        public DiscountBase CreateDiscount(PeriodicDiscount discountAndLine)
        {
            ThrowIf.Null(discountAndLine, nameof(discountAndLine));

            var threshold = (ThresholdDiscount) this.discountPackage.CreateDiscount(discountAndLine);

            // Set the field to indicate using gross amount instead of discounted amount for total amount calculation.
            threshold.UseGrossAmountForTotalThresholdAmount = true;
            return threshold;
        }

        /// <summary>
        /// Loads discount details.
        /// </summary>
        /// <param name="offerIdToDiscountMap">Offer Id to discount lookup.</param>
        /// <param name="pricingDataManager">Pricing data manager.</param>
        /// <param name="transaction">Sales transaction.</param>
        public void LoadDiscountDetails(Dictionary<string, DiscountBase> offerIdToDiscountMap, IPricingDataAccessor pricingDataManager, SalesTransaction transaction)
        {
            this.discountPackage.LoadDiscountDetails(offerIdToDiscountMap, pricingDataManager, transaction);
        }
    }
}
