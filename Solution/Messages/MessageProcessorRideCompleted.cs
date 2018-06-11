using NServiceBus;

namespace Messages
{
    public class MessageProcessorRideCompleted :
        IEvent
    {
        public string OrderId { get; set; }
    }
}