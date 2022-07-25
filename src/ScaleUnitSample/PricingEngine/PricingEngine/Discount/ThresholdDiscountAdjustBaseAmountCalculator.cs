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
    public class ThresholdDiscountAdjustBaseAmountCalculator : IPriorityDiscountBaseAmountCalculator
    {
        private string TargetOfferId;
        public ThresholdDiscountAdjustBaseAmountCalculator(string targetOfferId)
        {
            this.TargetOfferId = targetOfferId;
        }

        /// <summary>
        /// Gets the discount base amount.
        /// </summary>
        /// <param name="discountItemGroup">Discountable item group.</param>
        /// <param name="priceContext">Price context.</param>
        /// <returns>Discount base amount.</returns>
        public decimal GetDiscountBaseAmount(DiscountableItemGroup discountItemGroup, PriceContext priceContext)
        {
            ThrowIf.Null(discountItemGroup, "discountItemGroup");

            decimal baseAmount = discountItemGroup[0].Price;
            return baseAmount;
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

            var appliedForOffer = appliedDiscountApplications.Where(a => OfferShouldReduceDiscountBaseAmount(itemGroupIndex, a)).ToList();
            if (appliedDiscountApplications != null && appliedDiscountApplications.Count > 0)
            {
                bool shouldReduce = OfferShouldReduceDiscountBaseAmount(itemGroupIndex, appliedDiscountApplications.ToArray()[appliedDiscountApplications.Count - 1]);
                var salesLine = discountItemGroup[0];
                if (shouldReduce)
                {
                    discountBaseAmount = 1000m;
                }
            }

            return discountBaseAmount;
        }

        private bool OfferShouldReduceDiscountBaseAmount(int itemGroupIndex, AppliedDiscountApplication a)
        {
            bool ret = false;

            var discount = a.DiscountApplication.Discount;
            if (discount.OfferId == TargetOfferId)
            {
                ret = true;
            }

            return ret;
        }

        /// <summary>
        /// The base amount of this calculator will be used for threshold calculation.
        /// </summary>
        /// <returns>returns true.</returns>
        public bool ShouldOverrideDiscountBaseAmountForThresholds()
        {
            return true;
        }
    }
}
