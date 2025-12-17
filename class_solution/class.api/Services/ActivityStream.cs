using class_api.Application.Dtos;
using class_api.Application.Interfaces;
using class_api.Hubs;
using Microsoft.AspNetCore.SignalR;
using System.Collections.Concurrent;

namespace class_api.Services
{
    public sealed class ActivityStream : IActivityStream
    {
        private readonly int _maxEntries = 200;
        private readonly ConcurrentQueue<ActivityEvent> _fallbackQueue = new();

        private readonly IHubContext<ActivityHub> _hub;
        public ActivityStream(IHubContext<ActivityHub> hub)
        {
            _hub = hub;
        }

        public async Task PublishAsync(ActivityEvent payload, CancellationToken cancellationToken = default)
        {
            _fallbackQueue.Enqueue(payload);
            while (_fallbackQueue.Count > _maxEntries)
            {
                _fallbackQueue.TryDequeue(out _);
            }

            await _hub.Clients.All.SendAsync("ActivityUpdated", payload, cancellationToken);
        }

        public Task<IReadOnlyList<ActivityEvent>> GetRecentAsync(int take, CancellationToken cancellationToken = default)
        {
            var limit = Math.Clamp(take, 1, _maxEntries);
            // No external cache: return from in-memory queue
            var snapshot = _fallbackQueue.Reverse().Take(limit).ToList();
            return Task.FromResult<IReadOnlyList<ActivityEvent>>(snapshot);
        }
    }
}
