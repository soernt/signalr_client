using Microsoft.AspNetCore;
using Microsoft.AspNetCore.Hosting;

namespace TestServer
{
  public class Program
  {
    public static void Main(string[] args)
    {
      createWebHostBuilder(args).Build().Run();
    }

    private static IWebHostBuilder createWebHostBuilder(string[] args) =>
      WebHost.CreateDefaultBuilder(args)
        .UseStartup<Startup>()
        .UseUrls(urls: "http://*:51001");
  }
}
