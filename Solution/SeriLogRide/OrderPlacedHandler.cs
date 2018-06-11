using System.Threading.Tasks;
using Messages;
using NServiceBus;

namespace SeriLogRide
{
    public class OrderPlacedHandler :
        IHandleMessages<MessageProcessorRideCompleted>
    {
        SimulationEffects simulationEffects;

        public OrderPlacedHandler(SimulationEffects simulationEffects)
        {
            this.simulationEffects = simulationEffects;
        }

        public async Task Handle(MessageProcessorRideCompleted message, IMessageHandlerContext context)
        {
            await simulationEffects.SimulatedMessageProcessing()
                .ConfigureAwait(false);

            var orderBilled = new TicketBought
            {
                OrderId = message.OrderId
            };
            await context.Publish(orderBilled)
                .ConfigureAwait(false);
        }
    }
}