/*
 * Created with Android Studio.
 * User: whqfor
 * Date: 2020-02-03
 * Time: 14:20
 * email: wanghuaqiang@tal.com
 * tartget: flutter侧用户调用入口
 */

import 'dart:io';

import 'package:d_stack/constant/constant_config.dart';
import 'package:d_stack/d_stack.dart';
import 'package:d_stack/navigator/dnavigator_gesture_observer.dart';
import 'package:flutter/material.dart';

/// 主要两个部分：
/// 1.发送节点信息到Native，Native记录完整的路由信息
/// 2.处理Native发过来的指令，Native侧节点管理处理完节点信息，如果有指令过来，则flutter根据节点信息做相应的跳转事件

class DNavigatorManager {
  /// 1.发送节点信息到Native
  /// routeName 路由名，pageType native或者flutter, params 参数

  /// 获取navigator
  static NavigatorState get _navigator =>
      DStack.instance.navigatorKey.currentState;

  /// 推出页面
  static Future push(String routeName, PageType pageType,
      [Map params, bool maintainState]) {
    if (pageType == PageType.flutter) {
      DNavigatorManager.nodeHandle(
          routeName, pageType, DStackConstant.push, {});

      MaterialPageRoute route = DNavigatorManager.materialRoute(
          routeName: routeName, params: params, maintainState: maintainState);
      return _navigator.push(route);
    } else {
      DNavigatorManager.nodeHandle(
          routeName, pageType, DStackConstant.push, params);
      return Future.value(true);
    }
  }

  /// 弹出页面
  static Future present(String routeName, PageType pageType,
      [Map params, bool maintainState]) {
    if (pageType == PageType.flutter) {
      DNavigatorManager.nodeHandle(
          routeName, pageType, DStackConstant.present, {});
      PageRouteBuilder route =
          slideRoute(routeName: routeName, params: params, milliseconds: 300);
      return _navigator.push(route);
    } else {
      DNavigatorManager.nodeHandle(
          routeName, pageType, DStackConstant.present, params);
      return Future.value(true);
    }
  }

  /// 自定义进场方式
  static Future animationPage(
    String routeName,
    PageType pageType,
    AnimatedPageBuilder animatedBuilder, [
    Map params,
    Duration transitionDuration = const Duration(milliseconds: 300),
    bool opaque = true,
    bool barrierDismissible = false,
    Color barrierColor,
    String barrierLabel,
    bool maintainState = true,
    bool fullscreenDialog = false,
  ]) {
    if (pageType == PageType.flutter) {
      DNavigatorManager.nodeHandle(
          routeName, pageType, DStackConstant.push, {});
      PageRouteBuilder route = DNavigatorManager.animationRoute(
        animatedBuilder: animatedBuilder,
        routeName: routeName,
        params: params,
        transitionDuration: transitionDuration,
        opaque: opaque,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      );
      return _navigator.push(route);
    } else {
      DNavigatorManager.nodeHandle(
          routeName, pageType, DStackConstant.push, params);
      return Future.value(true);
    }
  }

  /// 提供外界直接传builder的能力
  static Future pushBuild(
      String routeName, PageType pageType, WidgetBuilder builder,
      [Map params, bool maintainState, bool fullscreenDialog]) {
    if (pageType == PageType.flutter) {
      DNavigatorManager.nodeHandle(
          routeName, PageType.flutter, DStackConstant.push, {});

      RouteSettings userSettings =
          RouteSettings(name: routeName, arguments: params);
      MaterialPageRoute route = MaterialPageRoute(
          settings: userSettings,
          builder: builder,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog);
      return _navigator.push(route);
    } else {
      DNavigatorManager.nodeHandle(
          routeName, pageType, DStackConstant.push, params);
      return Future.value(true);
    }
  }

  /// 目前只支持flutter使用，替换flutter页面
  static Future replace(String routeName, PageType pageType,
      {Map params, bool maintainState = true, bool homePage = false}) {
    DNavigatorManager.nodeHandle(
        routeName, pageType, DStackConstant.replace, params, homePage);

    if (pageType == PageType.flutter) {
      MaterialPageRoute route = DNavigatorManager.materialRoute(
          routeName: routeName, params: params, maintainState: maintainState);
      return _navigator.pushReplacement(route);
    } else {
      return Future.error('not flutter page');
    }
  }

  /// result 返回值，可为空
  /// pop可以不传路由信息
  static void pop([Map result]) {
    DNavigatorManager.nodeHandle(null, null, DStackConstant.pop, result);
  }

  static void popWithGesture() {
    DNavigatorManager.nodeHandle(null, null, DStackConstant.gesture);
  }

  static void popTo(String routeName, PageType pageType, [Map result]) {
    DNavigatorManager.nodeHandle(
        routeName, pageType, DStackConstant.popTo, result);
  }

  static void popToRoot() {
    DNavigatorManager.nodeHandle(null, null, DStackConstant.popToRoot);
  }

  static void popToNativeRoot() {
    DNavigatorManager.nodeHandle(null, null, 'popToNativeRoot');
  }

  static void popSkip(String skipName, [Map result]) {
    DNavigatorManager.nodeHandle(
        skipName, null, DStackConstant.popSkip, result);
  }

  static void dismiss([Map result]) {
    DNavigatorManager.nodeHandle(null, null, DStackConstant.dismiss, result);
  }

