using System;
using Microsoft.AspNet.SignalR;
using Microsoft.AspNet.SignalR.Hubs;
using GoogleCloudSamples.Hubs;
using GoogleCloudSamples.Services;

namespace GoogleCloudSamples
{
    public class LogTicker : ISimpleLogger
    {
        // Singleton instance
        private readonly static Lazy<LogTicker> _instance = new Lazy<LogTicker>(() => new LogTicker(GlobalHost.ConnectionManager.GetHubContext<LogHub>().Clients));

        private object _lastMessageLock = new Object();
        private string _lastMessage;

        private LogTicker(IHubConnectionContext<dynamic> clients)
        {
            Clients = clients;
        }

        public static LogTicker Instance
        {
            get
            {
                return _instance.Value;
            }
        }

        private IHubConnectionContext<dynamic> Clients
        {
            get;
            set;
        }

        public void LogVerbose(string message)
        {
            lock (_lastMessageLock) _lastMessage = message;
            Clients.All.logVerbose(message);
        }

        public void LogError(string message, Exception e)
        {
            Clients.All.logError(message, e.ToString());
        }

        public string GetLastMessage()
        {
            lock (_lastMessageLock) return _lastMessage;
        }
    }
}