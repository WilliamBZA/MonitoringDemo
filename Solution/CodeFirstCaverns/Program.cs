﻿using NServiceBus;
using System;
using System.Threading.Tasks;
using Messages;
using Shared;

namespace CodeFirstCaverns
{
    class Program
    {
        static async Task Main()
        {
            Console.Title = "CodeFirstCaverns";
            Console.SetWindowSize(65, 15);

            LoggingUtils.ConfigureLogging("CodeFirstCaverns");


            var endpointConfiguration = new EndpointConfiguration("CodeFirstCaverns");
            endpointConfiguration.LimitMessageProcessingConcurrencyTo(4);


            endpointConfiguration.UsePersistence<InMemoryPersistence>();

            var transport = endpointConfiguration.UseTransport<SqlServerTransport>();
            transport.ConnectionStringName("NServiceBus/Transport");

            endpointConfiguration.AuditProcessedMessagesTo("audit");

            endpointConfiguration.UniquelyIdentifyRunningInstance()
                .UsingCustomIdentifier(new Guid("BB8A8BAF-4187-455E-AAD2-211CD43267CB"))
                .UsingCustomDisplayName("original-instance");

            var metrics = endpointConfiguration.EnableMetrics();
            metrics.SendMetricDataToServiceControl(
                "Particular.Monitoring",
                TimeSpan.FromMilliseconds(500)
            );

            var routing = transport.Routing();
            routing.RegisterPublisher(
                typeof(MessageProcessorRideCompleted),
                "TheMessageProcessor"
            );
            routing.RegisterPublisher(
                typeof(TicketBought),
                "BusinessLogicBumperCars"
            );

            var simulationEffects = new SimulationEffects();
            endpointConfiguration.RegisterComponents(cc => cc.RegisterSingleton(simulationEffects));

            var endpointInstance = await Endpoint.Start(endpointConfiguration)
                .ConfigureAwait(false);

            RunUserInterfaceLoop(simulationEffects);

            await endpointInstance.Stop()
                .ConfigureAwait(false);
        }

        static void RunUserInterfaceLoop(SimulationEffects state)
        {
            while (true)
            {
                Console.Clear();
                Console.WriteLine("CodeFirstCaverns Endpoint");
                Console.WriteLine("Press D to toggle resource degradation simulation");
                Console.WriteLine("Press F to process OrderBilled events faster");
                Console.WriteLine("Press S to process OrderBilled events slower");
                Console.WriteLine("Press ESC to quit");
                Console.WriteLine();

                state.WriteState(Console.Out);

                var input = Console.ReadKey(true);

                switch (input.Key)
                {
                    case ConsoleKey.D:
                        state.ToggleDegradationSimulation();
                        break;
                    case ConsoleKey.F:
                        state.ProcessMessagesFaster();
                        break;
                    case ConsoleKey.S:
                        state.ProcessMessagesSlower();
                        break;
                    case ConsoleKey.Escape:
                        return;
                }
            }
        }

    }
}