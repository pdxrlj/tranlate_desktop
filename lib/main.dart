import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/config_service.dart';
import 'services/translation_service.dart';
import 'pages/settings_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'dart:io';

void main() async {
  try {
    // Ensure Flutter is initialized
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize hotkey manager
    await hotKeyManager.unregisterAll();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Initialize window manager
      await windowManager.ensureInitialized();

      // Configure window options
      WindowOptions windowOptions = WindowOptions(
        size: Size(800, 600),
        minimumSize: Size(400, 300),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: '智能翻译助手',
      );

      // Apply window options
      await windowManager.waitUntilReadyToShow(windowOptions);

      // Configure window settings after options are applied
      await Future.wait([
        windowManager.setPreventClose(true),
        windowManager.setSkipTaskbar(false),
        windowManager.show(),
        windowManager.focus(),
      ]);
    }

    // Initialize app services
    final prefs = await SharedPreferences.getInstance();
    final configService = ConfigService(prefs);

    // Run the app
    runApp(
      ChangeNotifierProvider<ConfigService>(
        create: (_) => configService,
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    print('Initialization error: $e');
    print('Stack trace: $stackTrace');
    windowManager.destroy();
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Translation Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: GoogleFonts.notoSans().fontFamily,
        textTheme: TextTheme(
          displayLarge: GoogleFonts.notoSans(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: GoogleFonts.notoSans(
            fontSize: 16,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.notoSans(
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  final TextEditingController _sourceController = TextEditingController();
  String _translatedText = '';
  bool _isLoading = false;
  bool _isConfigured = false;
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  bool _isExit = false;
  String _targetLanguage = 'zh'; // 默认目标语言为中文

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initSystemTray();
    _checkConfiguration();
    _registerHotkey();
  }

  Future<void> _registerHotkey() async {
    try {
      final hotKey = HotKey(
        KeyCode.keyL,
        modifiers: [KeyModifier.alt],
        scope: HotKeyScope.system,
      );

      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) async {
          debugPrint('Global hotkey Alt + L triggered');
          // 读取剪切板内容
          final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
          final clipboardText = clipboardData?.text ?? '';

          if (clipboardText.isNotEmpty) {
            // 显示窗口
            await _showWindow();

            // 更新输入框内容并触发翻译
            if (mounted) {
              setState(() {
                _sourceController.text = clipboardText;
                _sourceController.selection = TextSelection.fromPosition(
                  TextPosition(offset: clipboardText.length),
                );
              });
              _translate();
            }
          }
        },
      );

      debugPrint('Hotkey registered successfully');
    } catch (e) {
      debugPrint('Failed to register hotkey: $e');
    }
  }

  @override
  void dispose() {
    hotKeyManager.unregisterAll();
    windowManager.removeListener(this);
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    try {
      await _systemTray.initSystemTray(
        title: "智能翻译助手",
        iconPath:
            Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
      );

      await _menu.buildFrom([
        MenuItemLabel(label: '显示', onClicked: (menuItem) => _showWindow()),
        MenuItemLabel(label: '退出', onClicked: (menuItem) => _exitApp()),
      ]);

      await _systemTray.setContextMenu(_menu);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _showWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      debugPrint('Error initializing system tray: $e');
    }
  }

  Future<void> _showWindow() async {
    try {
      final primaryDisplay = await ScreenRetriever.instance.getPrimaryDisplay();
      final windowInfo = await windowManager.getSize();
      final x = (primaryDisplay.size.width - windowInfo.width) / 2;
      final y = (primaryDisplay.size.height - windowInfo.height) / 2;

      // 先将窗口移动到正确位置
      await windowManager.setPosition(Offset(x, y));
      
      // 平滑显示窗口
      await windowManager.show();
      await windowManager.focus();
      
      // 使用较低的 opacity 值开始
      await windowManager.setOpacity(0.0);
      await windowManager.setAlwaysOnTop(true);
      
      // 平滑地增加透明度
      for (double opacity = 0.0; opacity <= 1.0; opacity += 0.1) {
        await windowManager.setOpacity(opacity);
        await Future.delayed(Duration(milliseconds: 10));
      }
      
      // 确保最终透明度为 1.0
      await windowManager.setOpacity(1.0);
      await Future.delayed(const Duration(milliseconds: 100));
      await windowManager.setAlwaysOnTop(false);
      
      debugPrint('Window shown with smooth animation');
    } catch (e) {
      debugPrint('Error showing window: $e');
    }
  }

  Future<void> _exitApp() async {
    _isExit = true;
    // 并行执行销毁操作
    await Future.wait([
      _systemTray.destroy(),
      windowManager.destroy(),
    ]);
    // 强制退出应用
    exit(0);
  }

  void _checkConfiguration() {
    final config = Provider.of<ConfigService>(context, listen: false).config;
    setState(() {
      _isConfigured = config.apiKey.isNotEmpty;
    });
  }

  Future<void> _translate() async {
    if (_sourceController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final config = Provider.of<ConfigService>(context, listen: false).config;
      final translationService = TranslationService(config);
      final sourceText = _sourceController.text;
      
      String targetLang = _targetLanguage;
      if (_targetLanguage == 'auto') {
        // 检测文本是否包含中文字符
        final containsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(sourceText);
        targetLang = containsChinese ? 'en' : 'zh';
      }
      
      final result = await translationService.translate(sourceText, targetLang: targetLang);
      setState(() => _translatedText = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('翻译失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearText() {
    setState(() {
      _sourceController.clear();
      _translatedText = '';
    });
  }

  @override
  Future<bool> onWindowClose() async {
    if (_isExit) {
      return true;
    }

    bool? shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => PopScope(
        canPop: true,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF2C2C2C)
              : Colors.white,
          elevation: 10,
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                '确认操作',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请选择关闭方式：',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              _buildActionButton(
                context,
                icon: Icons.exit_to_app,
                title: '完全退出',
                subtitle: '关闭应用程序',
                onTap: () => Navigator.of(context).pop(true),
                color: Colors.red.shade100,
                textColor: Colors.red.shade700,
              ),
              SizedBox(height: 8),
              _buildActionButton(
                context,
                icon: Icons.minimize,
                title: '最小化到托盘',
                subtitle: '在后台继续运行',
                onTap: () => Navigator.of(context).pop(false),
                color: Colors.blue.shade100,
                textColor: Colors.blue.shade700,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                '取消',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldExit == null) {
      return false;
    } else if (shouldExit) {
      // 直接调用退出，不等待 onWindowClose 的返回
      _exitApp();
      return true;
    } else {
      await windowManager.hide();
      return false;
    }
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
    required Color textColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: textColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能翻译助手', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
              _checkConfiguration();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isConfigured)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade800),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '请先在设置中配置API信息',
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsPage(),
                                ),
                              );
                            },
                            child: const Text('去设置'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '源文本',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.translate,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            '目标语言',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                          width: 1.5,
                                        ),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                            Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                          ],
                                        ),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          inputDecorationTheme: InputDecorationTheme(
                                            border: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _targetLanguage,
                                            icon: Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: Theme.of(context).colorScheme.primary,
                                              size: 20,
                                            ),
                                            elevation: 4,
                                            borderRadius: BorderRadius.circular(12),
                                            dropdownColor: Theme.of(context).colorScheme.surface,
                                            focusColor: Colors.transparent,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            menuMaxHeight: 200,
                                            items: [
                                              DropdownMenuItem(
                                                value: 'zh',
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                    constraints: BoxConstraints(maxWidth: 120),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '中文',
                                                          style: TextStyle(
                                                            fontWeight: _targetLanguage == 'zh' ? FontWeight.w600 : FontWeight.normal,
                                                          ),
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text('🇨🇳', style: TextStyle(fontSize: 14)),
                                                        if (_targetLanguage == 'zh')
                                                          Padding(
                                                            padding: EdgeInsets.only(left: 6),
                                                            child: Icon(
                                                              Icons.check,
                                                              size: 16,
                                                              color: Theme.of(context).colorScheme.primary,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'en',
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                    constraints: BoxConstraints(maxWidth: 120),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '英文',
                                                          style: TextStyle(
                                                            fontWeight: _targetLanguage == 'en' ? FontWeight.w600 : FontWeight.normal,
                                                          ),
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text('🇬🇧', style: TextStyle(fontSize: 14)),
                                                        if (_targetLanguage == 'en')
                                                          Padding(
                                                            padding: EdgeInsets.only(left: 6),
                                                            child: Icon(
                                                              Icons.check,
                                                              size: 16,
                                                              color: Theme.of(context).colorScheme.primary,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'auto',
                                                child: Material(
                                                  color: Colors.transparent,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                    constraints: BoxConstraints(maxWidth: 120),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '自动',
                                                          style: TextStyle(
                                                            fontWeight: _targetLanguage == 'auto' ? FontWeight.w600 : FontWeight.normal,
                                                          ),
                                                        ),
                                                        SizedBox(width: 6),
                                                        Icon(
                                                          Icons.auto_awesome,
                                                          size: 16,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                        if (_targetLanguage == 'auto')
                                                          Padding(
                                                            padding: EdgeInsets.only(left: 6),
                                                            child: Icon(
                                                              Icons.check,
                                                              size: 16,
                                                              color: Theme.of(context).colorScheme.primary,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (String? newValue) {
                                              if (newValue != null) {
                                                setState(() {
                                                  _targetLanguage = newValue;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearText,
                                  tooltip: '清除文本',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _sourceController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: '请输入需要翻译的文本...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading || !_isConfigured
                                ? null
                                : _translate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text('翻译 (Alt+L)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_translatedText.isNotEmpty || _isLoading)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '翻译结果',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: _translatedText.isEmpty
                                    ? null
                                    : () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: _translatedText),
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('已复制到剪贴板'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                tooltip: '复制结果',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: SelectableText(
                              _translatedText.isEmpty
                                  ? '翻译结果将显示在这里'
                                  : _translatedText,
                              style: TextStyle(
                                color: _translatedText.isEmpty
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
