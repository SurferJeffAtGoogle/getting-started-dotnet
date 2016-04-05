using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using Microsoft.AspNet.SignalR;
using Microsoft.AspNet.SignalR.Hubs;
using worker_mvc.Hubs;

namespace worker_mvc
{
    public class LogTicker
    {
        // Singleton instance
        private readonly static Lazy<LogTicker> _instance = new Lazy<LogTicker>(() => new LogTicker(GlobalHost.ConnectionManager.GetHubContext<LogHub>().Clients));

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

        public void LogVerbose(string message) => Clients.All.logVerbose(message);

        public void LogError(string message, Exception e)
        {
            Clients.All.logError(message, e.ToString());
        }
    }
}