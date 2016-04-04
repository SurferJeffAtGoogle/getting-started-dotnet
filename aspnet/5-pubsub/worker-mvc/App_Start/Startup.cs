using Microsoft.Owin;
using Owin;

[assembly: OwinStartupAttribute(typeof(worker_mvc.Startup))]

namespace worker_mvc
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            app.MapSignalR();
        }
    }
}
