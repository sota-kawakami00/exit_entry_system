import 'dart:async';
import 'dart:js_util' as js_util;
import 'package:exit_entry_system/service/firebase_service.dart';
import 'package:exit_entry_system/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:ai_barcode/ai_barcode.dart';
import 'package:flutter/foundation.dart';
import 'package:js/js.dart' if (dart.library.html) 'package:js/js.dart';

// JSのjsQRライブラリが利用可能か確認する関数
bool isJsQRAvailable() {
  if (kIsWeb) {
    try {
      final jsQRExists = js_util.getProperty(js_util.globalThis, 'jsQR') != null;
      return jsQRExists;
    } catch (e) {
      print('JSQRチェックエラー: $e');
      return false;
    }
  }
  return false;
}

class QRScanner extends StatefulWidget {
  const QRScanner({super.key});

  @override
  QRScannerState createState() => QRScannerState();
}

class QRScannerState extends State<QRScanner> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isScanning = true;
  String _lastScannedCode = '';
  DateTime? _lastScanTime;
  Timer? _scanCooldownTimer;
  String _statusMessage = 'QRコードをスキャンしてください';
  bool _isError = false;
  bool _isCameraInitialized = false;
  bool _mounted = true;
  bool _isJsQRAvailable = false;

  // アニメーション関連の変数
  late AnimationController _checkmarkController;
  late Animation<double> _checkmarkAnimation;
  bool _showCheckmark = false;

  // デバッグログリスト
  List<String> _debugLogs = [];
  bool _showDebugPanel = false;

  // Firebaseの接続状態とデータ状態
  bool _isFirebaseConnected = false;
  List<UserModel> _cachedUsers = [];
  DateTime? _lastFirebaseCheck;

  // AIBarcodeスキャナーのコントローラー
  late ScannerController _scannerController;

  // カメラのフレームレート制御のための変数
  Timer? _scanningTimer;
  bool _processingQRCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _addDebugLog("QRScanner初期化開始");

    // Webブラウザでの実行時にjsQRライブラリの存在確認
    if (kIsWeb) {
      _isJsQRAvailable = isJsQRAvailable();
      _addDebugLog("jsQRライブラリ利用可能: $_isJsQRAvailable");

      if (!_isJsQRAvailable) {
        _addDebugLog("警告: jsQRライブラリが見つかりません。index.htmlにスクリプトタグを追加してください。");
      }
    }

    // チェックマークアニメーションの初期化
    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _checkmarkAnimation = CurvedAnimation(
      parent: _checkmarkController,
      curve: Curves.elasticOut,
    );

    _checkmarkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // アニメーション完了後、2秒後にチェックマークを非表示にする
        Timer(const Duration(seconds: 2), () {
          if (_mounted) {
            setState(() {
              _showCheckmark = false;
            });
          }
        });
      }
    });

    // スキャナーの設定
    _configureBarcodeScanner();

    // Firebase接続をチェック
    _checkFirebaseConnection();

    // ウィジェットがビルドされた後にカメラを初期化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  // Firebaseの接続状態をチェック
  Future<void> _checkFirebaseConnection() async {
    _addDebugLog("Firebase接続チェック開始");
    try {
      // 全ユーザーを取得してキャッシュ
      _cachedUsers = await _firebaseService.getAllUsers();
      _lastFirebaseCheck = DateTime.now();
      _isFirebaseConnected = true;
      _addDebugLog("Firebase接続成功: ${_cachedUsers.length}人のユーザーを取得");

      // ユーザーデータの詳細をデバッグログに追加
      if (_cachedUsers.isEmpty) {
        _addDebugLog("警告: ユーザーデータが存在しません");
      } else {
        _addDebugLog("ユーザーデータ概要:");
        for (var user in _cachedUsers) {
          _addDebugLog("- ID: ${user.id}, 名前: ${user.name}, QRコード: ${user.qrCode}");
        }
      }
    } catch (e) {
      _isFirebaseConnected = false;
      _addDebugLog("Firebase接続エラー: $e");
    }
  }

  // 指定されたQRコードに一致するユーザーをキャッシュから検索
  UserModel? _findUserInCache(String qrCode) {
    for (var user in _cachedUsers) {
      if (user.qrCode == qrCode) {
        return user;
      }
    }
    return null;
  }

  // バーコードスキャナーの設定
  void _configureBarcodeScanner() {
    try {
      _addDebugLog("バーコードスキャナーを設定中");

      // スキャナーコントローラーの設定
      _scannerController = ScannerController(
        scannerResult: (String qrCode) {
          // Web環境での疑似QRコード結果を無視
          if (kIsWeb && qrCode.contains("after 10 second ,web code result doing")) {
            _addDebugLog("無効なQRコードをスキップ: $qrCode");
            return;
          }

          _addDebugLog("QRコード検出: $qrCode");
          _onQRCodeDetected(qrCode);
        },
        // 以下のオプションも追加可能
      );

      _addDebugLog("バーコードスキャナー設定完了");
    } catch (e) {
      _addDebugLog("バーコードスキャナー設定エラー: $e");
    }
  }

  // デバッグログを追加
  void _addDebugLog(String log) {
    print(log); // コンソールにも出力
    if (_mounted) {
      setState(() {
        final timestamp = DateTime.now().toString().split('.').first;
        _debugLogs.add("[$timestamp] $log");
        // 最大100件までログを保持
        if (_debugLogs.length > 100) {
          _debugLogs.removeAt(0);
        }
      });
    }
  }

  // デバッグパネルの表示/非表示を切り替え
  void _toggleDebugPanel() {
    setState(() {
      _showDebugPanel = !_showDebugPanel;

      // デバッグパネルを表示する際にFirebase接続を再確認
      if (_showDebugPanel) {
        final now = DateTime.now();
        if (_lastFirebaseCheck == null ||
            now.difference(_lastFirebaseCheck!).inMinutes > 5) {
          _checkFirebaseConnection();
        }
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      // カメラ初期化前のステータス更新
      if (mounted) {
        setState(() {
          _statusMessage = 'カメラを初期化中...';
        });
      }

      _addDebugLog("カメラ初期化開始");

      // カメラの初期化前にクリーンアップ
      if (_isCameraInitialized) {
        try {
          await _scannerController.stopCameraPreview();
          _addDebugLog("既存のカメラプレビューを停止");
        } catch (e) {
          _addDebugLog("既存のカメラプレビュー停止エラー: $e");
        }
      }

      // Webブラウザでのカメラ初期化の特別な処理
      if (kIsWeb) {
        _addDebugLog("Webプラットフォームでカメラを初期化します");
        // jsQRライブラリの存在を再確認
        if (!_isJsQRAvailable) {
          _isJsQRAvailable = isJsQRAvailable();
          if (!_isJsQRAvailable) {
            _addDebugLog("警告: jsQRライブラリが見つかりません");
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QRスキャン機能の初期化に失敗しました。jsQRライブラリが必要です。'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }

      // カメラプレビューを開始（少し遅延を入れて安定性を向上）
      await Future.delayed(const Duration(milliseconds: 1000));

      // カメラプレビュー開始のタイムアウト処理
      bool cameraStarted = false;

      // カメラ起動タイムアウト処理
      Timer cameraTimeout = Timer(const Duration(seconds: 10), () {
        if (!cameraStarted && mounted) {
          _addDebugLog("カメラ初期化タイムアウト - 再試行します");
          // 強制的に再初期化
          _restartCamera(forceRestart: true);
        }
      });

      // カメラプレビュー開始
      await _scannerController.startCameraPreview();
      cameraStarted = true;
      cameraTimeout.cancel();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'QRコードをスキャンしてください';
        });
      }

      _addDebugLog("カメラ初期化完了");

      // スキャナーの定期的なチェックを開始
      _startPeriodicScanning();

    } catch (e) {
      _addDebugLog('カメラ初期化エラー: $e');
      if (mounted) {
        setState(() {
          _statusMessage = 'カメラ初期化エラー - 再試行してください';
          _isError = true;
        });
      }
    }
  }

  // 定期的なスキャン処理を開始
  void _startPeriodicScanning() {
    _scanningTimer?.cancel();
    _scanningTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_mounted && _isCameraInitialized && !_processingQRCode) {
        // カメラがアクティブであることを確認するための心拍
        _addDebugLog("スキャナー心拍チェック");

        // カメラが正常に動作していることを確認するために、
        // 必要に応じてここでスキャナーの状態をリフレッシュするロジックを追加
        try {
          // スキャナーの状態をリフレッシュ（任意）
          // この部分は使用しているライブラリによって異なる場合があります
        } catch (e) {
          _addDebugLog("スキャナーリフレッシュエラー: $e");
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _addDebugLog("アプリライフサイクル状態変更: $state");

    // アプリがバックグラウンドから復帰したときにカメラを再初期化
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
      _checkFirebaseConnection(); // Firebase接続も再確認
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // カメラリソースの解放
      try {
        _scannerController.stopCameraPreview();
        _scanningTimer?.cancel();
        _addDebugLog("カメラプレビュー停止（ライフサイクル変更による）");
      } catch (e) {
        _addDebugLog("カメラ停止エラー（ライフサイクル）: $e");
      }
    }
  }

  @override
  void dispose() {
    _addDebugLog("QRScanner破棄開始");
    _mounted = false;
    WidgetsBinding.instance.removeObserver(this);
    _scanCooldownTimer?.cancel();
    _scanningTimer?.cancel();
    _checkmarkController.dispose(); // アニメーションコントローラーの破棄

    // カメラプレビューの停止を try-catch で囲む
    try {
      _scannerController.stopCameraPreview();
      _addDebugLog("カメラプレビュー停止成功");
    } catch (e) {
      _addDebugLog('カメラ停止エラー: $e');
    }

    super.dispose();
  }

  // QRコードが検出された時の処理
  void _onQRCodeDetected(String qrCode) async {
    _addDebugLog("QRコード処理開始: $qrCode");

    // QRコードをクリーニング - 余分な空白や改行の削除
    qrCode = qrCode.trim();

    // クールダウン中または処理中の場合はスキップ
    if (!_isScanning || _processingQRCode) {
      _addDebugLog("スキャン中断: スキャン停止中またはクールダウン中");
      return;
    }

    // マウント状態チェック
    if (!mounted || !_mounted) {
      _addDebugLog("スキャン中断: ウィジェットがマウントされていません");
      return;
    }

    // 空のQRコードは処理しない
    if (qrCode.isEmpty) {
      _addDebugLog("スキャン中断: 空のQRコード");
      return;
    }

    // 同じQRコードの連続スキャンを防止
    if (_lastScannedCode == qrCode) {
      final now = DateTime.now();
      if (_lastScanTime != null) {
        final difference = now.difference(_lastScanTime!);
        if (difference.inSeconds < 3) {
          _addDebugLog("スキャン中断: 3秒以内の同一QRコード");
          return;
        }
      }
    }

    // 処理中フラグを設定
    _processingQRCode = true;

    setState(() {
      _isScanning = false;
      _lastScannedCode = qrCode;
      _lastScanTime = DateTime.now();
      _statusMessage = 'QRコードを処理中...';
    });

    try {
      _addDebugLog("Firebaseからユーザー情報取得中: $qrCode");

      // デバッグモードの場合はキャッシュから先に検索
      if (_showDebugPanel) {
        UserModel? cachedUser = _findUserInCache(qrCode);
        if (cachedUser != null) {
          _addDebugLog("キャッシュ内でユーザーを発見: ${cachedUser.name} (ID: ${cachedUser.id})");
        } else {
          _addDebugLog("キャッシュ内にユーザーが見つかりません: $qrCode");

          // 現在のキャッシュ内容を表示
          _addDebugLog("現在のキャッシュ内容 (${_cachedUsers.length}人):");
          for (var user in _cachedUsers) {
            _addDebugLog("- ID: ${user.id}, 名前: ${user.name}, QRコード: ${user.qrCode}");
          }
        }
      }

      // QRコードからユーザーを取得
      final user = await _firebaseService.getUserByQRCode(qrCode);

      // マウント状態の再チェック（非同期処理中に変わる可能性があるため）
      if (!_mounted) {
        _addDebugLog("処理中断: 非同期処理中にウィジェットがアンマウントされました");
        _processingQRCode = false;
        return;
      }

      if (user == null) {
        _addDebugLog("ユーザーが見つかりません: $qrCode");

        // デバッグモードの場合は詳細な診断情報を表示
        if (_showDebugPanel) {
          _addDebugLog("QRコード検証:");
          _addDebugLog("- QRコード形式: ${qrCode.length}文字, 全て数字: ${int.tryParse(qrCode) != null}");
          _addDebugLog("- Firebase接続状態: ${_isFirebaseConnected ? 'OK' : 'エラー'}");

          // Firebase再チェック
          _addDebugLog("Firebase再チェック実行中...");
          try {
            await _checkFirebaseConnection();
          } catch (e) {
            _addDebugLog("Firebase再チェック中にエラー: $e");
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ユーザーが見つかりません。QRコードを確認してください。')),
          );
        }
        setState(() {
          _isScanning = true;
          _statusMessage = 'QRコードをスキャンしてください';
        });
        _processingQRCode = false;
        return;
      }

      _addDebugLog("ユーザー取得成功: ${user.name}, 現在の状態: ${user.isPresent ? '在室中' : '不在'}");

      // ユーザーの現在のステータスを確認して切り替え
      bool isEntering = !user.isPresent; // 現在の状態を反転

      // 更新されたユーザーモデル
      final updatedUser = user.copyWith(
        isPresent: isEntering,
        lastEntryTime: isEntering ? DateTime.now() : user.lastEntryTime,
        lastExitTime: !isEntering ? DateTime.now() : user.lastExitTime,
      );

      _addDebugLog("ユーザー状態を更新中: ${isEntering ? '入室' : '退室'}");

      // ユーザー状態を更新
      await _firebaseService.updateUser(updatedUser);

      if (!_mounted) {
        _processingQRCode = false;
        return;
      }

      // ログエントリを作成
      await _firebaseService.createEntryLog(user.id, user.name, isEntering);

      if (!_mounted) {
        _processingQRCode = false;
        return;
      }

      _addDebugLog("処理完了: ${user.name}が${isEntering ? '入室' : '退室'}しました");

      // チェックマークアニメーションを表示
      setState(() {
        _showCheckmark = true;
      });
      _checkmarkController.reset();
      _checkmarkController.forward();

      // 通知を表示
      _showFeedback(user.name, isEntering);

      // クールダウン後にスキャンを再開
      _scanCooldownTimer?.cancel(); // 既存のタイマーをキャンセル
      _scanCooldownTimer = Timer(const Duration(seconds: 3), () {
        if (_mounted && mounted) {
          setState(() {
            _isScanning = true;
            _statusMessage = 'QRコードをスキャンしてください';
          });
          _processingQRCode = false;
          _addDebugLog("スキャン再開準備完了");
        }
      });
    } catch (e) {
      _addDebugLog("エラー発生: $e");

      // エラーのスタックトレースも表示（デバッグモードの場合）
      if (_showDebugPanel) {
        _addDebugLog("エラーの詳細:");
        _addDebugLog(e.toString());

        // Firebase接続の再確認
        _addDebugLog("Firebase接続を再確認中...");
        try {
          await _checkFirebaseConnection();
        } catch (e2) {
          _addDebugLog("Firebase再接続エラー: $e2");
        }
      }

      if (_mounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );

        setState(() {
          _isScanning = true;
          _statusMessage = 'QRコードをスキャンしてください';
        });
        _processingQRCode = false;
      }
    }
  }

  // QRコードの手動入力
  void _manualQRCodeEntry() {
    if (!_mounted) return;

    final TextEditingController qrController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('QRコードを手動入力'),
          content: TextField(
            controller: qrController,
            decoration: const InputDecoration(
              hintText: 'QRコード値を入力してください',
            ),
            keyboardType: TextInputType.text,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final qrCode = qrController.text.trim();
                if (qrCode.isNotEmpty) {
                  Navigator.of(context).pop();
                  _addDebugLog("手動入力されたQRコード: $qrCode");
                  _onQRCodeDetected(qrCode);
                }
              },
              child: const Text('送信'),
            ),
          ],
        );
      },
    );
  }

  // ユーザーリスト表示ダイアログ
  // ユーザーリスト表示ダイアログ
  void _showUserList() {
    if (!_mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          child: Container(
            width: double.maxFinite,
            height: 480,
            padding: EdgeInsets.all(0),
            child: Column(
              children: [
                // ヘッダー部分
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '登録ユーザー一覧',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // ユーザー数表示
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 18, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        '${_cachedUsers.length}人のユーザーが登録されています',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // リスト部分
                Expanded(
                  child: _cachedUsers.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'ユーザーが見つかりません',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.separated(
                    itemCount: _cachedUsers.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = _cachedUsers[index];
                      final isPresent = user.isPresent;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPresent
                              ? Colors.green.shade100
                              : Colors.red.shade50,
                          child: Icon(
                            isPresent ? Icons.login : Icons.logout,
                            color: isPresent ? Colors.green.shade700 : Colors.red.shade400,
                          ),
                        ),
                        title: Text(
                          user.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Text(
                              user.qrCode,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPresent
                                ? Colors.green.shade100
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPresent ? '在室中' : '不在',
                            style: TextStyle(
                              color: isPresent
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _addDebugLog("リストから選択されたユーザー: ${user.name}");
                          _onQRCodeDetected(user.qrCode);
                        },
                      );
                    },
                  ),
                ),
                // フッターボタン
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.refresh, size: 18),
                        label: Text('最新の情報に更新'),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          // リストを更新
                          await _checkFirebaseConnection();
                          // 再表示
                          _showUserList();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('閉じる'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFeedback(String userName, bool isEntering) {
    if (!_mounted || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEntering ? '$userNameが入室しました' : '$userNameが退室しました',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: isEntering ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 手動でカメラを再起動するメソッド
  void _restartCamera({bool forceRestart = false}) async {
    if (!_mounted) return;

    _addDebugLog("カメラ再起動開始" + (forceRestart ? " (強制)" : ""));

    setState(() {
      _isCameraInitialized = false;
      _statusMessage = 'カメラを再起動中...';
    });

    // タイマーをキャンセル
    _scanningTimer?.cancel();

    try {
      await _scannerController.stopCameraPreview();
      _addDebugLog("カメラプレビュー停止成功");
    } catch (e) {
      _addDebugLog('カメラ停止エラー: $e');
    }

    if (forceRestart) {
      // 強制再起動の場合はスキャナーを再設定
      _configureBarcodeScanner();
    }

    // 少し遅延を入れてからカメラを再起動
    await Future.delayed(const Duration(milliseconds: 1500));
    _initializeCamera();
  }

  // デバッグログをクリア
  void _clearDebugLogs() {
    setState(() {
      _debugLogs.clear();
      _addDebugLog("デバッグログをクリアしました");
    });
  }

  // デバッグパネル
  Widget _buildDebugPanel() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'デバッグパネル',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  // jsQRステータス（Webの場合のみ）
                  if (kIsWeb)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      margin: EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _isJsQRAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isJsQRAvailable ? 'jsQR：OK' : 'jsQR：NG',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  // Firebase状態表示
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isFirebaseConnected ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _isFirebaseConnected ? 'FB接続中' : 'FB未接続',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // ユーザーリスト表示ボタン
                  IconButton(
                    icon: Icon(Icons.people, color: Colors.white, size: 20),
                    onPressed: _showUserList,
                    tooltip: 'ユーザーリスト',
                  ),
                  // テスト用手動入力ボタン
                  IconButton(
                    icon: Icon(Icons.keyboard, color: Colors.white, size: 20),
                    onPressed: _manualQRCodeEntry,
                    tooltip: 'QRコードを手動入力',
                  ),
                  IconButton(
                    icon: Icon(Icons.clear_all, color: Colors.white, size: 20),
                    onPressed: _clearDebugLogs,
                    tooltip: 'ログをクリア',
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: _toggleDebugPanel,
                    tooltip: 'パネルを閉じる',
                  ),
                ],
              ),
            ],
          ),
          Divider(color: Colors.white30),
          // Firebase情報セクション
          Container(
            color: Colors.black45,
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firebase情報:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'ユーザー数: ${_cachedUsers.length}',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '最終確認: ${_lastFirebaseCheck?.toString() ?? '未確認'}',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                if (_lastScannedCode.isNotEmpty)
                  Text(
                    '最終スキャン: $_lastScannedCode',
                    style: TextStyle(color: Colors.yellow, fontSize: 12),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8),
          // ログセクション
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var log in _debugLogs.reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        log,
                        style: TextStyle(
                          color: log.contains('エラー') ? Colors.red :
                          log.contains('警告') ? Colors.yellow :
                          log.contains('成功') ? Colors.green : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 操作ボタン
          Container(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh, size: 16),
                  label: Text('FB再接続'),
                  onPressed: () async {
                    _addDebugLog("Firebase接続を手動で更新中...");
                    await _checkFirebaseConnection();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: Colors.blue,
                  ),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.camera_enhance, size: 16),
                  label: Text('カメラ再起動'),
                  onPressed: () => _restartCamera(forceRestart: true),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: Colors.orange,
                  ),
                ),
                if (kIsWeb)
                  ElevatedButton.icon(
                    icon: Icon(Icons.check_circle, size: 16),
                    label: Text('jsQR再確認'),
                    onPressed: () {
                      setState(() {
                        _isJsQRAvailable = isJsQRAvailable();
                        _addDebugLog("jsQRライブラリ状態: ${_isJsQRAvailable ? '利用可能' : '利用不可'}");
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      backgroundColor: Colors.purple,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // カメラプレビューとQRスキャナー
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: _isCameraInitialized
                ? PlatformAiBarcodeScannerWidget(
              platformScannerController: _scannerController,
            )
                : const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),

        // QRスキャンガイド
        if (_isCameraInitialized && !_showDebugPanel && !_showCheckmark)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),

        // 成功時のチェックマークアニメーション
        if (_showCheckmark)
          ScaleTransition(
            scale: _checkmarkAnimation,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 140,
              ),
            ),
          ),

        // Web用のカメラアクセス許可ボタン
        if (kIsWeb && !_isCameraInitialized && !_isError)
          ElevatedButton(
            onPressed: () {
              _initializeCamera();
            },
            child: const Text('カメラへのアクセスを許可'),
          ),

        // jsQRライブラリ未検出エラー（Webのみ）
        if (kIsWeb && !_isJsQRAvailable && !_isError)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'jsQRライブラリが見つかりません',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'index.htmlに必要なスクリプトを追加してください',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isJsQRAvailable = isJsQRAvailable();
                      _addDebugLog("jsQRライブラリ再確認: ${_isJsQRAvailable ? '利用可能' : '利用不可'}");
                    });
                  },
                  child: const Text('再確認'),
                ),
              ],
            ),
          ),

        // エラー時の再起動ボタン
        if (_isError)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'カメラの初期化に失敗しました',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('カメラを再起動'),
                  onPressed: () => _restartCamera(forceRestart: true),
                ),
              ],
            ),
          ),

        // 右上のボタン群
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              // カメラ再起動ボタン
              if (_isCameraInitialized)
                FloatingActionButton(
                  mini: true,
                  onPressed: () => _restartCamera(forceRestart: true),
                  backgroundColor: Colors.white.withOpacity(0.7),
                  child: const Icon(Icons.refresh, color: Colors.black),
                  tooltip: 'カメラを再起動',
                ),
              const SizedBox(height: 8),
              // QRコード手動入力ボタン
              FloatingActionButton(
                mini: true,
                onPressed: _manualQRCodeEntry,
                backgroundColor: Colors.white.withOpacity(0.7),
                child: const Icon(Icons.keyboard, color: Colors.black),
                tooltip: 'QRコードを手動入力',
              ),
              const SizedBox(height: 8),
              // ユーザーリスト表示ボタン
              FloatingActionButton(
                mini: true,
                onPressed: _showUserList,
                backgroundColor: Colors.white.withOpacity(0.7),
                child: const Icon(Icons.people, color: Colors.black),
                tooltip: 'ユーザーリスト',
              ),
              const SizedBox(height: 8),
              // デバッグモードボタン
              FloatingActionButton(
                mini: true,
                onPressed: _toggleDebugPanel,
                backgroundColor: _showDebugPanel
                    ? Colors.blue.withOpacity(0.7)
                    : Colors.white.withOpacity(0.7),
                child: Icon(
                  Icons.bug_report,
                  color: _showDebugPanel ? Colors.white : Colors.black,
                ),
                tooltip: 'デバッグモード',
              ),
            ],
          ),
        ),

        // デバッグパネル
        if (_showDebugPanel)
          Positioned.fill(
            child: _buildDebugPanel(),
          ),

        // ステータス表示（デバッグパネルが表示されていない時かつチェックマークが表示されていない時のみ）
        if (!_showDebugPanel && !_showCheckmark)
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                  if (_lastScannedCode.isNotEmpty && !_isScanning)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '検出されたコード: $_lastScannedCode',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}