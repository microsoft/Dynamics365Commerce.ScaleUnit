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
     using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine.DiscountData;
     using System.Linq;

    /// <summary>
    /// Qualify line filter helper class.
    /// </summary>
    internal static class QuantityQualifyLineHelper
    {
        /// <summary>
        /// Determine if a qualify line is satisfied.
        /// </summary>
        /// <param name="discountableItemGroups">The item group.</param>
        /// <param name="qualifyLine">The qualify line</param>
        /// <param name="qualifyLineDataAccessor">The qualify line data accessor.</param>
        /// <returns>A bool value to indicate if a qualify line is satisfied.</returns>
        public static bool IsQualifyLineSatisfied(
            DiscountableItemGroup[] discountableItemGroups,
            DiscountQualifyLine qualifyLine,
            IDataAccessorDiscountQualifyLines qualifyLineDataAccessor)
        {
            if (qualifyLine == null || qualifyLine.Quantity <= 0 || (qualifyLine.ProductId == 0 && qualifyLine.CategoryId == 0))
            {
                return true;
            }

            if (null == discountableItemGroups || 0 == discountableItemGroups.Length)
            {
                return false;
            }

            var requiredProductId = qualifyLine.ProductId;
            if (requiredProductId != 0)
            {

                var quantityRequiredProductInItemGroups = discountableItemGroups
                    .Where(itemGroup => itemGroup.ProductId == requiredProductId)
                    .Sum(itemGroup => itemGroup.Quantity);

                return quantityRequiredProductInItemGroups >= qualifyLine.Quantity;
            }

            var requiredCategoryId = qualifyLine.CategoryId;
            var quantityRequiredForCategory = discountableItemGroups
                    .Where(itemGroup => itemGroup.Quantity > 0)
                    // TODO: You should never call data accessor in a loop in production environment.
                    // This is just a demo of discount filter implementation.
                    .Where(itemGroup => qualifyLineDataAccessor.IsProductInCategory(itemGroup.ProductId, requiredCategoryId))
                    .Sum(itemGroup => itemGroup.Quantity);
            return quantityRequiredForCategory >= qualifyLine.Quantity;
        }
    }
}
