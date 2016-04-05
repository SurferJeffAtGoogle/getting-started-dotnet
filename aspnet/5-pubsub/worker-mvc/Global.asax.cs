using GoogleCloudSamples;
using GoogleCloudSamples.Models;
using GoogleCloudSamples.Services;
using Microsoft.Practices.Unity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Web;
using System.Web.Mvc;
using System.Web.Optimization;
using System.Web.Routing;

namespace GoogleCloudSamples
{
    public class MvcApplication : System.Web.HttpApplication
    {
        protected void Application_Start()
        {
            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            BundleConfig.RegisterBundles(BundleTable.Bundles);

            // Launch a thread that watches the book detail subscription.
            var container = App_Start.UnityConfig.GetConfiguredContainer();
            LibUnityConfig.RegisterTypes(container);
            var bookDetailLookup = new BookDetailLookup(LibUnityConfig.ProjectId,
                logger: LogTicker.Instance);
            bookDetailLookup.CreateTopicAndSubscription();
            var pullTask = bookDetailLookup.StartPullLoop(container.Resolve<IBookStore>(),
                new CancellationTokenSource().Token);
        }
    }
}
