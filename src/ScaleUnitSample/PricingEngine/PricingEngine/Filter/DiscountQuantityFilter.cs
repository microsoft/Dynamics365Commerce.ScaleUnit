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
    using System.Linq;
    using System.Collections.Generic;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine.DiscountData;

    /// <summary>
    /// A sample usage of discount filter interface.
    /// </summary>
    public class DiscountQuantityFilter : IDiscountFilter
    {
        // Qualify line data accessor.
        private IDataAccessorDiscountQualifyLines dataAccessor;

        /// <summary>
        /// Initialize a new instance.
        /// </summary>
        /// <param name="dataAccessorCategoryQualifyLines">A qualify line data accessor.</param>
        public DiscountQuantityFilter(IDataAccessorDiscountQualifyLines dataAccessorCategoryQualifyLines)
        {
            this.dataAccessor = dataAccessorCategoryQualifyLines;
        }

        /// <summary>
        /// Filter the discounts.
        /// </summary>
        /// <param name="discounts">The discounts list.</param>
        /// <param name="discountableItemGroups">The item group.</param>
        /// <param name="priceContext">The price context.</param>
        /// <returns>A list of qualified discounts.</returns>
        public IEnumerable<DiscountBase> Filter(IEnumerable<DiscountBase> discounts, DiscountableItemGroup[] discountableItemGroups, PriceContext priceContext)
        {
            if (discounts == null || !discounts.Any())
            {
                return Enumerable.Empty<DiscountBase>();
            }

            var offerIds = discounts.Select(discount => discount.OfferId);
            // Get qualify lines.
            var qualifyLines = this.dataAccessor.GetQualifyLinesByOfferIds(offerIds);
            // Filter discounts.
            ISet<string> invalidOfferIds = new HashSet<string>();
            var lineLookup = qualifyLines.ToLookup(line => line.OfferId);
            return discounts
                    .Where(discount =>
                            lineLookup[discount.OfferId].All(line =>
                                QuantityQualifyLineHelper.IsQualifyLineSatisfied(discountableItemGroups, line, this.dataAccessor)));
        }
    }
}
