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
    /// Discount loader for discount offer with line filter.
    /// </summary>
    /// <remarks>
    /// See <see href="https://blogs.msdn.microsoft.com/retaillife/2017/05/05/dynamics-retail-discount-extensibility-multiple-isvs/">discount package for extensibility</see>.
    /// </remarks>
    public class DiscountPackageOfferLineFilter : IDiscountPackage
    {
        private IDataAccessorOfferLineFilter offerLineFilterDataAccessor;

        /// <summary>
        /// Initializes a new instance of the <see cref="DiscountPackageOfferLineFilter" /> class.
        /// </summary>
        /// <param name="offerLineFilterDataAccessor">Offer line filter data accessor.</param>
        /// <remarks>Data accessor interface to support both Channel And AX.</remarks>
        public DiscountPackageOfferLineFilter(IDataAccessorOfferLineFilter offerLineFilterDataAccessor)
        {
            this.offerLineFilterDataAccessor = offerLineFilterDataAccessor;
        }

        /// <summary>Gets the discount type.</summary>
        /// <remarks>This is an override.</remarks>
        public ExtensiblePeriodicDiscountOfferType DiscountOfferType
        {
            get { return ExtensiblePeriodicDiscountOfferType.Offer; }
        }

        /// <summary>
        /// Creates the discount.
        /// </summary>
        /// <param name="discountAndLine">Discount and line data.</param>
        /// <returns>The discount.</returns>
        public DiscountBase CreateDiscount(PeriodicDiscount discountAndLine)
        {
            ThrowIf.Null(discountAndLine, "discountAndLine");

            return new OfferDiscountWithLineFilter(discountAndLine.ValidationPeriod);
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

            IEnumerable<string> offerIds = offerIdToDiscountMap.Where(p => p.Value.PeriodicDiscountType == ExtensiblePeriodicDiscountOfferType.Offer).Select(p => p.Key);

            if (offerIds.Any())
            {
                IEnumerable<OfferLineFilter> lineFilters = this.offerLineFilterDataAccessor.GetOfferLineFiltersByOfferIds(offerIds) as IEnumerable<OfferLineFilter>;

                foreach (OfferLineFilter lineFilter in lineFilters)
                {
                    if (!string.IsNullOrEmpty(lineFilter.ValidationPeriodId))
                    {
                        OfferDiscountWithLineFilter discount = offerIdToDiscountMap[lineFilter.OfferId] as OfferDiscountWithLineFilter;
                        if (discount != null)
                        {
                            RetailDiscountLine discountLineDefinition;
                            if (discount.DiscountLines.TryGetValue(lineFilter.DiscountLineNumber, out discountLineDefinition))
                            {
                                // We could optimize validation period lookup here.
                                ValidationPeriod period = this.offerLineFilterDataAccessor.GetValidationPeriod(lineFilter.ValidationPeriodId);
                                if (period != null)
                                {
                                    discountLineDefinition.SetProperty(OfferDiscountWithLineFilter.StringExtensionLinePeriod, period);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
