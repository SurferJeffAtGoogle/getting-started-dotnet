using Moq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using GoogleCloudSamples;

namespace upload_test
{
    class Program
    {
        private static readonly string _usage = @"{0} id localpath

Uploads a png file to cloud storage.

id:         An integer.  Pick a number.  2 is nice.
localpath:  Full path to a local png file.
";
        static void Main(string[] args)
        {
            if (args.Length < 2)
            {
                string binPath = System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName;
                Console.WriteLine(String.Format(_usage, System.IO.Path.GetFileName(binPath)));
                return;
            }
            var uploader = new GoogleCloudSamples.Services.ImageUploader(
                UnityConfig.GetConfigVariable("GoogleCloudSamples:BucketName"),
                UnityConfig.GetConfigVariable("GoogleCloudSamples:ProjectId"));
            var file = new Mock<System.Web.HttpPostedFileBase>();
            var stream = new FileStream(args[1], FileMode.Open);
            file.Setup(x => x.InputStream).Returns(stream);
            file.Setup(x => x.ContentLength).Returns((int)stream.Length);
            file.Setup(x => x.FileName).Returns(stream.Name);
            file.Setup(x => x.ContentType).Returns("image/png");
            uploader.UploadImage(file.Object, long.Parse(args[0])).Wait();
        }
    }
}
