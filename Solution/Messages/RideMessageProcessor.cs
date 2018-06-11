using NServiceBus;

namespace Messages
{
    public class RideMessageProcessor :
        ICommand
    {
        public string OrderId { get; set; }
    }
}