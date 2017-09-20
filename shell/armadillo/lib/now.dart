// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';
import 'package:lib.widgets/widgets.dart';

import 'context_model.dart';
import 'elevations.dart';
import 'important_info.dart';
import 'minimized_now_bar.dart';
import 'now_minimization_model.dart';
import 'opacity_model.dart';
import 'power_model.dart';
import 'quick_settings.dart';
import 'quick_settings_progress_model.dart';
import 'size_model.dart';
import 'story_drag_transition_model.dart';
import 'user_context_text.dart';

/// Fraction of the minimization animation which should be used for falling away
/// and sliding in of the user context and battery icon.
const double _kFallAwayDurationFraction = 0.35;

/// The distance above the lowest point we can scroll down to when
/// recents scroll offset is 0.0.
const double _kRestingDistanceAboveLowestPoint = 80.0;

/// When the recent list's scrollOffset exceeds this value we minimize [Now].
const double _kNowMinimizationScrollOffsetThreshold = 120.0;

/// When the recent list's scrollOffset exceeds this value we hide quick
/// settings [Now].
const double _kNowQuickSettingsHideScrollOffsetThreshold = 16.0;

const double _kQuickSettingsHorizontalPadding = 16.0;

const double _kQuickSettingsInnerHorizontalPadding = 16.0;

const double _kMaxQuickSettingsBackgroundWidth = 700.0;

/// The overscroll amount which must occur before now begins to grow in height.
const double _kOverscrollDelayOffset = 0.0;

/// The speed multiple at which now increases in height when overscrolling.
const double _kScrollFactor = 0.8;

/// Shows the user, the user's context, and important settings.  When minimized
/// also shows an affordance for seeing missed interruptions.
class Now extends StatefulWidget {
  /// How much to shift the quick settings vertically when shown.
  final double quickSettingsHeightBump;

  /// Called when [Now]'s center button is tapped while minimized.
  final VoidCallback onMinimizedTap;

  /// Called when [Now]'s center button is long pressed while minimized.
  final VoidCallback onMinimizedLongPress;

  /// Called when [Now]'s quick settings are maximized.
  final VoidCallback onQuickSettingsMaximized;

  /// Called when the user releases their finger while overscrolled past a
  /// certain threshold and/or overscrolling with a certain velocity.
  final VoidCallback onOverscrollThresholdRelease;

  /// Called when a vertical drag occurs on [Now] when in its fully minimized
  /// bar state.
  final GestureDragUpdateCallback onBarVerticalDragUpdate;

  /// Called when a vertical drag ends on [Now] when in its fully minimized bar
  /// state.
  final GestureDragEndCallback onBarVerticalDragEnd;

  /// Called when the user selects log out.
  final VoidCallback onLogoutSelected;

  /// Called when the user selects log out and clear the ledger.
  final VoidCallback onClearLedgerSelected;

  /// Called when the user taps the user context.
  final VoidCallback onUserContextTapped;

  /// Called when minimized context is tapped.
  final VoidCallback onMinimizedContextTapped;

  /// Constructor.
  Now({
    Key key,
    this.quickSettingsHeightBump,
    this.onMinimizedTap,
    this.onMinimizedLongPress,
    this.onQuickSettingsMaximized,
    this.onBarVerticalDragUpdate,
    this.onBarVerticalDragEnd,
    this.onOverscrollThresholdRelease,
    this.onLogoutSelected,
    this.onClearLedgerSelected,
    this.onUserContextTapped,
    this.onMinimizedContextTapped,
  })
      : super(key: key);

  @override
  NowState createState() => new NowState();
}

/// Controls the animations for maximizing and minimizing, showing and hiding
/// quick settings, and vertically shifting as the story list is scrolled.
class NowState extends State<Now> {
  final GlobalKey _importantInfoMaximizedKey = new GlobalKey();
  final GlobalKey _userContextTextKey = new GlobalKey();
  final GlobalKey _userImageKey = new GlobalKey();
  final ValueNotifier<double> _recentsScrollOffset =
      new ValueNotifier<double>(0.0);

