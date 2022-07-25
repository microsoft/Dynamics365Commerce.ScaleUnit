/**
* SAMPLE CODE NOTICE
* 
* THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
* OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
* THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
* NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
*/

using System.Threading.Tasks;

namespace Contoso.CommerceRuntime.PricingEngine
{
    using System.Collections.Generic;

    /// <summary>
    /// Discount qualify lines data accessor interface.
    /// </summary>
    /// <remarks>Data accessor interface to support both Channel and AX.</remarks>
    public interface IDataAccessorDiscountQualifyLines
    {
        /// <summary>
        /// Check if a product is belong to a category.
        /// </summary>
        /// <param name="productId">Product id.</param>
        /// <param name="categoryId">Category id.</param>
        /// <returns>A bool value to indicate whether a product is belong to a category.</returns>
        bool IsProductInCategory(long productId, long categoryId);

        /// <summary>
        /// Get qualify lines by offer id, which is used to store required items and corresponding quantity for the discounts.
        /// </summary>
        /// <param name="offerIds">The offer ids of the discounts.</param>
        /// <returns>A enumerable object contains all qualify lines of specified discounts.</returns>
        IEnumerable<DiscountQualifyLine> GetQualifyLinesByOfferIds(
            IEnumerable<string> offerIds);
    }
}
