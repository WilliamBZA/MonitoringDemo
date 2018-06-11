namespace ParkEntrance
{
    using System;
    using System.IO;
    using System.Threading;
    using System.Threading.Tasks;
    using Messages;
    using NServiceBus;

    class SimulatedCustomers
    {
        readonly IEndpointInstance endpointInstance;
        bool highTrafficMode;

        public SimulatedCustomers(IEndpointInstance endpointInstance)
        {
            this.endpointInstance = endpointInstance;
        }

        public void WriteState(TextWriter output)
        {
            var trafficMode = highTrafficMode ? "High" : "Low";
            output.WriteLine($"{trafficMode} traffic mode - sending {rate} orders / second");
        }

        public void ToggleTrafficMode()
        {
            highTrafficMode = !highTrafficMode;
            rate = highTrafficMode ? 8 : 1;
        }

        DateTime nextReset;
        int currentIntervalCount;
        int rate = 1;
        int sent = 0;

        public async Task Run(CancellationToken token)
        {
            nextReset = DateTime.UtcNow.AddSeconds(1);
            currentIntervalCount = 0;

            while(!token.IsCancellationRequested)
            {
                sent++;

                var now = DateTime.UtcNow;
                if(now > nextReset)
                {
                    currentIntervalCount = 0;
                    nextReset = now.AddSeconds(1);
                }

                await PlaceSingleOrder()
                    .ConfigureAwait(false);
                currentIntervalCount++;

                if (sent % 5 == 0)
                {
                    await PlaceRideWithAChaperone();
                }

                try
                {
                    if (currentIntervalCount >= rate)
                    {
                        var delay = nextReset - DateTime.UtcNow;
                        if (delay > TimeSpan.Zero)
                        {
                            await Task.Delay(delay, token)
                                .ConfigureAwait(false);
                        }
                    }
                }
                catch (TaskCanceledException)
                {
                    break;
                }
            }
        }

        Task PlaceRideWithAChaperone()
        {
            return endpointInstance.Send(new RideWithChaperone
            {
                OrderId = Guid.NewGuid().ToString()
            });
        }

        Task PlaceSingleOrder()
        {
            var placeOrderCommand = new RideMessageProcessor
            {
                OrderId = Guid.NewGuid().ToString()
            };

            return endpointInstance.Send(placeOrderCommand);
        }
    }
}