  /// scroll offset affects the bottom padding of the user and text elements
  /// as well as the overall height of [Now] while maximized.
  double _lastRecentsScrollOffset = 0.0;

  // initialized in showQuickSettings
  final double _quickSettingsMaximizedHeight = 200.0;
  double _importantInfoMaximizedHeight = 0.0;
  double _userContextTextHeight = 0.0;
  double _userImageHeight = 0.0;

  /// Sets the [scrollOffset] of the story list tracked by [Now].
  void onRecentsScrollOffsetChanged(double scrollOffset, bool ignore) {
    _recentsScrollOffset.value =
        scrollOffset - SizeModel.of(context).storyListTopPadding;
    if (ignore) {
      return;
    }
    if (scrollOffset > _kNowMinimizationScrollOffsetThreshold &&
        _lastRecentsScrollOffset < scrollOffset) {
      NowMinimizationModel.of(context).minimize();
      QuickSettingsProgressModel.of(context).hide();
    } else if (scrollOffset < _kNowMinimizationScrollOffsetThreshold &&
        _lastRecentsScrollOffset > scrollOffset) {
      NowMinimizationModel.of(context).maximize();
    }
    // When we're past the quick settings threshold and are
    // scrolling further, hide quick settings.
    if (scrollOffset > _kNowQuickSettingsHideScrollOffsetThreshold &&
        _lastRecentsScrollOffset < scrollOffset) {
      QuickSettingsProgressModel.of(context).hide();
    }
    _lastRecentsScrollOffset = scrollOffset;
  }

  @override
  Widget build(BuildContext context) =>
      new ScopedModelDescendant<StoryDragTransitionModel>(
        builder: (
          BuildContext context,
          Widget child,
          StoryDragTransitionModel storyDragTransitionModel,
        ) =>
            new Offstage(
              offstage: storyDragTransitionModel.value == 1.0,
              child: new Opacity(
                opacity: lerpDouble(
                  1.0,
                  0.0,
                  storyDragTransitionModel.value,
                ),
                child: child,
              ),
            ),
        child: new ScopedModelDescendant<QuickSettingsProgressModel>(
          builder: (
            BuildContext context,
            Widget child,
            QuickSettingsProgressModel quickSettingsProgressModel,
          ) =>
              new ScopedModelDescendant<NowMinimizationModel>(
                builder: (
                  BuildContext context,
                  Widget child,
                  NowMinimizationModel nowMinimizationModel,
                ) =>
                    _buildNow(context),
              ),
        ),
      );

