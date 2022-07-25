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
    /// Class containing additional enumeration members for <see cref="ExtensiblePeriodicDiscountOfferType"/>.
    /// </summary>
    public class ContosoPeriodicDiscountOfferType : ExtensiblePeriodicDiscountOfferType
    {
        /// <summary>
        /// Initializes a new instance of the <see cref="ContosoPeriodicDiscountOfferType"/> class.
        /// </summary>
        /// <param name="name">The name of this enumeration instance.</param>
        /// <param name="value">The value of this enumeration instance.</param>
        protected ContosoPeriodicDiscountOfferType(string name, int value) : base(name, value)
        {
        }

        /// <summary>
        /// Gets Amount cap discount type.
        /// </summary>
        public static ExtensiblePeriodicDiscountOfferType AmountCap
        {
            get
            {
                return ExtensiblePeriodicDiscountOfferType.GetByName("AmountCap");
            }
        }
    }
}
