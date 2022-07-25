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
    using System.Collections.Generic;
    using System.Linq;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine.DiscountData;

    /// <summary>
    /// A discount base amount calculator that, given an amount cap discount that applies base reduction, changes the discount base amount of subsequently discount calculations.
    /// </summary>
    public class BaseReductionForAmountCapDiscountBaseAmountCalculator : IPriorityDiscountBaseAmountCalculator
    {
        /// <summary>
        /// Gets the discount base amount.
        /// </summary>
        /// <param name="discountItemGroup">Discountable item group.</param>
        /// <param name="priceContext">Price context.</param>
        /// <returns>Discount base amount.</returns>
        public decimal GetDiscountBaseAmount(DiscountableItemGroup discountItemGroup, PriceContext priceContext)
        {
            ThrowIf.Null(discountItemGroup, "discountItemGroup");

            var salesLine = discountItemGroup[0];

            return discountItemGroup.Price - GetFreeMoneyAmount(salesLine);
        }

        /// <summary>
        /// Calculate priority discount base amount.
        /// </summary>
        /// <param name="currentPriority">Current priority.</param>
        /// <param name="discountItemGroup">Discountable item group.</param>
        /// <param name="itemGroupIndex">Item group index.</param>
        /// <param name="appliedDiscountApplications">Applied discount applications.</param>
        /// <param name="existingPriorityDiscountBaseAmounts">Existing priority discount base amounts.</param>
        /// <param name="priceContext">Price context.</param>
        /// <returns>Discount base amount for the priority.</returns>
        /// <remarks>
        /// For now, we cover only one scenario:
        /// * Simple discount with amount cap with %-off.
        /// * Only a single offer in the transaction can have the ApplyBaseReduction flag set to true.
        /// </remarks>
        public decimal CalculatePriorityDiscountBaseAmount(int currentPriority, DiscountableItemGroup discountItemGroup, int itemGroupIndex, IReadOnlyCollection<AppliedDiscountApplication> appliedDiscountApplications, IReadOnlyCollection<PriorityDiscountBaseAmount> existingPriorityDiscountBaseAmounts, PriceContext priceContext)
        {
            ThrowIf.Null(discountItemGroup, "discountItemGroup");
            ThrowIf.Null(priceContext, "priceContext");

            decimal discountBaseAmount = discountItemGroup.DiscountBaseAmount;
            decimal appliedBaseAmount = decimal.Zero;

            var appliedForOffer = appliedDiscountApplications.Where(a => OfferShouldReduceDiscountBaseAmount(itemGroupIndex, a)).ToList();

            if (appliedForOffer.Count != 0)
            {
                var applied = appliedForOffer.First();

                var discountLineQuantityList = applied.ItemGroupIndexToDiscountLineQuantitiesLookup[itemGroupIndex];

                decimal totalDiscountEffectiveAmount = discountLineQuantityList.Sum(dlq => dlq.DiscountLine.EffectiveAmount);
                decimal totalDiscountQuantity = discountLineQuantityList.Sum(dlq => dlq.Quantity);

                if (totalDiscountQuantity > decimal.Zero)
                {
                    var retailDiscountLineItem = applied.DiscountApplication.RetailDiscountLines.First();
                    var retailDiscountLine = retailDiscountLineItem.RetailDiscountLine;

                    // For now, we assume it's %-off.
                    if ((DiscountOfferMethod)retailDiscountLine.DiscountMethod == DiscountOfferMethod.DiscountPercent && retailDiscountLine.DiscountPercent > decimal.Zero)
                    {
                        appliedBaseAmount = (totalDiscountEffectiveAmount / totalDiscountQuantity) / (retailDiscountLine.DiscountPercent / 100);
                        appliedBaseAmount = priceContext.CurrencyAndRoundingHelper.Round(appliedBaseAmount);
                    }

                    discountBaseAmount -= appliedBaseAmount;
                    discountBaseAmount = Math.Max(decimal.Zero, discountBaseAmount);
                }
            }

            return discountBaseAmount;
        }

        /// <summary>
        /// Default calculation won't use this base amount for threshold calculation.
        /// </summary>
        /// <returns>PriorityDiscountBaseAmountCalculator returns false.</returns>
        public bool ShouldOverrideDiscountBaseAmountForThresholds()
        {
            return false;
        }

        private static bool OfferShouldReduceDiscountBaseAmount(int itemGroupIndex, AppliedDiscountApplication a)
        {
            var discount = a.DiscountApplication.Discount as AmountCapDiscount;

            if (discount == null)
            {
                return false;
            }

            return a.ItemGroupIndexToDiscountLineQuantitiesLookup.ContainsKey(itemGroupIndex) && discount.ApplyBaseReduction;
        }

        private static decimal GetFreeMoneyAmount(SalesLine salesLine)
        {
            if (salesLine.GetProperties().ContainsKey(FreeMoneyAmountDiscountableItemGroupKeyConstructor.FreeMoneyAmountPropertyName))
            {
                return (decimal)salesLine.GetProperty(FreeMoneyAmountDiscountableItemGroupKeyConstructor.FreeMoneyAmountPropertyName);
            }
            else
            {
                return decimal.Zero;
            }
        }
    }
}
