using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Microsoft.AspNet.SignalR;

namespace worker_mvc.Hubs
{
    public class LogHub : Hub
    {
        private readonly LogTicker _logTicker;

        public LogHub()
        {
            _logTicker = LogTicker.Instance;
        }

        public void LogVerbose(string message) => Clients.All.logVerbose(message);

        public void LogError(string message, Exception e)
        {
            Clients.All.logError(message, e.ToString());
        }
    }
}