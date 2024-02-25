import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class SearchBarAnimation extends StatefulWidget {
  /// This gives the width to the searchbar by default it will take the size of whole screen.
  final double? searchBoxWidth;

  /// This give the shadow to the search box button by default it is 0.
  final double buttonElevation;

  /// Need to pass the textEditingController for the textFormField of the searchbar.
  final TextEditingController textEditingController;

  final Widget trailingWidget;

  /// Provide trailing icon in search box which is beside [trailingWidget]
  final Widget? buttonWidgetSmall;

  final double buttonWidgetSmallPadding;

  /// Provide the button icon that is when the search box is closed by default it is search icon.
  final Widget buttonWidget;

  /// Provide the button icon that is when the search box is open by default it is close icon.
  final Widget secondaryButtonWidget;

  /// This allows to set the hintText color of textFormField of the search box.
  final TextStyle? Function(double height)? hintTextStyle;

  /// This allows to set the background colour of the whole search box field by default it is set to white.
  final Color? searchBoxColour;

  /// This property allows to set the background colour of the search button.
  final Color? buttonColour;

  /// This allows to set the colour of the cursor of textFormField.
  final Color? cursorColour;

  /// If user required the search box border than they can set it's colour from here.
  final Color? searchBoxBorderColour;

  /// User can set the shadow colour of button form here.
  final Color? buttonShadowColour;

  /// User can set the border colour of button from here
  final Color? buttonBorderColour;

  /// Can Change the hint text from here.
  final String hintText;

  /// Set the duration of animation from here by default it is 1000 milliseconds.
  final int durationInMilliSeconds;

  /// If user required the search box appear on the right side instead of left side they can set it from here.
  final bool isSearchBoxOnRightSide;

  /// This property allows user to enable the keyboard on tap of search box button directly if this is set as true if not set as true than it will not automatically bring keyboard on tap of the search box button instead it will bring keyboard once searchField is tapped.
  final bool enableKeyboardFocus;

  /// Can enable or disable the shadow of the button from here if isOriginalAnimation is set to false.
  final bool enableButtonShadow;

  /// Can set if searchBox shadow is required from here.
  final bool enableBoxShadow;

  /// Can set the direction of the text, That is form right to left in case of languages like arabic.
  final bool textAlignToRight;

  /// If user wants the border around the search box can enable from this parameter.
  final bool enableBoxBorder;

  /// If user wants border around the button they can set it from this parameter.
  final bool enableButtonBorder;

  /// This is the required field it allows to enable or disable the animation of the button currently it's animation is based on the 'DecoratedBoxTransition', If it is disabled than user can give the shadow to the button but if it is set to true than cannot give shadow to the button when search box is closed.
  final bool isOriginalAnimation;

  /// This allows us to change the style of the text which user have entered in the textFormField of search box.
  final TextStyle? enteredTextStyle;

  /// OnSaved function for the textFormField, In order to use this user must wrap this widget into 'Form' widget.
  final Function? onSaved;

  /// OnChanged function for the textFormField.
  final Function? onChanged;

  /// onFieldSubmitted function for the textFormField.
  final Function? onFieldSubmitted;

  /// onFieldSubmitted function for the textFormField.
  final Function? onEditingComplete;

  /// onExpansionComplete functions can be used to perform something just after searchbox is opened.
  final Function? onExpansionComplete;

  /// onCollapseComplete functions can be used to perform something just after searchbox is closed.
  final Function? onCollapseComplete;

  /// onPressButton function can be used to handle open/close searchbar button taps.
  /// it may be used for animation start handling
  final Function(bool isOpen)? onPressButton;

  /// Can set keyBoard Type from here (e.g TextInputType.numeric) by default it is set to text,
  final TextInputType textInputType;

  /// Can set RegExp in the textFormField of search box from here.
  final List<TextInputFormatter>? inputFormatters;

  final void Function()? onTap;
  final void Function(PointerDownEvent event)? onTapOutside;
  final double? cursorHeight;
  final Radius? cursorRadius;

  const SearchBarAnimation({
    required this.textEditingController,
    required this.isOriginalAnimation,
    required this.trailingWidget,
    this.buttonWidgetSmall,
    this.buttonWidgetSmallPadding = 0.0,
    required this.secondaryButtonWidget,
    required this.buttonWidget,
    this.searchBoxWidth,
    this.hintText = "Search Here",
    this.searchBoxColour = _SBColor.white,
    this.buttonColour = _SBColor.white,
    this.cursorColour = _SBColor.black,
    this.hintTextStyle,
    this.searchBoxBorderColour = _SBColor.black12,
    this.buttonShadowColour = _SBColor.black45,
    this.buttonBorderColour = _SBColor.black26,
    this.durationInMilliSeconds = _SBDimensions.t1000,
    this.textInputType = TextInputType.text,
    this.isSearchBoxOnRightSide = false,
    this.enableKeyboardFocus = false,
    this.enableBoxBorder = false,
    this.enableButtonBorder = false,
    this.enableButtonShadow = true,
    this.enableBoxShadow = true,
    this.textAlignToRight = false,
    this.onSaved,
    this.onChanged,
    this.onFieldSubmitted,
    this.onExpansionComplete,
    this.onCollapseComplete,
    this.onPressButton,
    this.onEditingComplete,
    this.enteredTextStyle,
    this.buttonElevation = _SBDimensions.d0,
    this.inputFormatters,
    this.onTap,
    this.onTapOutside,
    Key? key,
    this.cursorHeight,
    this.cursorRadius,
  }) : super(key: key);

  @override
  SearchBarAnimationState createState() => SearchBarAnimationState();
}

