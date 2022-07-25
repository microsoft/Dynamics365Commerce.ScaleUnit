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
    using Microsoft.Dynamics.Commerce.Runtime.Services.PricingEngine;

    /// <summary>
    /// Pricing engine initializer.
    /// </summary>
    /// <remarks>The sample code of multiple ways of initializing pricing engine. In production code, you need one only.</remarks>
    public static class PricingEngineExtensionRegister
    {
        /// <summary>
        /// Initializes pricing engine extensions.
        /// </summary>
        public static void RegisterPricingEngineExtensions()
        {
            PricingEngineExtensionRepository.RegisterDiscountableItemGroupKeyConstructor(new FreeMoneyAmountDiscountableItemGroupKeyConstructor());
            PricingEngineExtensionRepository.RegisterPriorityDiscountBaseAmountCalculator(new BaseReductionForAmountCapDiscountBaseAmountCalculator());
        }
    }
}
