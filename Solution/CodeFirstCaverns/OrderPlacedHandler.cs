using System.Threading.Tasks;
using Messages;
using NServiceBus;

namespace CodeFirstCaverns
{
    public class OrderPlacedHandler :
        IHandleMessages<MessageProcessorRideCompleted>
    {
        private SimulationEffects simulationEffects;

        public OrderPlacedHandler(SimulationEffects simulationEffects)
        {
            this.simulationEffects = simulationEffects;
        }

        public Task Handle(MessageProcessorRideCompleted message, IMessageHandlerContext context)
        {
            return simulationEffects.SimulateOrderPlacedMessageProcessing();
        }
    }
}