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
    using System.Threading.Tasks;

    /// <summary>
    /// Amount cap data accessor interface.
    /// </summary>
    /// <remarks>Data accessor interface to support both Channel and AX.</remarks>
    public interface IDataAccessorAmountCap
    {
        /// <summary>
        /// Gets discount amount caps by offer Ids.
        /// </summary>
        /// <param name="offerIds">Offer Ids.</param>
        /// <returns>The collection of discount amount caps of type ReadOnlyCollection&lt;DiscountAmountCap&gt;.</returns>
        Task<object> GetDiscountAmountCapsByOfferIdsAsync(object offerIds);
    }
}
