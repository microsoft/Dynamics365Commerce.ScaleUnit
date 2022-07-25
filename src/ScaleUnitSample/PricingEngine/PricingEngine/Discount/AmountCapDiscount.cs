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
    using System.Text;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine.DiscountData;

    /// <summary>
    /// Amount cap discount class.
    /// For the sample, it caps for all the items covered by the discount.
    /// </summary>
    /// <remarks>
    /// It implements IDiscountPostBestDeal instead of IDiscountForBestDeal.
    /// See <see href="https://blogs.msdn.microsoft.com/retaillife/2017/02/17/dynamics-retail-discount-extensibility-idiscountforbestdeal-i//">Dynamics Retail Discount Extensibility – IDiscountForBestDeal I</see>.
    /// </remarks>
    public class AmountCapDiscount : DiscountBase, IDiscountPostBestDeal
    {
        private EffectiveDiscountMethodForOrdering? effectiveDiscountMethod;

        /// <summary>
        /// Initializes a new instance of the <see cref="AmountCapDiscount" /> class.
        /// </summary>
        /// <param name="validationPeriod">The validation period.</param>
        public AmountCapDiscount(ValidationPeriod validationPeriod) : base(validationPeriod)
        {
        }

        /// <summary>Gets effective discount method for ordering.</summary>
        /// <remarks>
        /// Used only in concurrency control model of best price and compound within priority and no compound across.
        /// We process compoundable discounts in following order: offer/unit/deal price, amount off and percentage off.
        /// See <see href="https://blogs.msdn.microsoft.com/retaillife/2017/04/04/dynamics-retail-discount-concept-effective-discount-method-for-compound-ordering/">Dynamics Retail Discount Concept: Effective Discount Method for Compound Ordering</see>.
        /// </remarks>
        public override EffectiveDiscountMethodForOrdering EffectiveDiscountMethodForOrdering
        {
            get
            {
                if (!this.effectiveDiscountMethod.HasValue)
                {
                    EffectiveDiscountMethodForOrdering effective = EffectiveDiscountMethodForOrdering.PercentageOff;
                    foreach (KeyValuePair<decimal, RetailDiscountLine> pair in this.DiscountLines)
                    {
                        RetailDiscountLine line = pair.Value;
                        DiscountOfferMethod discountMethod = (DiscountOfferMethod)line.DiscountMethod;

                        if (discountMethod == DiscountOfferMethod.OfferPrice)
                        {
                            effective = EffectiveDiscountMethodForOrdering.DealPriceOrUnitPrice;
                        }
                        else if (discountMethod == DiscountOfferMethod.DiscountAmount && effective == EffectiveDiscountMethodForOrdering.PercentageOff)
                        {
                            effective = EffectiveDiscountMethodForOrdering.AmountOff;
                        }
                    }

                    this.effectiveDiscountMethod = effective;
                }

                return this.effectiveDiscountMethod.Value;
            }
        }

        /// <summary>Gets or sets the discount amount cap.</summary>
        /// <remarks>For sample, the cap is for all items covered by the discount. If you need more fine-grained cap, introduce additional data structure to manage the cap.</remarks>
        public decimal DiscountAmountCap { get; set; }

        /// <summary>Gets or sets a value indicating whether this discount reduces the discount base amount for the discounts in the lower priority.</summary>
        /// <remarks>See BaseReductionForAmountCapDiscountBaseAmountCalculator.</remarks>
        public bool ApplyBaseReduction { get; set; }

        /// <summary>
        /// To string.
        /// </summary>
        /// <returns>String representation.</returns>
        public override string ToString()
        {
            StringBuilder builder = new StringBuilder(base.ToString());

            builder.AppendFormat(" Cap [${0:0.##}]", this.DiscountAmountCap);
            builder.AppendFormat(" Apply base reduction? [{0}]", this.ApplyBaseReduction);

            return builder.ToString();
        }

        /// <summary>
        /// Before we evaluate discounts, each discount can build up additional lookup tables and streamline them.
        /// </summary>
        /// <param name="discountableItemGroups">The valid sales line items on the transaction to consider.</param>
        /// <param name="remainingQuantities">The remaining quantities of each of the sales lines to consider.</param>
        /// <param name="priceContext">Price context.</param>
        /// <param name="itemsWithOverlappingDiscounts">Items with overlapping discounts.</param>
        /// <param name="itemsWithOverlappingDiscountsCompoundedOnly">Hast set of overlapped item group indices, compounded only.</param>
        /// <returns>Whether items have been removed.</returns>
        /// <remarks>We may run this more than once, and please make sure it can handle it.</remarks>
        public override bool BuildAndStreamlineLookups(DiscountableItemGroup[] discountableItemGroups, decimal[] remainingQuantities, PriceContext priceContext, HashSet<int> itemsWithOverlappingDiscounts, HashSet<int> itemsWithOverlappingDiscountsCompoundedOnly)
        {
            this.RemoveItemGroupIndexesWithZeroQuanttiyFromLookups(remainingQuantities);

            this.ReduceWorseDiscountLines(discountableItemGroups, priceContext);

            this.CleanupLookups();

            return false;
        }

        /// <summary>
        /// Applies the discount application and gets the value, taking into account previously applied discounts.
        /// </summary>
        /// <param name="discountableItemGroups">The transaction line items.</param>
        /// <param name="remainingQuantities">The quantities remaining for each item.</param>
        /// <param name="appliedDiscounts">The previously applied discounts.</param>
        /// <param name="discountApplication">The specific application of the discount to use.</param>
        /// <param name="priceContext">The pricing context to use.</param>
        /// <returns>The value of the discount application.</returns>
        /// <remarks>In compounded case, the result may depends on previously applied compounded discounts on the same items.</remarks>
        public override AppliedDiscountApplication CreateAppliedDiscountApplication(
            DiscountableItemGroup[] discountableItemGroups,
            decimal[] remainingQuantities,
            IEnumerable<AppliedDiscountApplication> appliedDiscounts,
            DiscountApplication discountApplication,
            PriceContext priceContext)
        {
            ThrowIf.Null(discountApplication, "discountApplication");
            ThrowIf.Null(discountableItemGroups, "discountableItemGroups");
            ThrowIf.Null(remainingQuantities, "remainingQuantities");
            ThrowIf.Null(priceContext, "priceContext");

            if (!discountApplication.RetailDiscountLines.Any())
            {
                return null;
            }

            Dictionary<int, decimal> prices = new Dictionary<int, decimal>();

            // step 1: calculate the total discount amount to be applied
            decimal totalDiscountAmountToBeApplied = this.TotalDiscountAmountToBeApplied(
                discountableItemGroups,
                remainingQuantities,
                appliedDiscounts,
                discountApplication,
                prices,
                priceContext);

#if DEBUG
            System.Diagnostics.Debug.WriteLine("Total discount to be applied = {0} / Amount cap = {1}", totalDiscountAmountToBeApplied, this.DiscountAmountCap);
#endif

            bool discountWasCapped = false;
            decimal totalDiscount = 0;

            // step 2: figure out if the amount cap should be applied
            if (totalDiscountAmountToBeApplied > this.DiscountAmountCap)
            {
                totalDiscount = Math.Min(totalDiscountAmountToBeApplied, this.DiscountAmountCap);
                discountWasCapped = true;
            }
            else
            {
                totalDiscount = totalDiscountAmountToBeApplied;
            }

            if (totalDiscount > decimal.Zero)
            {
                Dictionary<int, decimal> itemQuantities = discountApplication.ItemQuantities;

                AppliedDiscountApplication newAppliedDiscountApplication = new AppliedDiscountApplication(discountApplication, totalDiscount, itemQuantities);

                // step 3: cap was reached and rounding is required
                if (discountWasCapped)
                {
                    // See https://blogs.msdn.microsoft.com/retaillife/2017/04/04/dynamics-retail-discount-sample-rounding/
                    // Please note that rounding is handled slightly differently here.
                    // step 3.1: calculate the total sales price, this will be needed to allocate the discount amounts proportionally
                    var totalPrice = 0m;
                    foreach (var keyValuePair in prices)
                    {
                        totalPrice += keyValuePair.Value * discountApplication.ItemQuantities[keyValuePair.Key];
                    }

                    // step 3.2: allocate each discountable item group a part of discount amount, proportional to its price
                    var amountAllocatedToItemGroup = new Dictionary<int, decimal>();
                    var totalAmountAllocated = 0m;

                    var itemCountParticipatingOnDiscount = discountApplication.ItemQuantities.Count;
                    for (int i = 0; i < itemCountParticipatingOnDiscount; i++)
                    {
                        var keyValuePair = discountApplication.ItemQuantities.ElementAt(i);
                        var itemGroupIndex = keyValuePair.Key;
                        var quantity = keyValuePair.Value;

                        var currentPrice = prices[itemGroupIndex] * quantity;
                        var ratio = currentPrice / totalPrice;

                        decimal amountToAllocate;
                        if (i < itemCountParticipatingOnDiscount - 1)
                        {
                            amountToAllocate = priceContext.CurrencyAndRoundingHelper.Round(totalDiscount * ratio);
                            totalAmountAllocated += amountToAllocate;
                        }
                        else
                        {
                            // last element, allocate the remaining here.
                            amountToAllocate = totalDiscount - totalAmountAllocated;
                        }

                        amountAllocatedToItemGroup[itemGroupIndex] = amountToAllocate;
                    }

                    // step 3.3: given the amounts allocated to each item, create the discount lines
                    foreach (var pair in discountApplication.ItemQuantities)
                    {
                        int itemGroupIndex = pair.Key;
                        var currentDiscountableItemGroup = discountableItemGroups[itemGroupIndex];
                        var quantity = pair.Value;

                        DiscountLine discountLine = this.NewDiscountLine(discountApplication.DiscountCode, currentDiscountableItemGroup.ItemId);
                        discountLine.ExtensiblePeriodicDiscountType = ContosoPeriodicDiscountOfferType.AmountCap;

                        var amountAllocatedForThisDiscount = amountAllocatedToItemGroup[itemGroupIndex];

                        var amountPerUnit = amountAllocatedForThisDiscount / quantity;
                        var amountPerUnitRounded = priceContext.CurrencyAndRoundingHelper.Round(amountPerUnit);

                        if (PricingArithmetics.IsFraction(currentDiscountableItemGroup.Quantity) || priceContext.HoldTogetherForDiscountRounding)
                        {
                            // step 3.3.1: assigned all discount amount to the discount item group.
                            discountLine.DealPrice = 0m;
                            discountLine.Amount = amountPerUnit;
                            discountLine.Percentage = 0m;
                            discountLine.EffectiveAmount = amountAllocatedForThisDiscount;

                            // If the discount item group has multiple sales lines, the discount totaler will handle additional rounding when requiresFurtherRounding = true
                            newAppliedDiscountApplication.AddDiscountLine(itemGroupIndex, new DiscountLineQuantity(discountLine, quantity, requiresFurtherRounding: true));
                        }
                        else
                        {
                            // step 3.3.2: rounding should be performed here, allocate amount properly in 2 discount lines
                            var remainingAmount = amountAllocatedForThisDiscount - (amountPerUnitRounded * quantity);

                            var sign = Math.Sign(remainingAmount);
                            remainingAmount = Math.Abs(remainingAmount);

                            var smallestAmount = PriceContextHelper.GetSmallestNonNegativeAmount(priceContext, amountAllocatedForThisDiscount);

                            var quantitySplitForAdjustment = Convert.ToInt32(remainingAmount / smallestAmount);
                            var quantityNoAdjustment = quantity - quantitySplitForAdjustment;

                            if (quantityNoAdjustment > decimal.Zero)
                            {
                                discountLine.DealPrice = 0m;
                                discountLine.Amount = amountPerUnitRounded;
                                discountLine.Percentage = 0m;
                                discountLine.EffectiveAmount = discountLine.Amount * quantityNoAdjustment;
                                newAppliedDiscountApplication.AddDiscountLine(itemGroupIndex, new DiscountLineQuantity(discountLine, quantityNoAdjustment));
                            }

                            if (quantitySplitForAdjustment > decimal.Zero)
                            {
                                var discountLineWithRoundingAdj = new DiscountLine();
                                discountLineWithRoundingAdj.CopyFrom(discountLine);
                                discountLineWithRoundingAdj.Amount = amountPerUnitRounded + (smallestAmount * sign);
                                discountLineWithRoundingAdj.EffectiveAmount = discountLineWithRoundingAdj.Amount * quantitySplitForAdjustment;
                                newAppliedDiscountApplication.AddDiscountLine(itemGroupIndex, new DiscountLineQuantity(discountLineWithRoundingAdj, quantitySplitForAdjustment));
                            }
                        }
                    }
                }
                else
                {
                    // step 4: cap has no effect, so it's treated as a simple discount.
                    foreach (var retailDiscountLineItem in discountApplication.RetailDiscountLines)
                    {
                        var itemGroupIndex = retailDiscountLineItem.ItemGroupIndex;
                        var currentDiscountableItemGroup = discountableItemGroups[itemGroupIndex];

                        var discountValue = OfferDiscount.GetDiscountValueFromDefinition(
                            itemGroupIndex,
                            retailDiscountLineItem.RetailDiscountLine,
                            currentDiscountableItemGroup.DiscountBaseAmount,
                            prices,
                            priceContext);

                        DiscountLine discountLine = this.NewDiscountLine(discountApplication.DiscountCode, currentDiscountableItemGroup.ItemId);
                        DiscountOfferMethod discountMethod = (DiscountOfferMethod)retailDiscountLineItem.RetailDiscountLine.DiscountMethod;

                        discountLine.ExtensiblePeriodicDiscountType = ContosoPeriodicDiscountOfferType.AmountCap;
                        discountLine.DealPrice = retailDiscountLineItem.RetailDiscountLine.OfferPrice;
                        discountLine.Amount = discountMethod == DiscountOfferMethod.OfferPrice ? discountValue : retailDiscountLineItem.RetailDiscountLine.DiscountAmount;
                        discountLine.Percentage = retailDiscountLineItem.RetailDiscountLine.DiscountPercent;
                        discountLine.EffectiveAmount = totalDiscount;

                        newAppliedDiscountApplication.AddDiscountLine(itemGroupIndex, new DiscountLineQuantity(discountLine, itemQuantities[itemGroupIndex]));
                    }
                }

                if (discountApplication.RemoveItemsFromLookupsWhenApplied)
                {
                    foreach (var retailDiscountLineItem in discountApplication.RetailDiscountLines)
                    {
                        this.RemoveItemIndexGroupFromLookups(retailDiscountLineItem.ItemGroupIndex);
                    }
                }

                return newAppliedDiscountApplication;
            }

            return null;
        }

        /// <summary>
        /// Get discount application multiples.
        /// </summary>
        /// <param name="discountableItemGroups">Discountable item groups.</param>
        /// <param name="remainingQuantities">Remaining quantities.</param>
        /// <param name="appliedDiscountApplications">Applied discount applications.</param>
        /// <param name="priceContext">Price context.</param>
        /// <returns>A collection of discount application multiples.</returns>
        /// <remarks>
        /// We put all items in one discount application. This is necessary for rounding. The alternative is to have one discount application for one item.
        /// See rounding in CreateAppliedDiscountApplication.
        /// </remarks>
        public List<DiscountApplicationMultiple> GetDiscountApplicationMultiples(
            DiscountableItemGroup[] discountableItemGroups,
            decimal[] remainingQuantities,
            List<AppliedDiscountApplication> appliedDiscountApplications,
            PriceContext priceContext)
        {
            ThrowIf.Null(discountableItemGroups, "discountableItemGroups");
            ThrowIf.Null(remainingQuantities, "remainingQuantities");
            ThrowIf.Null(priceContext, "priceContext");

            List<DiscountApplicationMultiple> multiples = new List<DiscountApplicationMultiple>();

            DiscountApplication discountApplication = new DiscountApplication(this);
            foreach (KeyValuePair<int, HashSet<decimal>> pair in this.ItemGroupIndexToDiscountLineNumberSetMap)
            {
                int itemGroupIndex = pair.Key;
                HashSet<decimal> discountLineNumberSet = pair.Value;
                decimal quantity = remainingQuantities[itemGroupIndex];
                if (quantity > decimal.Zero && discountLineNumberSet != null && discountLineNumberSet.Count > 0)
                {
                    // We have already reduced discount line numbers per item group index to 1.
                    RetailDiscountLine discountLineDefinition = this.DiscountLines[discountLineNumberSet.ElementAt(0)];
                    discountApplication.RetailDiscountLines.Add(new RetailDiscountLineItem(itemGroupIndex, discountLineDefinition));
                    discountApplication.ItemQuantities.Add(itemGroupIndex, quantity);
                }
            }

            discountApplication.RemoveItemsFromLookupsWhenApplied = true;

            if (discountApplication != null)
            {
                multiples.Add(new DiscountApplicationMultiple(discountApplication, 1));
            }

            return multiples;
        }

        /// <summary>
        /// Gets the discount deal estimate.
        /// </summary>
        /// <param name="discountableItemGroups">The valid sales line items on the transaction to consider.</param>
        /// <param name="remainingQuantities">The remaining quantities of each of the sales lines to consider.</param>
        /// <param name="appliedDiscountApplications">Applied discount applications.</param>
        /// <param name="itemsWithOverlappingDiscounts">Items with overlapping discounts.</param>
        /// <param name="itemsWithOverlappingDiscountsCompoundedOnly">Hast set of overlapped item group indices, compounded only.</param>
        /// <param name="priceContext">Price Context.</param>
        /// <returns>Discount deal estimate.</returns>
        /// <remarks>
        /// If it overlaps with another post-best-deal discount of the same priority, then we need to decide which one to evaluate first.
        /// See <see href="https://blogs.msdn.microsoft.com/retaillife/2017/02/19/dynamics-retail-discount-concepts-discount-deal-estimate/">Dynamics Retail discount concept: discount deal estimate</see>.
        /// </remarks>
        public DiscountDealEstimate GetDiscountDealEstimate(DiscountableItemGroup[] discountableItemGroups, decimal[] remainingQuantities, List<AppliedDiscountApplication> appliedDiscountApplications, HashSet<int> itemsWithOverlappingDiscounts, HashSet<int> itemsWithOverlappingDiscountsCompoundedOnly, PriceContext priceContext)
        {
            ThrowIf.Null(discountableItemGroups, "discountableItemGroups");
            ThrowIf.Null(remainingQuantities, "remainingQuantities");
            ThrowIf.Null(itemsWithOverlappingDiscounts, "itemsWithOverlappingDiscounts");
            ThrowIf.Null(itemsWithOverlappingDiscountsCompoundedOnly, "itemsWithOverlappingDiscountsCompoundedOnly");

            Dictionary<int, decimal> itemGroupIndexToQuantityNeededFromOverlappedLookup = new Dictionary<int, decimal>();

            decimal totalDiscountAmountWithOverlapped = decimal.Zero;
            decimal totalDiscountAmountWithoutOverlapped = decimal.Zero;

            foreach (KeyValuePair<int, HashSet<decimal>> pair in this.ItemGroupIndexToDiscountLineNumberSetMap)
            {
                int itemGroupIndex = pair.Key;
                HashSet<decimal> discountLineNumberSet = pair.Value;
                decimal quantity = remainingQuantities[itemGroupIndex];
                if (quantity > decimal.Zero)
                {
                    decimal price = discountableItemGroups[itemGroupIndex].DiscountBaseAmount;
                    decimal unitDiscountAmount = decimal.Zero;

                    if (discountLineNumberSet.Any())
                    {
                        unitDiscountAmount = GetUnitDiscountAmount(this.DiscountLines[discountLineNumberSet.First()], price, price, priceContext);
                    }

                    decimal effectiveDiscountAmount = unitDiscountAmount * quantity;

                    totalDiscountAmountWithOverlapped += effectiveDiscountAmount;

                    if (this.IsItemIndexGroupOverlappedWithNonCompoundedDiscounts(itemGroupIndex, itemsWithOverlappingDiscounts, itemsWithOverlappingDiscountsCompoundedOnly))
                    {
                        itemGroupIndexToQuantityNeededFromOverlappedLookup[itemGroupIndex] = quantity;
                    }
                    else
                    {
                        totalDiscountAmountWithoutOverlapped += effectiveDiscountAmount;
                    }
                }
            }

            totalDiscountAmountWithoutOverlapped = Math.Min(totalDiscountAmountWithoutOverlapped, this.DiscountAmountCap);
            totalDiscountAmountWithOverlapped = Math.Min(totalDiscountAmountWithOverlapped, this.DiscountAmountCap);

            DiscountDealEstimate estimate = new DiscountDealEstimate(
                this.CanCompound,
                this.OfferId,
                totalDiscountAmountWithOverlapped,
                totalDiscountAmountWithoutOverlapped,
                itemGroupIndexToQuantityNeededFromOverlappedLookup);

            return estimate;
        }

        private static decimal GetUnitDiscountAmount(RetailDiscountLine discountLineDefinition, decimal originalPrice, decimal price, PriceContext priceContext)
        {
            return PricingArithmetics.GetUnitDiscountAmount(
                (DiscountOfferMethod)discountLineDefinition.DiscountMethod,
                discountLineDefinition.OfferPrice,
                discountLineDefinition.DiscountAmount,
                discountLineDefinition.DiscountPercent,
                originalPrice,
                price,
                priceContext);
        }

        private decimal TotalDiscountAmountToBeApplied(
            DiscountableItemGroup[] discountableItemGroups,
            decimal[] remainingQuantities,
            IEnumerable<AppliedDiscountApplication> appliedDiscounts,
            DiscountApplication discountApplication,
            Dictionary<int, decimal> prices,
            PriceContext priceContext)
        {
            this.CalculateDiscountedPricesAndPopulateBestDealPriceLookup(
                discountableItemGroups,
                remainingQuantities,
                appliedDiscounts,
                discountApplication,
                prices);

            var totalAmountToBeApplied = 0m;

            foreach (var retailDiscountLineItem in discountApplication.RetailDiscountLines)
            {
                var itemGroupIndex = retailDiscountLineItem.ItemGroupIndex;

                var currentDiscountableItemGroup = discountableItemGroups[itemGroupIndex];

                var discountValue = OfferDiscount.GetDiscountValueFromDefinition(
                    itemGroupIndex,
                    retailDiscountLineItem.RetailDiscountLine,
                    currentDiscountableItemGroup.DiscountBaseAmount,
                    prices,
                    priceContext);

                totalAmountToBeApplied += discountValue * discountApplication.ItemQuantities[itemGroupIndex];
            }

            return totalAmountToBeApplied;
        }

        private void ReduceWorseDiscountLines(
            DiscountableItemGroup[] discountableItemGroups,
            PriceContext priceContext)
        {
            // If an item is covered by multiple line definitions of the same discount, we reduce it to 1 per item.
            foreach (KeyValuePair<int, HashSet<decimal>> pair in this.ItemGroupIndexToDiscountLineNumberSetMap)
            {
                int itemGroupIndex = pair.Key;
                HashSet<decimal> discountLineNumberSet = pair.Value;

                if (discountLineNumberSet.Count > 1)
                {
                    decimal discountLineNumberToKeep = decimal.Zero;
                    decimal bestUnitDiscountAmount = decimal.Zero;
                    bool isFirst = true;

                    decimal price = discountableItemGroups[itemGroupIndex].DiscountBaseAmount;
                    foreach (decimal discountLineNumber in discountLineNumberSet)
                    {
                        RetailDiscountLine discountLine = this.DiscountLines[discountLineNumber];
                        decimal unitDiscountAmount = GetUnitDiscountAmount(discountLine, price, price, priceContext);
                        if (isFirst)
                        {
                            discountLineNumberToKeep = discountLineNumber;
                            bestUnitDiscountAmount = unitDiscountAmount;
                            isFirst = false;
                        }
                        else if (unitDiscountAmount > bestUnitDiscountAmount)
                        {
                            discountLineNumberToKeep = discountLineNumber;
                            bestUnitDiscountAmount = unitDiscountAmount;
                        }
                    }

                    foreach (decimal discountLineNumber in discountLineNumberSet)
                    {
                        if (discountLineNumber != discountLineNumberToKeep)
                        {
                            HashSet<int> itemGroupIndexSetForDiscountLineNumber = null;
                            if (this.DiscountLineNumberToItemGroupIndexSetMap.TryGetValue(discountLineNumber, out itemGroupIndexSetForDiscountLineNumber))
                            {
                                itemGroupIndexSetForDiscountLineNumber.Remove(itemGroupIndex);
                            }
                        }
                    }

                    discountLineNumberSet.Clear();
                    discountLineNumberSet.Add(discountLineNumberToKeep);
                }
            }
        }
    }
}
