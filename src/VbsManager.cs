using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;

namespace VbsManagerApp
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            var app = new Application
            {
                ShutdownMode = ShutdownMode.OnMainWindowClose
            };

            app.Run(new MainWindow());
        }
    }

    internal enum WorkflowKind
    {
        Disable,
        Revert
    }

    internal enum StatusKind
    {
        Ready,
        Running,
        Completed,
        Attention,
        Failed
    }

    internal sealed class MainWindow : Window
    {
        private const int DwmWindowAttributeUseImmersiveDarkMode = 20;
        private const int DwmWindowAttributeWindowCornerPreference = 33;
        private const int DwmWindowAttributeSystemBackdropType = 38;

        private readonly TextBlock _headerTitleText;
        private readonly TextBlock _headerBadgeText;
        private readonly Button _languageButton;
        private readonly TextBlock _actionTitleText;
        private readonly TextBlock _noteText;
        private readonly TextBlock _dangerText;
        private readonly TextBlock _statusText;
        private readonly Border _statusBadge;
        private readonly Button _disableButton;
        private readonly Button _revertButton;
        private readonly TextBlock _logTitleText;
        private readonly TextBlock _logSubtitleText;
        private readonly TextBox _logBox;
        private readonly Button _copyLogButton;

        private bool _isRunning;
        private bool _isChinese;
        private StatusKind _currentStatus = StatusKind.Ready;

        public MainWindow()
        {
            _isChinese = CultureInfo.CurrentUICulture.Name.StartsWith("zh", StringComparison.OrdinalIgnoreCase);

            Width = 1040;
            Height = 760;
            MinWidth = 980;
            MinHeight = 700;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            Background = new SolidColorBrush(Color.FromRgb(242, 245, 249));

            var root = new Grid
            {
                Margin = new Thickness(24)
            };

            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            root.RowDefinitions.Add(new RowDefinition());
            Content = root;

            var header = new Grid();
            header.ColumnDefinitions.Add(new ColumnDefinition());
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            Grid.SetRow(header, 0);
            root.Children.Add(header);

            var headerLeft = new StackPanel
            {
                Orientation = Orientation.Vertical
            };

            _headerTitleText = new TextBlock
            {
                FontSize = 34,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(Color.FromRgb(15, 23, 42)),
                FontFamily = new FontFamily("Segoe UI Variable Display")
            };

            headerLeft.Children.Add(_headerTitleText);
            header.Children.Add(headerLeft);

            var headerRight = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Right
            };

            _languageButton = CreateGhostButton(string.Empty);
            _languageButton.Width = 88;
            _languageButton.Height = 38;
            _languageButton.Margin = new Thickness(0, 0, 12, 0);
            _languageButton.Click += (_, __) => ToggleLanguage();
            headerRight.Children.Add(_languageButton);

            var headerBadge = new Border
            {
                CornerRadius = new CornerRadius(18),
                Background = new SolidColorBrush(Color.FromRgb(15, 23, 42)),
                Padding = new Thickness(14, 8, 14, 8),
                VerticalAlignment = VerticalAlignment.Top
            };

            _headerBadgeText = new TextBlock
            {
                Foreground = Brushes.White,
                FontWeight = FontWeights.Medium,
                FontSize = 13
            };
            headerBadge.Child = _headerBadgeText;
            headerRight.Children.Add(headerBadge);

            Grid.SetColumn(headerRight, 1);
            header.Children.Add(headerRight);

            var actionPanel = CreateCard();
            actionPanel.Margin = new Thickness(0, 20, 0, 20);
            Grid.SetRow(actionPanel, 1);
            root.Children.Add(actionPanel);

            var actionGrid = new Grid { Margin = new Thickness(24) };
            actionPanel.Child = actionGrid;
            actionGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            actionGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            actionGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var actionTitleRow = new Grid();
            actionTitleRow.ColumnDefinitions.Add(new ColumnDefinition());
            actionTitleRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            actionGrid.Children.Add(actionTitleRow);

            var actionTitleStack = new StackPanel();
            _actionTitleText = new TextBlock
            {
                FontSize = 22,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(Color.FromRgb(15, 23, 42))
            };
            actionTitleStack.Children.Add(_actionTitleText);
            actionTitleRow.Children.Add(actionTitleStack);

            _statusBadge = new Border
            {
                CornerRadius = new CornerRadius(999),
                Padding = new Thickness(14, 8, 14, 8),
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center
            };
            _statusText = new TextBlock
            {
                FontSize = 13,
                FontWeight = FontWeights.SemiBold
            };
            _statusBadge.Child = _statusText;
            Grid.SetColumn(_statusBadge, 1);
            actionTitleRow.Children.Add(_statusBadge);

            var notePanel = CreateTintedPanel(Color.FromRgb(255, 247, 237));
            notePanel.Margin = new Thickness(0, 20, 0, 20);
            _noteText = new TextBlock
            {
                FontSize = 13,
                Foreground = new SolidColorBrush(Color.FromRgb(154, 52, 18)),
                TextWrapping = TextWrapping.Wrap
            };
            notePanel.Child = _noteText;
            Grid.SetRow(notePanel, 1);
            actionGrid.Children.Add(notePanel);

            var controls = new Grid();
            controls.ColumnDefinitions.Add(new ColumnDefinition());
            Grid.SetRow(controls, 2);
            actionGrid.Children.Add(controls);

            var left = new StackPanel();
            _dangerText = new TextBlock
            {
                FontSize = 14,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(Color.FromRgb(185, 28, 28)),
                TextWrapping = TextWrapping.Wrap,
                MaxWidth = 520
            };
            left.Children.Add(_dangerText);

            var buttons = new WrapPanel
            {
                Margin = new Thickness(0, 18, 0, 0)
            };

            _disableButton = CreatePrimaryButton(string.Empty, Color.FromRgb(190, 24, 93));
            _revertButton = CreatePrimaryButton(string.Empty, Color.FromRgb(37, 99, 235));

            _disableButton.Click += async (_, __) => await RunWorkflowAsync(WorkflowKind.Disable);
            _revertButton.Click += async (_, __) => await RunWorkflowAsync(WorkflowKind.Revert);

            buttons.Children.Add(_disableButton);
            buttons.Children.Add(_revertButton);
            left.Children.Add(buttons);
            controls.Children.Add(left);

            var logPanel = CreateCard();
            Grid.SetRow(logPanel, 2);
            root.Children.Add(logPanel);

            var logGrid = new Grid { Margin = new Thickness(24) };
            logPanel.Child = logGrid;
            logGrid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            logGrid.RowDefinitions.Add(new RowDefinition());

            var logHeader = new Grid();
            logHeader.ColumnDefinitions.Add(new ColumnDefinition());
            logHeader.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            logGrid.Children.Add(logHeader);

            var logHeaderLeft = new StackPanel();
            _logTitleText = new TextBlock
            {
                FontSize = 22,
                FontWeight = FontWeights.SemiBold,
                Foreground = new SolidColorBrush(Color.FromRgb(15, 23, 42))
            };
            _logSubtitleText = new TextBlock
            {
                Margin = new Thickness(0, 6, 0, 0),
                FontSize = 13,
                Foreground = new SolidColorBrush(Color.FromRgb(100, 116, 139))
            };
            logHeaderLeft.Children.Add(_logTitleText);
            logHeaderLeft.Children.Add(_logSubtitleText);
            logHeader.Children.Add(logHeaderLeft);

            _copyLogButton = CreateGhostButton(string.Empty);
            _copyLogButton.Width = 110;
            _copyLogButton.Click += (_, __) => CopyLog();
            Grid.SetColumn(_copyLogButton, 1);
            logHeader.Children.Add(_copyLogButton);

            _logBox = new TextBox
            {
                Margin = new Thickness(0, 20, 0, 0),
                Padding = new Thickness(16),
                Background = new SolidColorBrush(Color.FromRgb(248, 250, 252)),
                BorderBrush = new SolidColorBrush(Color.FromRgb(226, 232, 240)),
                BorderThickness = new Thickness(1),
                FontFamily = new FontFamily("Cascadia Mono"),
                FontSize = 13,
                IsReadOnly = true,
                TextWrapping = TextWrapping.Wrap,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Auto,
                AcceptsReturn = true
            };
            Grid.SetRow(_logBox, 1);
            logGrid.Children.Add(_logBox);

            ApplyLanguage(false);
            SetStatus(StatusKind.Ready);
            AppendLog(L("Native Windows executable loaded.", "原生 Windows 可执行程序已加载。"));
            AppendLog(L("This app wraps the original script inside a modern desktop UI.", "这个应用把原始脚本封装进了现代桌面图形界面。"));
            AppendLog(L("Clicking Disable Protections or Revert Changes will restart the computer immediately.", "点击“关闭保护”或“还原改动”后，电脑会立即重启。"));
        }

        protected override void OnSourceInitialized(EventArgs e)
        {
            base.OnSourceInitialized(e);
            ApplyModernWindowEffects();
        }

        private async Task RunWorkflowAsync(WorkflowKind kind)
        {
            if (_isRunning)
            {
                MessageBox.Show(this, L("A workflow is already running.", "已有任务正在运行。"), L("Busy", "忙碌"), MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            var confirmMessage = kind == WorkflowKind.Disable
                ? L("This will lower Windows security protections for the current workflow. Continue?", "这会降低当前流程所需的 Windows 安全保护。是否继续？")
                : L("This will restore the settings previously changed by the tool. Continue?", "这会恢复工具之前改动过的设置。是否继续？");

            if (MessageBox.Show(this, confirmMessage, Title, MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
            {
                return;
            }

            _isRunning = true;
            SetButtonsEnabled(false);
            SetStatus(StatusKind.Running);
            AppendLog(string.Empty);
            AppendLog("============================================================");
            AppendLog(L("Starting workflow: ", "开始执行流程：") + GetWorkflowName(kind));
            AppendLog(L("Timestamp: ", "时间：") + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));

            try
            {
                var scriptPath = ExtractEmbeddedScript();
                AppendLog(L("Embedded script extracted to: ", "内嵌脚本已释放到：") + scriptPath);

                var modeArgument = kind == WorkflowKind.Disable ? "--continue" : "--revert";
                var restartArgument = "--restart-now";
                var args = "/c \"\"" + scriptPath + "\" " + modeArgument + " " + restartArgument + "\"";

                var startInfo = new ProcessStartInfo
                {
                    FileName = Environment.GetEnvironmentVariable("ComSpec") ?? "cmd.exe",
                    Arguments = args,
                    WorkingDirectory = Path.GetDirectoryName(scriptPath) ?? AppDomain.CurrentDomain.BaseDirectory,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                };

                using (var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true })
                {
                    process.OutputDataReceived += (_, e) =>
                    {
                        if (!string.IsNullOrWhiteSpace(e.Data))
                        {
                            Dispatcher.Invoke(() => AppendLog(e.Data));
                        }
                    };

                    process.ErrorDataReceived += (_, e) =>
                    {
                        if (!string.IsNullOrWhiteSpace(e.Data))
                        {
                            Dispatcher.Invoke(() => AppendLog("[stderr] " + e.Data));
                        }
                    };

                    process.Start();
                    process.BeginOutputReadLine();
                    process.BeginErrorReadLine();
                    await Task.Run(() => process.WaitForExit());

                    if (process.ExitCode == 0)
                    {
                        SetStatus(StatusKind.Completed);
                        AppendLog(L("Workflow completed successfully.", "流程已成功完成。"));
                        AppendLog(L("The script was instructed to restart immediately if needed.", "脚本已设置为在需要时立即重启。"));
                    }
                    else
                    {
                        SetStatus(StatusKind.Attention);
                        AppendLog(L("Workflow exited with code ", "流程退出，代码：") + process.ExitCode + ".");
                        MessageBox.Show(this, L("The workflow ended with a non-zero exit code. Review the log for details.", "流程以非零退出码结束，请查看日志了解详情。"), Title, MessageBoxButton.OK, MessageBoxImage.Warning);
                    }
                }
            }
            catch (Exception ex)
            {
                SetStatus(StatusKind.Failed);
                AppendLog(L("Launch failed: ", "启动失败：") + ex.Message);
                MessageBox.Show(this, ex.Message, L("Launch failed", "启动失败"), MessageBoxButton.OK, MessageBoxImage.Error);
            }
            finally
            {
                _isRunning = false;
                SetButtonsEnabled(true);
            }
        }

        private void CopyLog()
        {
            try
            {
                Clipboard.SetText(_logBox.Text ?? string.Empty);
                AppendLog(L("Log copied to clipboard.", "日志已复制到剪贴板。"));
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, L("Copy failed", "复制失败"), MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void ToggleLanguage()
        {
            _isChinese = !_isChinese;
            ApplyLanguage(true);
        }

        private void ApplyLanguage(bool logChange)
        {
            Title = L("Denuvo Environment One-Click Config Tool", "Denuvo环境一键配置工具");
            _headerTitleText.Text = L("Denuvo Environment One-Click Config Tool", "Denuvo环境一键配置工具");
            _headerBadgeText.Text = L("One-Click Tool", "一键工具");
            _languageButton.Content = _isChinese ? "EN" : "中文";

            _actionTitleText.Text = L("Action Center", "操作中心");
            _noteText.Text = L(
                "This tool can disable VBS, Memory Integrity, Credential Guard, System Guard, Windows Hello protection, and the Windows hypervisor. The app runs elevated so the workflow can complete cleanly.",
                "这个工具可以关闭 VBS、内存完整性、Credential Guard、System Guard、Windows Hello 保护以及 Windows Hypervisor。程序会以管理员权限运行，确保流程可以顺利完成。");
            _dangerText.Text = L(
                "Clicking Disable Protections or Revert Changes will restart the computer immediately and apply the changes.",
                "单击“关闭保护”或“还原改动”后，电脑会立即重启，并在重启后生效。");
            _disableButton.Content = L("Disable Protections", "关闭保护");
            _revertButton.Content = L("Revert Changes", "还原改动");

            _logTitleText.Text = L("Live Output", "实时输出");
            _logSubtitleText.Text = L(
                "This replaces most of the black-console experience with a readable activity feed.",
                "这里会用更易读的活动日志，替代大部分黑框控制台体验。");
            _copyLogButton.Content = L("Copy Log", "复制日志");

            SetStatus(_currentStatus);

            if (logChange)
            {
                AppendLog(L("Language switched to English.", "语言已切换为中文。"));
            }
        }

        private void ApplyModernWindowEffects()
        {
            try
            {
                var helper = new WindowInteropHelper(this);
                if (helper.Handle == IntPtr.Zero)
                {
                    return;
                }

                var disableDarkCaption = 0;
                DwmSetWindowAttribute(helper.Handle, DwmWindowAttributeUseImmersiveDarkMode, ref disableDarkCaption, Marshal.SizeOf<int>());

                var roundedCorners = 2;
                DwmSetWindowAttribute(helper.Handle, DwmWindowAttributeWindowCornerPreference, ref roundedCorners, Marshal.SizeOf<int>());

                var micaBackdrop = 2;
                DwmSetWindowAttribute(helper.Handle, DwmWindowAttributeSystemBackdropType, ref micaBackdrop, Marshal.SizeOf<int>());
            }
            catch
            {
            }
        }

        private string ExtractEmbeddedScript()
        {
            var baseDir = Path.Combine(Path.GetTempPath(), "VbsManagerApp");
            Directory.CreateDirectory(baseDir);

            var scriptPath = Path.Combine(baseDir, "VBS.cmd");
            var assembly = Assembly.GetExecutingAssembly();

            using (var stream = assembly.GetManifestResourceStream("VbsManagerApp.Resources.VBS.cmd"))
            {
                if (stream == null)
                {
                    throw new FileNotFoundException(L("Embedded VBS script not found inside the executable.", "可执行文件内部没有找到内嵌的 VBS 脚本。"));
                }

                using (var file = File.Create(scriptPath))
                {
                    stream.CopyTo(file);
                }
            }

            return scriptPath;
        }

        private void SetButtonsEnabled(bool enabled)
        {
            _disableButton.IsEnabled = enabled;
            _revertButton.IsEnabled = enabled;
            _languageButton.IsEnabled = enabled;
        }

        private void SetStatus(StatusKind kind)
        {
            _currentStatus = kind;

            Color foreground;
            Color background;
            string text;

            switch (kind)
            {
                case StatusKind.Running:
                    foreground = Color.FromRgb(147, 51, 234);
                    background = Color.FromRgb(243, 232, 255);
                    text = L("Running", "处理中");
                    break;
                case StatusKind.Completed:
                    foreground = Color.FromRgb(21, 128, 61);
                    background = Color.FromRgb(220, 252, 231);
                    text = L("Completed", "已完成");
                    break;
                case StatusKind.Attention:
                    foreground = Color.FromRgb(180, 83, 9);
                    background = Color.FromRgb(254, 243, 199);
                    text = L("Attention Needed", "需要注意");
                    break;
                case StatusKind.Failed:
                    foreground = Color.FromRgb(185, 28, 28);
                    background = Color.FromRgb(254, 226, 226);
                    text = L("Failed", "失败");
                    break;
                default:
                    foreground = Color.FromRgb(14, 116, 144);
                    background = Color.FromRgb(224, 242, 254);
                    text = string.Empty;
                    break;
            }

            _statusText.Text = text;
            _statusText.Foreground = new SolidColorBrush(foreground);
            _statusBadge.Background = new SolidColorBrush(background);
            _statusBadge.Visibility = string.IsNullOrEmpty(text) ? Visibility.Collapsed : Visibility.Visible;
        }

        private void AppendLog(string message)
        {
            _logBox.AppendText(message + Environment.NewLine);
            _logBox.ScrollToEnd();
        }

        private string GetWorkflowName(WorkflowKind kind)
        {
            return kind == WorkflowKind.Disable ? L("Disable protections", "关闭保护") : L("Revert changes", "还原改动");
        }

        private string L(string english, string chinese)
        {
            return _isChinese ? chinese : english;
        }

        private static Border CreateCard()
        {
            return new Border
            {
                CornerRadius = new CornerRadius(24),
                Background = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromRgb(226, 232, 240)),
                BorderThickness = new Thickness(1),
                SnapsToDevicePixels = true
            };
        }

        private static Border CreateTintedPanel(Color color)
        {
            return new Border
            {
                CornerRadius = new CornerRadius(18),
                Background = new SolidColorBrush(color),
                Padding = new Thickness(16)
            };
        }

        private static Button CreatePrimaryButton(string text, Color color)
        {
            return new Button
            {
                Content = text,
                Width = 180,
                Height = 46,
                Margin = new Thickness(0, 0, 12, 0),
                Background = new SolidColorBrush(color),
                Foreground = Brushes.White,
                BorderThickness = new Thickness(0),
                FontSize = 14,
                FontWeight = FontWeights.SemiBold,
                Cursor = System.Windows.Input.Cursors.Hand
            };
        }

        private static Button CreateGhostButton(string text)
        {
            return new Button
            {
                Content = text,
                Width = 160,
                Height = 46,
                Margin = new Thickness(0),
                Background = new SolidColorBrush(Color.FromRgb(241, 245, 249)),
                Foreground = new SolidColorBrush(Color.FromRgb(15, 23, 42)),
                BorderBrush = new SolidColorBrush(Color.FromRgb(203, 213, 225)),
                BorderThickness = new Thickness(1),
                FontSize = 14,
                FontWeight = FontWeights.Medium,
                Cursor = System.Windows.Input.Cursors.Hand
            };
        }

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int valueSize);
    }
}
