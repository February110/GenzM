using class_api.Application.Interfaces;
using Microsoft.Extensions.Logging;

namespace class_api.Services
{
    /// <summary>
    /// No-op dispatcher used when RabbitMQ is unavailable/disabled.
    /// </summary>
    public sealed class NullNotificationDispatcher : INotificationDispatcher
    {
        private readonly ILogger<NullNotificationDispatcher> _logger;

        public NullNotificationDispatcher(ILogger<NullNotificationDispatcher> logger)
        {
            _logger = logger;
        }

        public Task DispatchAsync(IEnumerable<Guid> userIds, string title, string message, string type, Guid? classroomId = null, Guid? assignmentId = null, object? metadata = null, CancellationToken cancellationToken = default)
        {
            _logger.LogWarning("NotificationDispatcher is disabled (RabbitMQ unavailable). Skipping send for type '{Type}'.", type);
            return Task.CompletedTask;
        }
    }
}
