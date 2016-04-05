using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace GoogleCloudSamples.Services
{
    public interface ISimpleLogger
    {
        // Using a sophisticated logger like log4net is beyond the scope of this sample.
        void LogVerbose(string message);

        void LogError(string message, Exception e);
    }
}
