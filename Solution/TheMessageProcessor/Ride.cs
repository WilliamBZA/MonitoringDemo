using System;
using System.Threading.Tasks;
using Messages;
using NServiceBus;

namespace TheMessageProcessor
{
    public class Ride :
        IHandleMessages<RideMessageProcessor>,
        IHandleMessages<RideWithChaperone>
    {
        SimulationEffects simulationEffects;
        Random rand = new Random();

        public Ride(SimulationEffects simulationEffects)
        {
            this.simulationEffects = simulationEffects;
        }

        public async Task Handle(RideMessageProcessor message, IMessageHandlerContext context)
        {
            // Simulate the time taken to process a message
            await simulationEffects.SimulateMessageProcessing()
                .ConfigureAwait(false);

            var orderPlaced = new MessageProcessorRideCompleted
            {
                OrderId = message.OrderId
            };
            await context.Publish(orderPlaced)
                .ConfigureAwait(false);
        }

        public async Task Handle(RideWithChaperone message, IMessageHandlerContext context)
        {
            await Task.Delay(4500 + rand.Next(1000));

            // Simulate the time taken to process a message
            await simulationEffects.SimulateMessageProcessing()
                .ConfigureAwait(false);

            var orderPlaced = new MessageProcessorRideCompleted
            {
                OrderId = message.OrderId
            };
            await context.Publish(orderPlaced)
                .ConfigureAwait(false);
        }
    }
}