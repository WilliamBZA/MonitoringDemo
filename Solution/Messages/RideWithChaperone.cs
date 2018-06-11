using NServiceBus;

namespace Messages
{
    public class RideWithChaperone :
        ICommand
    {
        public string OrderId { get; set; }
    }
}