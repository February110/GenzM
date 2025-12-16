namespace class_worker
{
    public sealed class WorkerSettings
    {
        public RabbitSettings RabbitMQ { get; set; } = new();
        public ApiSettings Api { get; set; } = new();
    }

    public sealed class RabbitSettings
    {
        public string HostName { get; set; } = "rabbitmq";
        public int Port { get; set; } = 5672;
        public string UserName { get; set; } = "guest";
        public string Password { get; set; } = "guest";
        public string QueueName { get; set; } = "notifications";
    }

    public sealed class ApiSettings
    {
        public string BaseUrl { get; set; } = "http://class_api:8080";
        public string WorkerKey { get; set; } = string.Empty;
    }
}
