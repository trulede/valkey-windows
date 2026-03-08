using System.Diagnostics;

namespace ValkeyService
{
    class Program
    {
        static void Main(string[] args)
        {
            string configFilePath = "valkey.conf";

            if (args.Length > 1 && args[0] == "-c")
            {
                configFilePath = args[1];
            }

            IHost host = Host.CreateDefaultBuilder()
                .UseWindowsService()
                .ConfigureServices((hostContext, services) =>
                {
                    services.AddHostedService(_ => new ValkeyService(configFilePath));
                })
                .Build();

            host.Run();
        }
    }

    public class ValkeyService : BackgroundService
    {
        private readonly string configFilePath;

        private Process? valkeyProcess;

        private string valkeyServerPath = string.Empty;

        private string configPathForValkey = string.Empty;


        public ValkeyService(string configFilePath)
        {
            this.configFilePath = configFilePath;
        }


        public override Task StartAsync(CancellationToken cancellationToken)
        {
            var basePath = AppContext.BaseDirectory;
            string conf = configFilePath;

            if (!Path.IsPathRooted(conf))
                conf = Path.Combine(basePath, conf);

            conf = Path.GetFullPath(conf);

            var diskSymbol = conf[..conf.IndexOf(":")];
            configPathForValkey = conf
                .Replace(diskSymbol + ":", "/cygdrive/" + diskSymbol)
                .Replace("\\", "/");

            valkeyServerPath = Path.Combine(basePath, "valkey-server.exe")
                .Replace("\\", "/");

            string arguments = $"\"{configPathForValkey}\"";

            valkeyProcess = Process.Start(new ProcessStartInfo(valkeyServerPath, arguments)
            {
                WorkingDirectory = basePath,
                UseShellExecute = false
            });

            return Task.CompletedTask;
        }


        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }


        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            if (valkeyProcess == null || valkeyProcess.HasExited)
                return;

            try
            {
                await TryGracefulShutdownAsync();

                bool exited = await WaitForExitAsync(valkeyProcess, 5000);

                if (!exited)
                {
                    valkeyProcess.Kill(true);
                }
            }
            catch
            {
                if (!valkeyProcess.HasExited)
                    valkeyProcess.Kill(true);
            }

            valkeyProcess.Dispose();
        }


        private async Task TryGracefulShutdownAsync()
        {
            string valkeyCliPath = Path.Combine(AppContext.BaseDirectory, "valkey-cli.exe");

            if (!File.Exists(valkeyCliPath))
                return;

            var psi = new ProcessStartInfo(valkeyCliPath, "SHUTDOWN")
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            try
            {
                using var cli = Process.Start(psi);
                if (cli != null)
                    await cli.WaitForExitAsync();
            }
            catch
            {
            }
        }


        private static Task<bool> WaitForExitAsync(Process process, int timeoutMs)
        {
            return Task.Run(() => process.WaitForExit(timeoutMs));
        }
    }
}
