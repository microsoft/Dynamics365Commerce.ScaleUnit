/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */
 
namespace Contoso.CommerceRuntime.Controllers
{
    using System.Threading.Tasks;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.Hosting.Contracts;

    /// <summary>
    /// An extension controller to handle requests to the StoreHours entity set.
    /// </summary>
    [RoutePrefix("BoundController")]
    [BindEntity(typeof(Entities.DataModel.ExampleEntity))]
    public class BoundController : IController
    {
        [HttpGet]
        [Authorization(CommerceRoles.Anonymous, CommerceRoles.Application, CommerceRoles.Customer, CommerceRoles.Device, CommerceRoles.Employee, CommerceRoles.Storefront)]
        public async Task<PagedResult<Entities.DataModel.ExampleEntity>> GetAllExampleEntities(IEndpointContext context)
        {
            var queryResultSettings = QueryResultSettings.SingleRecord;
            queryResultSettings.Paging = new PagingInfo(10);

            var request = new Messages.ExampleEntityDataRequest() { QueryResultSettings = queryResultSettings };
            var response = await context.ExecuteAsync<Messages.ExampleEntityDataResponse>(request).ConfigureAwait(false);
            return response.ExampleEntities;
        }

        [HttpPost]
        [Authorization(CommerceRoles.Customer, CommerceRoles.Device, CommerceRoles.Employee)]
        public async Task<long> CreateExampleEntity(IEndpointContext context, CommerceRuntime.Entities.DataModel.ExampleEntity entityData)
        {
            var request = new Messages.CreateExampleEntityDataRequest(entityData);
            var response = await context.ExecuteAsync<Messages.CreateExampleEntityDataResponse>(request).ConfigureAwait(false);
            return response.CreatedId;
        }

        [HttpPost]
        [Authorization(CommerceRoles.Customer, CommerceRoles.Device, CommerceRoles.Employee)]
        public async Task<bool> UpdateExampleEntity(IEndpointContext context, [EntityKey] long key, CommerceRuntime.Entities.DataModel.ExampleEntity updatedEntity)
        {
            var request = new Messages.UpdateExampleEntityDataRequest(key, updatedEntity);
            var response = await context.ExecuteAsync<Messages.UpdateExampleEntityDataResponse>(request).ConfigureAwait(false);
            return response.Success;
        }

        [HttpPost]
        [Authorization(CommerceRoles.Customer, CommerceRoles.Device, CommerceRoles.Employee)]
        public async Task<bool> DeleteExampleEntity(IEndpointContext context, [EntityKey] long key)
        {
            var request = new Messages.DeleteExampleEntityDataRequest(key);
            var response = await context.ExecuteAsync<Messages.DeleteExampleEntityDataResponse>(request).ConfigureAwait(false);
            return response.Success;
        }
    }
}
