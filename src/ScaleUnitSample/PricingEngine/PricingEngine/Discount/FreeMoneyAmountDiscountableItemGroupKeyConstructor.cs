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
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine;

    /// <summary>
    /// A <see cref="DiscountableItemGroupKeyConstructor" /> that also uses a custom property to build the key.
    /// </summary>
    public class FreeMoneyAmountDiscountableItemGroupKeyConstructor : DiscountableItemGroupKeyConstructor
    {
        /// <summary>
        /// This is the name of the property where the "free money" amount should be set.
        /// </summary>
        public const string FreeMoneyAmountPropertyName = "FreeMoneyAmount";

        /// <summary>
        /// Constructs the group key for a sales line.
        /// </summary>
        /// <param name="salesLine">Sales line.</param>
        /// <returns>Group key.</returns>
        /// <remarks>Sales lines of the same group key will be grouped into one discountable item group.</remarks>
        public override string ConstructGroupKey(SalesLine salesLine)
        {
            ThrowIf.Null(salesLine, "salesLine");

            var freeMoneyAmount = salesLine.GetProperty(FreeMoneyAmountPropertyName) ?? decimal.Zero;

            return string.Concat(base.ConstructGroupKey(salesLine), freeMoneyAmount);
        }
    }
}
