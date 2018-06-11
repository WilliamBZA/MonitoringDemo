using System;
using System.Threading;
using System.Threading.Tasks;
using Messages;
using NServiceBus;
using Shared;

namespace ParkEntrance
{
    class Program
    {
        static async Task Main()
        {
            Console.Title = "ParkEntrance";
            Console.SetWindowSize(65, 15);

            LoggingUtils.ConfigureLogging("ParkEntrance");

            var endpointConfiguration = new EndpointConfiguration("ParkEntrance");

            endpointConfiguration.UsePersistence<InMemoryPersistence>();

            var transport = endpointConfiguration.UseTransport<SqlServerTransport>();
            transport.ConnectionStringName("NServiceBus/Transport");

            endpointConfiguration.UniquelyIdentifyRunningInstance()
                .UsingCustomIdentifier(new Guid("EA3E7D1B-8171-4098-B160-1FEA975CCB2C"))
                .UsingCustomDisplayName("original-instance");

            var metrics = endpointConfiguration.EnableMetrics();
            metrics.SendMetricDataToServiceControl(
                "Particular.Monitoring",
                TimeSpan.FromMilliseconds(500)
            );


            var routing = transport.Routing();
            routing.RouteToEndpoint(typeof(RideMessageProcessor), "TheMessageProcessor");
            routing.RouteToEndpoint(typeof(RideWithChaperone), "TheMessageProcessor");

            var endpointInstance = await Endpoint.Start(endpointConfiguration)
                .ConfigureAwait(false);

            var simulatedCustomers = new SimulatedCustomers(endpointInstance);
            var cancellation = new CancellationTokenSource();
            var simulatedWork = simulatedCustomers.Run(cancellation.Token);

            RunUserInterfaceLoop(simulatedCustomers);

            cancellation.Cancel();

            await simulatedWork
                .ConfigureAwait(false);

            await endpointInstance.Stop()
                .ConfigureAwait(false);
        }

        static void RunUserInterfaceLoop(SimulatedCustomers simulatedCustomers)
        {
            while (true)
            {
                Console.Clear();
                Console.WriteLine("Simulating customers placing orders on a website");
                Console.WriteLine("Press T to toggle High/Low traffic mode");
                Console.WriteLine("Press ESC to quit");
                Console.WriteLine();

                simulatedCustomers.WriteState(Console.Out);

                var input = Console.ReadKey(true);

                switch (input.Key)
                {
                    case ConsoleKey.T:
                        simulatedCustomers.ToggleTrafficMode();
                        break;
                    case ConsoleKey.Escape:
                        return;
                }
            }
        }
    }
}