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
    using System.Linq;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine.DiscountData;

    /// <summary>
    /// Discount package for amount cap.
    /// </summary>
    /// <remarks>
    /// See <see href="https://blogs.msdn.microsoft.com/retaillife/2017/05/05/dynamics-retail-discount-extensibility-multiple-isvs/">discount package for extensibility</see>.
    /// </remarks>
    public class DiscountPackageAmountCap : IDiscountPackage
    {
        private IDataAccessorAmountCap amountCapDataAccessor;

        /// <summary>
        /// Initializes a new instance of the <see cref="DiscountPackageAmountCap" /> class.
        /// </summary>
        /// <param name="amountCapDataAccessor">Amount cap data accessor.</param>
        /// <remarks>Data accessor interface to support both Channel And AX.</remarks>
        public DiscountPackageAmountCap(IDataAccessorAmountCap amountCapDataAccessor)
        {
            this.amountCapDataAccessor = amountCapDataAccessor;
        }

        /// <summary>Gets the discount type.</summary>
        public ExtensiblePeriodicDiscountOfferType DiscountOfferType
        {
            get { return ContosoPeriodicDiscountOfferType.AmountCap; }
        }

        /// <summary>
        /// Creates the discount.
        /// </summary>
        /// <param name="discountAndLine">Discount and line data.</param>
        /// <returns>The discount.</returns>
        public DiscountBase CreateDiscount(PeriodicDiscount discountAndLine)
        {
            ThrowIf.Null(discountAndLine, "discountAndLine");

            return new AmountCapDiscount(discountAndLine.ValidationPeriod);
        }

        /// <summary>
        /// Loads discount details.
        /// </summary>
        /// <param name="offerIdToDiscountMap">Offer Id to discount lookup.</param>
        /// <param name="pricingDataManager">Pricing data manager.</param>
        /// <param name="transaction">Sales transaction.</param>
        public void LoadDiscountDetails(
            Dictionary<string, DiscountBase> offerIdToDiscountMap,
            IPricingDataAccessor pricingDataManager,
            SalesTransaction transaction)
        {
            ThrowIf.Null(offerIdToDiscountMap, "offerIdToDiscountMap");

            IEnumerable<string> amountCapOfferIds = offerIdToDiscountMap.Where(p => p.Value.PeriodicDiscountType == ContosoPeriodicDiscountOfferType.AmountCap).Select(p => p.Key);

            if (amountCapOfferIds.Any())
            {
                IEnumerable<DiscountAmountCap> caps = this.amountCapDataAccessor.GetDiscountAmountCapsByOfferIdsAsync(amountCapOfferIds).GetAwaiter().GetResult() as IEnumerable<DiscountAmountCap>;

                foreach (DiscountAmountCap cap in caps)
                {
                    AmountCapDiscount discount = offerIdToDiscountMap[cap.OfferId] as AmountCapDiscount;
                    if (discount != null)
                    {
                        discount.DiscountAmountCap = cap.AmountCap;
                        discount.ApplyBaseReduction = cap.ApplyBaseReduction;
                    }
                }
            }
        }
    }
}
