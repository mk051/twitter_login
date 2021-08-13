import 'dart:html' as html;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twitter_login/src/exception.dart';

class AuthBrowser {
  late final String id;
  bool _isOpen = false;
  VoidCallback onClose;

  Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  AuthBrowser({required this.onClose}) {
    _isOpen = false;
  }

  Future methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case "onClose":
        onClose();
        _isOpen = false;
        break;
      default:
        return;
    }
  }

  ///　Open a web browser and log in to your Twitter account.
  Future<String?> doAuth(String url, String scheme) async {
    if (_isOpen) {
      throw PlatformException(code: 'AuthBrowser is opened.');
    }

    _isOpen = true;

    final SharedPreferences prefs = await _prefs;

    // localstorageを初期化
    prefs.remove('oauth_callback_url');

    var wnd = html.window.open(url, 'auth browser');

    // 認証処理待ち
    final callbackUrl = await _waitingWebAuthentication(wnd,1,100);
    if (callbackUrl.isEmpty) {
      throw CanceledByUserException();
    }

    //
    final token = prefs.getString("oauth_callback_url").toString();
    if (token.isEmpty) {
      throw CanceledByUserException();
    }

    // localstorageを初期化
    prefs.remove('oauth_callback_url');

    _isOpen = false;
    return token;
  }

  ///　Open a web browser and log in to your Twitter account.
  Future<bool> open(String url, String scheme) async {
    return false;
  }

  Future<String> _waitingWebAuthentication(html.WindowBase wnd,seconds,timeOut) async {

    final completer = Completer<String>();
    var callbackUrl = '';

    var counter = 0;
    Timer.periodic(
      Duration(seconds:seconds), // x秒毎にループ
        (timer) async {

        counter++;
        print(counter);

        if(true == wnd.closed) {
          // タイマーをクリア
          timer.cancel();

          // データ取得
          final SharedPreferences prefs = await _prefs;
          await prefs.reload();
          if(prefs.containsKey("oauth_callback_url")){
            callbackUrl = prefs.getString("oauth_callback_url")!;
          }

          if(!callbackUrl.isEmpty) {
            onClose();
            _isOpen = false;
          }

          // 結果を返却
          completer.complete(callbackUrl);
        }

        // タイムアウト
        if(counter == timeOut){
          timer.cancel();
          completer.complete('');
        }
      }
    );

    return completer.future;
  }
}
