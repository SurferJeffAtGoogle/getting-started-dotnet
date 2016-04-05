using Microsoft.Owin;
using Owin;

[assembly: OwinStartupAttribute(typeof(GoogleCloudSamples.Startup))]

namespace GoogleCloudSamples
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            app.MapSignalR();
        }
    }
}
