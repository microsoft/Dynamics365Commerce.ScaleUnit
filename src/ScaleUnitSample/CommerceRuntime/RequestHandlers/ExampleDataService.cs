/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

namespace Contoso.CommerceRuntime.RequestHandlers
{
    using System;
    using System.Collections.Generic;
    using System.Globalization;
    using System.Linq;
    using System.Threading.Tasks;
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.Data;
    using Microsoft.Dynamics.Commerce.Runtime.DataAccess.SqlServer;
    using Microsoft.Dynamics.Commerce.Runtime.Messages;
    using Contoso.CommerceRuntime.Entities.DataModel;
    using Contoso.CommerceRuntime.Messages;

    /// <summary>
    /// Sample service to demonstrate managing a collection of entities.
    /// </summary>
    public class ExampleDataService : IRequestHandlerAsync
    {
        /// <summary>
        /// Gets the collection of supported request types by this handler.
        /// </summary>
        public IEnumerable<Type> SupportedRequestTypes
        {
            get
            {
                return new[]
                {
                    typeof(CreateExampleEntityDataRequest),
                    typeof(ExampleEntityDataRequest),
                    typeof(UpdateExampleEntityDataRequest),
                    typeof(DeleteExampleEntityDataRequest),
                };
            }
        }

        /// <summary>
        /// Entry point to StoreHoursDataService service.
        /// </summary>
        /// <param name="request">The request to execute.</param>
        /// <returns>Result of executing request, or null object for void operations.</returns>
        public Task<Response> Execute(Request request)
        {
            ThrowIf.Null(request, nameof(request));

            switch (request)
            {
                case CreateExampleEntityDataRequest createExampleEntityDataRequest:
                    return this.CreateExampleEntity(createExampleEntityDataRequest);
                case ExampleEntityDataRequest exampleEntityDataRequest:
                    return this.GetExampleEntities(exampleEntityDataRequest);
                case UpdateExampleEntityDataRequest updateExampleEntityDataRequest:
                    return this.UpdateExampleEntity(updateExampleEntityDataRequest);
                case DeleteExampleEntityDataRequest deleteExampleEntityDataRequest:
                    return this.DeleteExampleEntity(deleteExampleEntityDataRequest);
                default:
                    throw new NotSupportedException($"Request '{request.GetType()}' is not supported.");
            }
        }

        private async Task<Response> CreateExampleEntity(CreateExampleEntityDataRequest request)
        {
            ThrowIf.Null(request, nameof(request));
            ThrowIf.Null(request.EntityData, nameof(request.EntityData));

            long insertedId = 0;
            using (var databaseContext = new SqlServerDatabaseContext(request.RequestContext))
            {
                ParameterSet parameters = new ParameterSet();
                parameters["@i_ExampleInt"] = request.EntityData.IntData;
                parameters["@s_ExampleString"] = request.EntityData.StringData;
                var result = await databaseContext
                    .ExecuteStoredProcedureAsync<ExampleEntity>("[ext].CONTOSO_INSERTEXAMPLE", parameters, request.QueryResultSettings)
                    .ConfigureAwait(continueOnCapturedContext: false);
                insertedId = result.Item2.Single().UnusualEntityId;
            }

            return new CreateExampleEntityDataResponse(insertedId);
        }

        private async Task<Response> GetExampleEntities(ExampleEntityDataRequest request)
        {
            ThrowIf.Null(request, "request");

            using (DatabaseContext databaseContext = new DatabaseContext(request.RequestContext))
            {
                var query = new SqlPagedQuery(request.QueryResultSettings)
                {
                    DatabaseSchema = "ext",
                    Select = new ColumnSet("EXAMPLEINT", "EXAMPLESTRING", "EXAMPLEID"),
                    From = "CONTOSO_EXAMPLEVIEW",
                    OrderBy = "EXAMPLEID",
                };

                var queryResults =
                    await databaseContext
                    .ReadEntityAsync<Entities.DataModel.ExampleEntity>(query)
                    .ConfigureAwait(continueOnCapturedContext: false);
                return new ExampleEntityDataResponse(queryResults);
            }
        }

        private async Task<Response> UpdateExampleEntity(UpdateExampleEntityDataRequest request)
        {
            ThrowIf.Null(request, nameof(request));
            ThrowIf.Null(request.UpdatedExampleEntity, nameof(request.UpdatedExampleEntity));

            if (request.ExampleEntityKey == 0)
            {
                throw new DataValidationException(DataValidationErrors.Microsoft_Dynamics_Commerce_Runtime_ValueOutOfRange, $"{nameof(request.ExampleEntityKey)} cannot be 0");
            }

            bool updateSuccess = false;
            using (var databaseContext = new SqlServerDatabaseContext(request.RequestContext))
            {
                ParameterSet parameters = new ParameterSet();
                parameters["@bi_Id"] = request.ExampleEntityKey;
                parameters["@i_ExampleInt"] = request.UpdatedExampleEntity.IntData;
                parameters["@s_ExampleString"] = request.UpdatedExampleEntity.StringData;
                int sprocErrorCode =
                    await databaseContext
                    .ExecuteStoredProcedureNonQueryAsync("[ext].CONTOSO_UPDATEEXAMPLE", parameters, request.QueryResultSettings)
                    .ConfigureAwait(continueOnCapturedContext: false);
                updateSuccess = (sprocErrorCode == 0);
            }

            return new UpdateExampleEntityDataResponse(updateSuccess);
        }

        private async Task<Response> DeleteExampleEntity(DeleteExampleEntityDataRequest request)
        {
            ThrowIf.Null(request, nameof(request));

            if (request.ExampleEntityKey == 0)
            {
                throw new DataValidationException(DataValidationErrors.Microsoft_Dynamics_Commerce_Runtime_ValueOutOfRange, $"{nameof(request.ExampleEntityKey)} cannot be 0");
            }

            bool deleteSuccess = false;
            using (var databaseContext = new SqlServerDatabaseContext(request.RequestContext))
            {
                ParameterSet parameters = new ParameterSet();
                parameters["@bi_Id"] = request.ExampleEntityKey;
                int sprocErrorCode =
                    await databaseContext
                    .ExecuteStoredProcedureNonQueryAsync("[ext].CONTOSO_DELETEEXAMPLE", parameters, request.QueryResultSettings)
                    .ConfigureAwait(continueOnCapturedContext: false);
                deleteSuccess = sprocErrorCode == 0;
            }

            return new DeleteExampleEntityDataResponse(deleteSuccess);
        }
    }
}