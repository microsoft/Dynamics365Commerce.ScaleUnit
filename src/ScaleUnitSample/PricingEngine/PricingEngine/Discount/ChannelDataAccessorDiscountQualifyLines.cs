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
    using System.Collections.Generic;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Data;
    using Microsoft.Dynamics.Commerce.Runtime.Data.Types;
    using Microsoft.Dynamics.Commerce.Runtime.DataServices.Messages;

    /// <summary>
    /// Channel data accessor for discount qualify lines.
    /// </summary>
    public class ChannelDataAccessorDiscountQualifyLines : IDataAccessorDiscountQualifyLines
    {
        private RequestContext requestContext;
        private const string DiscountQualifyLinesViewName = "CONTOSORETAILDISCOUNTQUALIFYLINESVIEW";

        /// <summary>
        /// Initializes a new instance of the <see cref="ChannelDataAccessorDiscountQualifyLines" /> class.
        /// </summary>
        /// <param name="requestContext">Commerce runtime request context.</param>
        public ChannelDataAccessorDiscountQualifyLines(RequestContext requestContext)
        {
            this.requestContext = requestContext;
        }

        /// <summary>
        /// Get category threshold qualify lines by offer id, which is used to store required items and corresponding quantity for the category threshold discount.
        /// </summary>
        /// <param name="offerIds">The offer ids of the threshold discount.</param>
        /// <returns>A paged result contains all category threshold qualify lines of specified threshold.</returns>
        public IEnumerable<DiscountQualifyLine> GetQualifyLinesByOfferIds(IEnumerable<string> offerIds)
        {
            ThrowIf.Null(offerIds, "offerIds");

            var query = new SqlPagedQuery(QueryResultSettings.AllRecords)
            {
                DatabaseSchema = "ext",
                From = DiscountQualifyLinesViewName,
                Where = "DATAAREAID = @dataAreaId",
            };

            using (var databaseContext = new DatabaseContext(this.requestContext))
            using (StringIdTableType type = new StringIdTableType(offerIds, "OFFERID"))
            {
                query.Parameters["@TVP_STRINGIDTABLETYPE"] = type;
                query.Parameters["@dataAreaId"] = this.requestContext.GetChannelConfiguration().InventLocationDataAreaId;

                return databaseContext.ReadEntity<DiscountQualifyLine>(query);
            }
        }

        /// <summary>
        /// Gets an value to indicate whether product is in a category.
        /// </summary>
        /// <param name="productId">Product id.</param>
        /// <param name="categoryId">Category id.</param>
        /// <returns>A bool value.</returns>
        public bool IsProductInCategory(long productId, long categoryId)
        {
            var dataRequest = new CheckIfProductOrVariantAreInCategoryDataRequest(productId, categoryId);
#pragma warning disable CS0618 // Type or member is obsolete. JUSTIFICATION: Needs refactoring
            return this.requestContext.Execute<SingleEntityDataServiceResponse<bool>>(dataRequest).Entity;
#pragma warning restore CS0618 // Type or member is obsolete
        }
    }
}
