using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace TestFxnApp
{
    public class CronFunction
    {
        private readonly IConfiguration _config;
        public CronFunction(IConfiguration config)
        {
            _config = config;
        }

        [FunctionName("CronFunction")]
        public void Run([TimerTrigger("*/60 * * * * *")]TimerInfo myTimer, ILogger log)
        {
            log.LogInformation($"C# Timer trigger function executed at: {DateTime.Now}");
            string keyName = "AppConfigKey";
            string message = _config[keyName];
            log.LogInformation($"{keyName}: {message}");
            string keyNameSecret = "KeyVaultSecretKey";
            string messageSecret = _config[keyNameSecret];
            log.LogInformation($"{keyNameSecret}: {messageSecret}");
            
        }
    }
}
