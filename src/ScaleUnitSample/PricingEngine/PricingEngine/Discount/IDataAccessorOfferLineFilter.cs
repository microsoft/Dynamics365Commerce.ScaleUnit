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
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;

    /// <summary>
    /// Discount offer with line filter data accessor interface.
    /// </summary>
    /// <remarks>Data accessor interface to support both Channel and AX.</remarks>
    public interface IDataAccessorOfferLineFilter
    {
        /// <summary>
        /// Gets discount amount caps by offer Ids.
        /// </summary>
        /// <param name="offerIds">Offer Ids.</param>
        /// <returns>The collection of discount amount caps of type ReadOnlyCollection&lt;OfferLineFilter&gt;.</returns>
        object GetOfferLineFiltersByOfferIds(object offerIds);

        /// <summary>
        /// Gets the validation period.
        /// </summary>
        /// <param name="periodId">Period Id.</param>
        /// <returns>Validation period.</returns>
        /// <remarks>Not optimized for sample.</remarks>
        ValidationPeriod GetValidationPeriod(string periodId);
    }
}
