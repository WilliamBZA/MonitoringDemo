using System.Threading.Tasks;
using Messages;
using NServiceBus;

namespace CodeFirstCaverns
{
    public class OrderBilledHandler :
        IHandleMessages<TicketBought>
    {
        SimulationEffects simulationEffects;

        public OrderBilledHandler(SimulationEffects simulationEffects)
        {
            this.simulationEffects = simulationEffects;
        }

        public Task Handle(TicketBought message, IMessageHandlerContext context)
        {
            return simulationEffects.SimulateOrderBilledMessageProcessing();
        }
    }
}