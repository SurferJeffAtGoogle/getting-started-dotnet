using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Sessions.Models;

namespace Sessions.Controllers
{
    public class HomeController : Controller
    {
        const string VisitCountSessionKey = "VisitCount";
        public IActionResult Index()
        {
            int? visitCount = HttpContext.Session.GetInt32(VisitCountSessionKey);
            var model = new IndexViewModel()
            {
                VisitCount = visitCount.HasValue ? visitCount.Value + 1 : 1
            };
            HttpContext.Session.SetInt32(VisitCountSessionKey, model.VisitCount);
            return View(model);
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