  Widget _buildNow(BuildContext context) => new Align(
        alignment: FractionalOffset.bottomCenter,
        child: new ScopedModelDescendant<SizeModel>(
          builder: (
            BuildContext context,
            Widget child,
            SizeModel sizeModel,
          ) =>
              new AnimatedBuilder(
                animation: _recentsScrollOffset,
                builder: (BuildContext context, Widget child) => new Container(
                      height: _getNowHeight(
                        sizeModel,
                        _recentsScrollOffset.value,
                      ),
                      child: child,
                    ),
                child: new Stack(
                  fit: StackFit.passthrough,
                  children: <Widget>[
                    // Quick Settings Background.
                    new Positioned(
                      left: _kQuickSettingsHorizontalPadding,
                      right: _kQuickSettingsHorizontalPadding,
                      top: _getQuickSettingsBackgroundTopOffset(
                        sizeModel,
                      ),
                      child: new Center(
                        child: new Container(
                          height: _getQuickSettingsBackgroundHeight(
                            sizeModel,
                          ),
                          width: _getQuickSettingsBackgroundWidth(
                            sizeModel,
                          ),
                          decoration: new BoxDecoration(
                            color: Colors.white,
                            borderRadius: new BorderRadius.circular(
                              _quickSettingsBackgroundBorderRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // User Image, User Context Text, and Important Information when maximized.
                    new Positioned(
                      left: _kQuickSettingsHorizontalPadding,
                      right: _kQuickSettingsHorizontalPadding,
                      top: _getUserImageTopOffset(sizeModel),
                      child: new Center(
                        child: new Column(
                          children: <Widget>[
                            new Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // User Context Text when maximized.
                                new Expanded(
                                  child: new GestureDetector(
                                    onTap: widget.onUserContextTapped,
                                    behavior: HitTestBehavior.opaque,
                                    child: new Container(
                                      key: _userContextTextKey,
                                      height: _userImageSize,
                                      child: _buildUserContextMaximized(
                                        opacity: _fallAwayOpacity,
                                      ),
                                    ),
                                  ),
                                ),
                                // User Profile image
                                _buildUserImage(),
                                // Important Information when maximized.
                                new Expanded(
                                  child: new Container(
                                    key: _importantInfoMaximizedKey,
                                    height: _userImageSize,
                                    child: _buildImportantInfoMaximized(
                                      opacity: _fallAwayOpacity,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Quick Settings
                            new Container(
                              padding: const EdgeInsets.only(top: 32.0),
                              child: _buildQuickSettings(sizeModel),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // User Context Text and Important Information when minimized.
                    new MinimizedNowBar(
                      fallAwayDurationFraction: _kFallAwayDurationFraction,
                    ),

                    // Minimized button bar gesture detector. Only enabled when
                    // we're nearly fully minimized.
                    _buildMinimizedButtonBarGestureDetector(
                      sizeModel,
                    ),
                  ],
                ),
              ),
        ),
      );

  Widget _buildUserImage() => new GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_revealingQuickSettings) {
            _showQuickSettings();
          } else {
            QuickSettingsProgressModel.of(context).hide();
          }
        },
        child: new PhysicalModel(
          color: Colors.transparent,
          shape: BoxShape.circle,
          elevation:
              _quickSettingsProgress * Elevations.nowUserQuickSettingsOpen,
          child: new Container(
            key: _userImageKey,
            width: _userImageSize,
            height: _userImageSize,
            foregroundDecoration: new BoxDecoration(
              border: new Border.all(
                color: new Color(0xFFFFFFFF),
                width: _userImageBorderWidth,
              ),
              shape: BoxShape.circle,
            ),
            child: _buildUser(),
          ),
        ),
      );

  Widget _buildQuickSettings(SizeModel sizeModel) => new Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: _kQuickSettingsInnerHorizontalPadding, vertical: 8.0),
        child: new Container(
          width: _getQuickSettingsBackgroundWidth(
            sizeModel,
          ),
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new Divider(
                height: 4.0,
                color: Colors.grey[300].withOpacity(
                  _quickSettingsSlideUpProgress,
                ),
              ),
              new Container(
                child: new QuickSettings(
                  opacity: _quickSettingsSlideUpProgress,
                  onLogoutSelected: widget.onLogoutSelected,
                  onClearLedgerSelected: widget.onClearLedgerSelected,
                ),
              ),
            ],
          ),
        ),
      );

  /// Returns an avatar of the current user.
  Widget _buildUser() => new ScopedModelDescendant<ContextModel>(
        builder: (
          BuildContext context,
          Widget child,
          ContextModel contextModel,
        ) {
          String avatarUrl = _getImageUrl(contextModel.userImageUrl) ?? '';
          String name = contextModel.userName ?? '';
          return avatarUrl.isNotEmpty
              ? new Alphatar.fromNameAndUrl(
                  avatarUrl: avatarUrl,
                  name: name,
                )
              : new Alphatar.fromName(
                  name: name,
                );
        },
      );

  /// Returns a verbose representation of the user's current context.
  Widget _buildUserContextMaximized({double opacity: 1.0}) => new Opacity(
        opacity: opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
        child: new ScopedModelDescendant<QuickSettingsProgressModel>(
          builder: (
            _,
            __,
            QuickSettingsProgressModel quickSettingsProgressModel,
          ) =>
              new Transform(
                transform: new Matrix4.translationValues(
                  lerpDouble(
                    -16.0,
                    0.0,
                    opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
                  ),
                  lerpDouble(0.0, 32.0, _quickSettingsProgress),
                  0.0,
                ),
                child: new UserContextText(
                  textColor: Color.lerp(
                    Colors.white,
                    Colors.grey[600],
                    _quickSettingsProgress,
                  ),
                ),
              ),
        ),
      );

  /// Returns a verbose representation of the important information to the user
  /// with the given [opacity].
  Widget _buildImportantInfoMaximized({double opacity: 1.0}) => new Opacity(
        opacity: opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
        child: new ScopedModelDescendant<QuickSettingsProgressModel>(
          builder: (
            _,
            __,
            QuickSettingsProgressModel quickSettingsProgressModel,
          ) =>
              new Transform(
                transform: new Matrix4.translationValues(
                  lerpDouble(
                    16.0,
                    0.0,
                    opacity < 0.8 ? 0.0 : ((opacity - 0.8) / 0.2),
                  ),
                  lerpDouble(
                    0.0,
                    32.0,
                    quickSettingsProgressModel.value,
                  ),
                  0.0,
                ),
                child: new ImportantInfo(
                  textColor: Color.lerp(
                    Colors.white,
                    Colors.grey[600],
                    quickSettingsProgressModel.value,
                  ),
                ),
              ),
        ),
      );

  String _getImageUrl(String userImageUrl) {
    if (userImageUrl == null) {
      return null;
    }
    Uri uri = Uri.parse(userImageUrl);
    if (uri.queryParameters['sz'] != null) {
      Map<String, dynamic> queryParameters = new Map<String, dynamic>.from(
        uri.queryParameters,
      );
      queryParameters['sz'] = '112';
      uri = uri.replace(queryParameters: queryParameters);
    }
    return uri.toString();
  }

  Widget _buildMinimizedButtonBarGestureDetector(SizeModel sizeModel) =>
      new Offstage(
        offstage: _buttonTapDisabled,
        child: new GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: widget.onBarVerticalDragUpdate,
          onVerticalDragEnd: widget.onBarVerticalDragEnd,
          child: new Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              new Expanded(
                child: new GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onMinimizedContextTapped?.call();
                  },
                ),
              ),
              new GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onMinimizedTap,
                onLongPress: widget.onMinimizedLongPress,
                child: new Container(width: sizeModel.minimizedNowHeight * 4.0),
              ),
              new Expanded(
                child: new GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onMinimizedContextTapped?.call();
                  },
                ),
              ),
            ],
          ),
        ),
      );

  /// Morphs [Now] into its quick settings mode.
  /// This should only be called when [Now] is maximized.
  void _showQuickSettings() {
    double heightFromKey(GlobalKey key) {
      RenderBox box = key.currentContext.findRenderObject();
      return box.size.height;
    }

    _importantInfoMaximizedHeight = heightFromKey(_importantInfoMaximizedKey);
    _userContextTextHeight = heightFromKey(_userContextTextKey);
    _userImageHeight = heightFromKey(_userImageKey);

    if (!_revealingQuickSettings) {
      QuickSettingsProgressModel.of(context).target = 1.0;
      widget.onQuickSettingsMaximized?.call();
    }
  }

  double get _quickSettingsProgress =>
      QuickSettingsProgressModel.of(context).value;

  double get _minimizationProgress => NowMinimizationModel.of(context).value;

  bool get _revealingQuickSettings =>
      QuickSettingsProgressModel.of(context).target == 1.0;

  bool get _buttonTapDisabled => _minimizationProgress < 1.0;

  double _getNowHeight(SizeModel sizeModel, double scrollOffset) => math.max(
      sizeModel.minimizedNowHeight,
      sizeModel.minimizedNowHeight +
          ((sizeModel.maximizedNowHeight - sizeModel.minimizedNowHeight) *
              (1.0 - _minimizationProgress)) +
          _quickSettingsRaiseDistance +
          _getScrollOffsetHeightDelta(scrollOffset));

  double get _userImageSize => lerpDouble(56.0, 12.0, _minimizationProgress);

  double get _userImageBorderWidth =>
      lerpDouble(2.0, 6.0, _minimizationProgress);

  double _getUserImageTopOffset(SizeModel sizeModel) =>
      lerpDouble(100.0, 20.0, _quickSettingsProgress) *
          (1.0 - _minimizationProgress) +
      ((sizeModel.minimizedNowHeight - _userImageSize) / 2.0) *
          _minimizationProgress;

  double _getQuickSettingsBackgroundTopOffset(SizeModel sizeModel) =>
      _getUserImageTopOffset(sizeModel) +
      ((_userImageSize / 2.0) * _quickSettingsProgress);

  double get _quickSettingsBackgroundBorderRadius =>
      lerpDouble(50.0, 4.0, _quickSettingsProgress);

  double _getQuickSettingsBackgroundMaximizedWidth(SizeModel sizeModel) =>
      math.min(_kMaxQuickSettingsBackgroundWidth, sizeModel.screenSize.width) -
      2 * _kQuickSettingsHorizontalPadding;

  double _getQuickSettingsBackgroundWidth(SizeModel sizeModel) => lerpDouble(
      _userImageSize,
      _getQuickSettingsBackgroundMaximizedWidth(sizeModel),
      _quickSettingsProgress * (1.0 - _minimizationProgress));

  double _getQuickSettingsBackgroundHeight(SizeModel sizeModel) {
    return lerpDouble(
        _userImageSize,
        -_getUserImageTopOffset(sizeModel) +
            _userImageHeight +
            _userContextTextHeight +
            _importantInfoMaximizedHeight +
            _quickSettingsHeight,
        _quickSettingsProgress * (1.0 - _minimizationProgress));
  }

  double get _quickSettingsHeight =>
      _quickSettingsProgress * _quickSettingsMaximizedHeight;

  double get _fallAwayOpacity => (1.0 - _fallAwayProgress).clamp(0.0, 1.0);

  double get _quickSettingsRaiseDistance =>
      widget.quickSettingsHeightBump * _quickSettingsProgress;

  double _getScrollOffsetHeightDelta(double scrollOffset) =>
      (math.max(
                  -_kRestingDistanceAboveLowestPoint,
                  (scrollOffset > -_kOverscrollDelayOffset &&
                          scrollOffset < 0.0)
                      ? 0.0
                      : (-1.0 *
                              (scrollOffset < 0.0
                                  ? scrollOffset + _kOverscrollDelayOffset
                                  : scrollOffset) *
                              _kScrollFactor) *
                          (1.0 - _minimizationProgress) *
                          (1.0 - _quickSettingsProgress)) *
              1000.0)
          .truncateToDouble() /
      1000.0;

  /// We fall away the context text and important information for the initial
  /// portion of the minimization animation as determined by
  /// [_kFallAwayDurationFraction].
  double get _fallAwayProgress =>
      math.min(1.0, (_minimizationProgress / _kFallAwayDurationFraction));

  /// We slide up and fade in the quick settings for the final portion of the
  /// quick settings animation as determined by [_kFallAwayDurationFraction].
  double get _quickSettingsSlideUpProgress => math.max(
        0.0,
        ((_quickSettingsProgress - (1.0 - _kFallAwayDurationFraction)) /
            _kFallAwayDurationFraction),
      );
}