  static void nodeHandle(
    String target,
    PageType pageType,
    String actionType, [
    Map result,
    bool homePage,
  ]) {
    Map arguments = {
      'target': target,
      'pageType': '$pageType'.split('.').last,
      'params': (result != null) ? result : {},
      'actionType': actionType,
      'homePage': homePage,
    };
    DStack.instance.channel.sendNodeToNative(arguments);
  }

  static void removeFlutterNode(String target) {
    String actionType = (Platform.isAndroid ? 'pop' : 'didPop');
    Map arguments = {
      'target': target,
      'pageType': 'flutter',
      'actionType': actionType
    };
    DStack.instance.channel.sendRemoveFlutterPageNode(arguments);
  }

  // 记录节点进出，如果已经是首页，则不再pop
  static Future gardPop([Map params]) {
    int minCount = Platform.isIOS ? 2 : 1;
    if (DStackNavigatorObserver.instance.routerCount < minCount) {
      return Future.value('已经是首页，不再出栈');
    }
    _navigator.pop(params);
    return Future.value(true);
  }

  /// 2.处理Native发过来的指令
  /// argument里包含必选参数routeName，actionTpye，可选参数params
  static Future handleActionToFlutter(Map arguments) {
    // 处理实际跳转
    debugPrint("【sendActionToFlutter】 \n"
        "【arguments】$arguments \n"
        "【navigator】$_navigator ");
    final String action = arguments['action'];
    final List nodes = arguments['nodes'];
    final Map params = arguments['params'];
    bool homePage = arguments["homePage"];
    final Map pageTypeMap = arguments['pageType'];
    switch (action) {
      case DStackConstant.push:
        continue Present;
      Present:
      case DStackConstant.present:
        {
          if (homePage != null &&
              homePage == true &&
              DStack.instance.hasHomePage == false) {
            String router = nodes.first;
            String pageTypeStr = pageTypeMap[router];
            pageTypeStr = pageTypeStr.toLowerCase();
            PageType pageType = PageType.native;
            if (pageTypeStr == "flutter") {
              pageType = PageType.flutter;
            }
            return replace(router, pageType, homePage: homePage);
          } else {
            bool animated = arguments['animated'];
            if (animated != null && animated == true) {
              MaterialPageRoute route = DNavigatorManager.materialRoute(
                  routeName: nodes.first,
                  params: params,
                  fullscreenDialog: action == DStackConstant.present);
              return _navigator.push(route);
            } else {
              PageRouteBuilder route = DNavigatorManager.slideRoute(
                  routeName: nodes.first, params: params, milliseconds: 0);
              return _navigator.push(route);
            }
          }
        }
        break;
      case DStackConstant.pop:
        {
          return DNavigatorManager.gardPop(params);
        }
        break;
      case DStackConstant.popTo:
        continue PopSkip;
      case 'popToNativeRoot':
        continue PopSkip;
      case DStackConstant.popToRoot:
        continue PopSkip;
      PopSkip:
      case DStackConstant.popSkip:
        {
          Future pop;
          for (int i = nodes.length - 1; i >= 0; i--) {
            pop = DNavigatorManager.gardPop();
          }
          return pop;
        }
        break;
      case DStackConstant.dismiss:
        {
          return DNavigatorManager.gardPop(params);
        }
        break;
      case DStackConstant.gesture:
        {
          // native发消息过来时，需要处理返回至上一页
          DStackNavigatorObserver.instance
              .setGesturingRouteName('NATIVEGESTURE');
          return DNavigatorManager.gardPop(params);
        }
        break;
    }
    return null;
  }

  /// 从下往上弹出动画
  static PageRouteBuilder slideRoute(
      {String routeName, Map params, int milliseconds}) {
    return animationRoute(
        routeName: routeName,
        params: params,
        animatedBuilder: (BuildContext context, Animation<double> animation,
            Animation<double> secondaryAnimation, WidgetBuilder widgetBuilder) {
          Offset startOffset = const Offset(1.0, 0.0);
          Offset endOffset = const Offset(0.0, 0.0);
          var curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuint,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: startOffset,
              end: endOffset,
            ).animate(curvedAnimation),
            child: widgetBuilder(context),
          );
        },
        transitionDuration: Duration(milliseconds: milliseconds));
  }

  /// 用户自定义flutter页面转场动画
  static PageRouteBuilder animationRoute({
    @required AnimatedPageBuilder animatedBuilder,
    @required String routeName,
    Map params,
    Duration transitionDuration = const Duration(milliseconds: 300),
    bool opaque = true,
    bool barrierDismissible = false,
    Color barrierColor,
    String barrierLabel,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    RouteSettings settings = RouteSettings(name: routeName, arguments: params);
    PageRouteBuilder pageRoute = PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: transitionDuration,
      opaque: opaque,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
      pageBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        DStackWidgetBuilder stackWidgetBuilder =
            DStack.instance.pageBuilder(routeName);

        return animatedBuilder(
            context, animation, secondaryAnimation, stackWidgetBuilder(params));
      },
    );
    return pageRoute;
  }

  // 创建materialRoute
  static MaterialPageRoute materialRoute(
      {String routeName,
      Map params,
      bool maintainState = true,
      bool fullscreenDialog = false}) {
    RouteSettings userSettings =
        RouteSettings(name: routeName, arguments: params);

    DStackWidgetBuilder stackWidgetBuilder =
        DStack.instance.pageBuilder(routeName);
    WidgetBuilder widgetBuilder = stackWidgetBuilder(params);

    MaterialPageRoute materialRoute = MaterialPageRoute(
        settings: userSettings,
        builder: widgetBuilder,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog);
    return materialRoute;
  }
}