class SearchBarAnimationState extends State<SearchBarAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final FocusNode focusNode = FocusNode();
  bool _isAnimationOn = false;
  bool switcher = false;

  final DecorationTween decorationTween = DecorationTween(
    begin: BoxDecoration(
      color: _SBColor.transparent,
      borderRadius: BorderRadius.circular(_SBDimensions.d60),
    ),
    end: BoxDecoration(
      color: _SBColor.transparent,
      borderRadius: BorderRadius.circular(_SBDimensions.d60),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          blurRadius: _SBDimensions.d5,
          spreadRadius: _SBDimensions.d0,
          color: _SBColor.black45,
        )
      ],
    ),
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationInMilliSeconds),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    // widget.textEditingController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smallButtonTotalPadding = _SBDimensions.d5 * 2 + widget.buttonWidgetSmallPadding;
    final smallButtonTotalPaddingPart = smallButtonTotalPadding * 0.6;
    return Container(
      height: _SBDimensions.d60,
      alignment: widget.isSearchBoxOnRightSide ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: _isAnimationOn ? widget.searchBoxColour : _SBColor.transparent,
          border: Border.all(
              color: !widget.enableBoxBorder
                  ? _SBColor.transparent
                  : _isAnimationOn
                      ? widget.searchBoxBorderColour!
                      : _SBColor.transparent),
          borderRadius: BorderRadius.circular(_SBDimensions.d30),
          boxShadow: (!_isAnimationOn)
              ? null
              : ((widget.enableBoxShadow)
                  ? [
                      const BoxShadow(
                        color: _SBColor.black26,
                        spreadRadius: -_SBDimensions.d10,
                        blurRadius: _SBDimensions.d10,
                        offset: Offset(_SBDimensions.d0, _SBDimensions.d7),
                      ),
                    ]
                  : null),
        ),
        child: AnimatedContainer(
          duration: Duration(milliseconds: widget.durationInMilliSeconds),
          height: _SBDimensions.d48,
          width: (!switcher) ? _SBDimensions.d48 : (widget.searchBoxWidth ?? MediaQuery.sizeOf(context).width),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_SBDimensions.d30),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Duration(milliseconds: widget.durationInMilliSeconds),
                top: _SBDimensions.d5,
                left: widget.isSearchBoxOnRightSide ? _SBDimensions.d6 : null,
                right: !widget.isSearchBoxOnRightSide ? _SBDimensions.d6 : null,
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: (!switcher) ? _SBDimensions.d0 : _SBDimensions.d1,
                  duration: const Duration(milliseconds: _SBDimensions.t700),
                  child: Container(
                    padding: const EdgeInsets.all(_SBDimensions.d8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_SBDimensions.d30),
                    ),
                    child: widget.trailingWidget,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: Duration(milliseconds: widget.durationInMilliSeconds),
                left: (!switcher)
                    ? _SBDimensions.d20
                    : (!widget.textAlignToRight)
                        ? _SBDimensions.d35
                        : _SBDimensions.d80,
                curve: Curves.easeOut,
                top: _SBDimensions.d11,
                child: AnimatedOpacity(
                  opacity: (!switcher) ? _SBDimensions.d0 : _SBDimensions.d1,
                  duration: const Duration(milliseconds: _SBDimensions.t200),
                  child: Container(
                    padding: const EdgeInsets.only(left: _SBDimensions.d10),
                    alignment: Alignment.topCenter,
                    width: smallButtonTotalPaddingPart + (widget.searchBoxWidth ?? MediaQuery.sizeOf(context).width) / _SBDimensions.d1_7,
                    child: _textFormField(context, smallButtonTotalPaddingPart),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                bottom: 0,
                right: smallButtonTotalPadding,
                child: Align(
                  alignment: widget.isSearchBoxOnRightSide ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: _SBDimensions.t200),
                    child: AnimatedOpacity(
                      opacity: (!switcher) ? _SBDimensions.d0 : _SBDimensions.d1,
                      duration: const Duration(milliseconds: _SBDimensions.t200),
                      child: widget.buttonWidgetSmall != null ? widget.buttonWidgetSmall! : const SizedBox(),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: widget.isSearchBoxOnRightSide ? Alignment.centerRight : Alignment.centerLeft,
                child: (widget.isOriginalAnimation)
                    ? Padding(
                        padding: const EdgeInsets.all(_SBDimensions.d5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: _isAnimationOn ? null : Border.all(color: widget.buttonBorderColour!),
                          ),
                          child: DecoratedBoxTransition(
                            decoration: decorationTween.animate(_animationController),
                            child: TapDetector(
                              onTap: () {
                                widget.onPressButton?.call(!switcher);
                                _onTapFunctionOriginalAnim();
                              },
                              child: CircleAvatar(
                                backgroundColor: widget.buttonColour,
                                child: switcher ? widget.secondaryButtonWidget : widget.buttonWidget,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(_SBDimensions.d5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: widget.enableButtonBorder ? Border.all(color: widget.buttonBorderColour!) : null,
                            boxShadow: widget.enableButtonShadow
                                ? [
                                    BoxShadow(
                                      blurRadius: _SBDimensions.d5,
                                      color: widget.buttonShadowColour!,
                                      spreadRadius: widget.buttonElevation,
                                    )
                                  ]
                                : null,
                          ),
                          child: TapDetector(
                            onTap: () {
                              widget.onPressButton?.call(!switcher);
                              _onTapFunction();
                            },
                            child: CircleAvatar(
                              backgroundColor: widget.buttonColour,
                              child: switcher ? widget.secondaryButtonWidget : widget.buttonWidget,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openCloseSearchBar({bool forceOpen = false}) {
    if (widget.isOriginalAnimation) {
      _onTapFunctionOriginalAnim(forceOpen: forceOpen);
    } else {
      _onTapFunction(forceOpen: forceOpen);
    }
  }

  /// This is the tap function for the animation style not for the original animation style.
  void _onTapFunction({bool forceOpen = false}) {
    _isAnimationOn = true;
    setState(
      () {
        if (forceOpen || !switcher) {
          switcher = true;
          if (widget.enableKeyboardFocus) {
            FocusScope.of(context).requestFocus(focusNode);
          }

          _animationController.forward().then((value) {
            _isAnimationOn = true;

            widget.onExpansionComplete?.call();
          });
        } else {
          switcher = false;

          if (widget.enableKeyboardFocus) {
            unFocusKeyboard();
          }

          _animationController.reverse().then((value) {
            _isAnimationOn = false;
          });
          widget.onCollapseComplete?.call();
        }
      },
    );
  }

  /// This is the tap function for the original animation style.
  void _onTapFunctionOriginalAnim({bool forceOpen = false}) {
    _isAnimationOn = true;
    setState(
      () {
        if (forceOpen || !switcher) {
          switcher = true;
          if (widget.enableKeyboardFocus) {
            FocusScope.of(context).requestFocus(focusNode);
          }

          _animationController.forward().then((value) {
            widget.onExpansionComplete?.call();
          });
        } else {
          switcher = false;
          if (widget.enableKeyboardFocus) {
            unFocusKeyboard();
          }

          _animationController.reverse().then((value) {
            _isAnimationOn = false;
            widget.onCollapseComplete?.call();
          });
        }
      },
    );
    unFocusKeyboard();
  }

  /// This function is for the textFormField of searchbar.
  Widget _textFormField(BuildContext context, double rightPadding) {
    MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.only(right: rightPadding),
      child: TextFormField(
        controller: widget.textEditingController,
        inputFormatters: widget.inputFormatters,
        focusNode: focusNode,
        cursorWidth: _SBDimensions.d2,
        textInputAction: TextInputAction.search,
        onTap: widget.onTap,
        onTapOutside: widget.onTapOutside,
        cursorHeight: widget.cursorHeight,
        cursorRadius: widget.cursorRadius,
        onFieldSubmitted: (String value) {
          setState(() {
            switcher = true;
          });
          (widget.onFieldSubmitted != null) ? widget.onFieldSubmitted!(value) : debugPrint('onFieldSubmitted Not Used');
        },
        onEditingComplete: () {
          unFocusKeyboard();
          setState(() {
            switcher = false;
          });
          (widget.onEditingComplete != null) ? widget.onEditingComplete?.call() : debugPrint('onEditingComplete Not Used');
        },
        keyboardType: widget.textInputType,
        onChanged: (var value) {
          (widget.onChanged != null) ? widget.onChanged?.call(value) : debugPrint('onChanged Not Used');
        },
        onSaved: (var value) {
          (widget.onSaved != null) ? widget.onSaved?.call(value) : debugPrint('onSaved Not Used');
        },
        style: widget.enteredTextStyle ?? const TextStyle(color: _SBColor.black),
        cursorColor: widget.cursorColour,
        textAlign: widget.textAlignToRight ? TextAlign.right : TextAlign.left,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.only(bottom: _SBDimensions.d8),
          isDense: true,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: widget.hintText,
          hintStyle: widget.hintTextStyle?.call(kIsWeb ? _SBDimensions.d1_5 : _SBDimensions.d1_2) ??
              const TextStyle(
                color: _SBColor.grey,
                fontSize: _SBDimensions.d15,
                fontWeight: FontWeight.w400,
                height: kIsWeb ? _SBDimensions.d1_5 : _SBDimensions.d1_2,
              ),
          alignLabelWithHint: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_SBDimensions.d20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// This is for automatically Focusing or unFocusing the keyboard on the tap of search button.
  void unFocusKeyboard() {
    final FocusScopeNode currentFocusScope = FocusScope.of(context);
    if (!currentFocusScope.hasPrimaryFocus && currentFocusScope.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }
}

/// Colours for searchbar widget
class _SBColor {
  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color grey = Colors.grey;
  static const Color black12 = Colors.black12;
  static const Color black26 = Colors.black26;
  static const Color black45 = Colors.black45;
  static const Color black = Colors.black;
}

/// Dimension for searchbar widget
class _SBDimensions {
  /// Dimension for sizing
  static const double d0 = 0.0;
  static const double d1 = 1.0;
  static const double d1_2 = 1.2;
  static const double d1_5 = 1.5;
  static const double d1_7 = 1.7;
  static const double d2 = 2.0;
  static const double d5 = 5.0;
  static const double d6 = 6.0;
  static const double d7 = 7.0;
  static const double d8 = 8.0;
  static const double d10 = 10.0;
  static const double d11 = 11.0;
  static const double d15 = 15.0;
  static const double d20 = 20.0;
  static const double d30 = 30.0;
  static const double d35 = 35.0;
  static const double d48 = 48.0;
  static const double d60 = 60.0;
  static const double d80 = 80.0;

  /// Time values
  static const int t200 = 200;
  static const int t700 = 700;
  static const int t1000 = 1000;
}
