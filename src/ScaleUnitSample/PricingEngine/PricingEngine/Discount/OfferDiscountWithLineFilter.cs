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
    /// Offer discount with additional validation of validation period on discount line.
    /// </summary>
    /// <remarks>
    /// We have extended OfferDiscount by adding additional line level validation.
    /// Unfortunately in this case, you will have to extend all retail discount types:
    /// mix and match, quantity discount and threshold discount to enable it for all. 
    /// </remarks>
    public class OfferDiscountWithLineFilter : OfferDiscount
    {
        internal const string StringExtensionLinePeriod = "ExtensionLinePeriod";

        /// <summary>
        /// Initializes a new instance of the <see cref="OfferDiscountWithLineFilter" /> class.
        /// </summary>
        /// <param name="validationPeriod">Validation period.</param>
        public OfferDiscountWithLineFilter(ValidationPeriod validationPeriod)
            : base(validationPeriod)
        {
        }

        /// <summary>
        /// Pre optimization.
        /// </summary>
        /// <param name="discountableItemGroups">The valid sales line items on the transaction to consider.</param>
        /// <param name="remainingQuantities">The remaining quantities of each of the sales lines to consider.</param>
        /// <param name="priceContext">Price context.</param>
        /// <param name="itemsWithOverlappingDiscounts">Items with overlapping discounts.</param>
        /// <param name="itemsWithOverlappingDiscountsCompoundedOnly">Items with overlapping discounts, compounded only.</param>
        /// <returns>Whether items have been removed.</returns>
        public override bool BuildAndStreamlineLookups(
            DiscountableItemGroup[] discountableItemGroups,
            decimal[] remainingQuantities,
            PriceContext priceContext,
            HashSet<int> itemsWithOverlappingDiscounts,
            HashSet<int> itemsWithOverlappingDiscountsCompoundedOnly)
        {
            ThrowIf.Null(priceContext, "priceContext");

            bool isItemRemoved = false;

            HashSet<decimal> discountLineNumbersToRemove = new HashSet<decimal>();
            foreach (KeyValuePair<decimal, HashSet<int>> pair in this.DiscountLineNumberToItemGroupIndexSetMap)
            {
                decimal discountLineNumber = pair.Key;
                RetailDiscountLine retailDiscountLine = this.DiscountLines[discountLineNumber];

                ValidationPeriod lineValidationPeriod = retailDiscountLine.GetProperty(StringExtensionLinePeriod) as ValidationPeriod;
                if (lineValidationPeriod != null &&
                    ValidationPeriodValidator.ValidateDateAgainstValidationPeriod(DateValidationType.Advanced, lineValidationPeriod, lineValidationPeriod.ValidFrom, lineValidationPeriod.ValidTo, priceContext.ActiveDate))
                {
                    discountLineNumbersToRemove.Add(pair.Key);
                    isItemRemoved = true;
                }
            }

            this.RemoveDiscountLineNumbersFromLookups(discountLineNumbersToRemove);

            isItemRemoved |= base.BuildAndStreamlineLookups(discountableItemGroups, remainingQuantities, priceContext, itemsWithOverlappingDiscounts, itemsWithOverlappingDiscountsCompoundedOnly);

            return isItemRemoved;
        }
    }
}
