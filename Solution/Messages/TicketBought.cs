using NServiceBus;

namespace Messages
{
    public class TicketBought :
        IEvent
    {
        public string OrderId { get; set; }
    }
}