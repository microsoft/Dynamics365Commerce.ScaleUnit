/**
 * SAMPLE CODE NOTICE
 * 
 * THIS SAMPLE CODE IS MADE AVAILABLE AS IS.  MICROSOFT MAKES NO WARRANTIES, WHETHER EXPRESS OR IMPLIED,
 * OF FITNESS FOR A PARTICULAR PURPOSE, OF ACCURACY OR COMPLETENESS OF RESPONSES, OF RESULTS, OR CONDITIONS OF MERCHANTABILITY.
 * THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS SAMPLE CODE REMAINS WITH THE USER.
 * NO TECHNICAL SUPPORT IS PROVIDED.  YOU MAY NOT DISTRIBUTE THIS CODE UNLESS YOU HAVE A LICENSE AGREEMENT WITH MICROSOFT THAT ALLOWS YOU TO DO SO.
 */

namespace Contoso.CommerceRuntime.Triggers
{
    using Microsoft.Dynamics.Commerce.Runtime;
    using Microsoft.Dynamics.Commerce.Runtime.DataModel;
    using Microsoft.Dynamics.Commerce.Runtime.DataServices.Messages;
    using Microsoft.Dynamics.Commerce.Runtime.Messages;
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading.Tasks;

    /// <summary>
    /// In this sample trigger, we will add property to channelConfiguartion in a thread-safe manner.
    /// That's important since channelConfiguration is a cached object, and concurrent modification on it can cause 100% CPU usage.
    /// </summary>
    public class ChannelDataServiceRequestTrigger : IRequestTriggerAsync
    {
        public static readonly string PropertyKey = "ExtConfigurationParameters";

        /// <summary>
        /// Gets the supported requests for this trigger.
        /// </summary>
        public IEnumerable<Type> SupportedRequestTypes
        {
            get
            {
                return new Type[]
                {
                        typeof(GetChannelConfigurationDataRequest),
                };
            }
        }

        /// <summary>
        /// Pre trigger code.
        /// </summary>
        /// <param name="request">The request.</param>
        public Task OnExecuting(Request request)
        {
            // It's only stub to handle async signature 
            return Task.CompletedTask;
        }

        /// <summary>
        /// Post request trigger
        /// </summary>
        /// <param name="request">request</param>
        /// <param name="response">response</param>
        public async Task OnExecuted(Request request, Response response)
        {
            switch (request)
            {
                case GetChannelConfigurationDataRequest originalRequest:
                    var data = response as SingleEntityDataServiceResponse<ChannelConfiguration>;
                    if (data != null && data.Entity != null && data.Entity.GetProperty(PropertyKey) == null)
                    {
                        // In this example, we just put the configuration parameters as part of channelConfiguration property.
                        var configurationParameters = (await request.RequestContext.ExecuteAsync<EntityDataServiceResponse<RetailConfigurationParameter>>(new GetConfigurationParametersDataRequest(originalRequest.ChannelId)).ConfigureAwait(false)).ToList();

                        // The reason we need a lock here because of thread-safety.
                        // ChannelConfiguration is an object required in most crt request, and we cached in memory on the underlying ChannelDataService.
                        // In case there is concurrent crt request, without lock here, it will modify against the same ChannelConfiguration and will result as 100% CPU usage in worst case.
                        // NOTE: both SetProperty and ExtensionProperties are not thread-safe.
                        // NOTE: same situation for DeviceConfiguration, in which it is also required in most crt request and is cached in underlying DataService.
                        lock (data.Entity)
                        {
                            if (data.Entity.GetProperty(PropertyKey) == null)
                            {
                                data.Entity.SetProperty(PropertyKey, configurationParameters);
                            }
                        }
                    }
                    break;
                default:
                    throw new NotSupportedException($"Request '{request.GetType()}' is not supported.");
            }
        }
    }
}