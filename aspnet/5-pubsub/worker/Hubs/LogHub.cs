using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using Microsoft.AspNet.SignalR;

namespace GoogleCloudSamples.Hubs
{
    /// <summary>
    /// A Hub that wraps LogTicker.
    /// </summary>
    public class LogHub : Hub
    {
        public string GetLastMessage()
        {
            return LogTicker.Instance.GetLastMessage();
        }
    }
}