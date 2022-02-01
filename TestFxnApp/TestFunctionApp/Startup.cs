using Azure.Identity;
using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using System;

[assembly: FunctionsStartup(typeof(TestFunctionApp.Startup))]
namespace TestFunctionApp
{
    public class Startup : FunctionsStartup
    {
        public override void ConfigureAppConfiguration(IFunctionsConfigurationBuilder builder)
        {
            base.ConfigureAppConfiguration(builder);
            string cs = Environment.GetEnvironmentVariable("AppConfigEndpoint");
            builder
                .ConfigurationBuilder
                .AddAzureAppConfiguration(o => o
                    .Connect(new Uri(cs), new DefaultAzureCredential())
                    .ConfigureKeyVault(kvo =>
                    {
                        kvo.SetCredential(new DefaultAzureCredential());
                    }));
        }

        public override void Configure(IFunctionsHostBuilder builder)
        {
            var configuration = builder.GetContext().Configuration;
            
        }
    }
}
