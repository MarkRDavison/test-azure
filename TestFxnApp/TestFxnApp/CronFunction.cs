using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace TestFxnApp
{
    public class CronFunction
    {
        [FunctionName("CronFunction")]
        public void Run([TimerTrigger("*/25 * * * * *")]TimerInfo myTimer, ILogger log)
        {
            log.LogInformation($"C# Timer trigger function executed at: {DateTime.Now}");
        }
    }
}
