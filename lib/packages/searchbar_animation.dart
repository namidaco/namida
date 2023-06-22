import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchBarAnimation extends StatefulWidget {
  /// This gives the width to the searchbar by default it will take the size of whole screen.
  final double? searchBoxWidth;

  /// This give the shadow to the search box button by default it is 0.
  final double buttonElevation;

  /// Need to pass the textEditingController for the textFormField of the searchbar.
  final TextEditingController textEditingController;

  /// Provide trailing icon in search box which is at the end of search box by default it is search icon.
  final Widget trailingWidget;

  /// Provide the button icon that is when the search box is closed by default it is search icon.
  final Widget buttonWidget;

  /// Provide the button icon that is when the search box is open by default it is close icon.
  final Widget secondaryButtonWidget;

  /// This allows to set the hintText color of textFormField of the search box.
  final Color? hintTextColour;

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
    required this.secondaryButtonWidget,
    required this.buttonWidget,
    this.searchBoxWidth,
    this.hintText = "Search Here",
    this.searchBoxColour = AppColours.white,
    this.buttonColour = AppColours.white,
    this.cursorColour = AppColours.black,
    this.hintTextColour = AppColours.grey,
    this.searchBoxBorderColour = AppColours.black12,
    this.buttonShadowColour = AppColours.black45,
    this.buttonBorderColour = AppColours.black26,
    this.durationInMilliSeconds = Dimensions.t1000,
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
    this.buttonElevation = Dimensions.d0,
    this.inputFormatters,
    this.onTap,
    this.onTapOutside,
    Key? key,
    this.cursorHeight,
    this.cursorRadius,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _SearchBarAnimationState createState() => _SearchBarAnimationState();
}

class _SearchBarAnimationState extends State<SearchBarAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  FocusNode focusNode = FocusNode();
  bool _isAnimationOn = false;
  bool switcher = false;

  final DecorationTween decorationTween = DecorationTween(
    begin: BoxDecoration(
      color: AppColours.transparent,
      borderRadius: BorderRadius.circular(Dimensions.d60),
    ),
    end: BoxDecoration(
      color: AppColours.transparent,
      borderRadius: BorderRadius.circular(Dimensions.d60),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          blurRadius: Dimensions.d5,
          spreadRadius: Dimensions.d0,
          color: AppColours.black45,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildAnimatedSearchbarBody();
  }

  /// main body of the searchbar animation
  Widget _buildAnimatedSearchbarBody() {
    return Container(
      height: Dimensions.d60,
      alignment: widget.isSearchBoxOnRightSide ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: _isAnimationOn ? widget.searchBoxColour : AppColours.transparent,
          border: Border.all(
              color: !widget.enableBoxBorder
                  ? AppColours.transparent
                  : _isAnimationOn
                      ? widget.searchBoxBorderColour!
                      : AppColours.transparent),
          borderRadius: BorderRadius.circular(Dimensions.d30),
          boxShadow: (!_isAnimationOn)
              ? null
              : ((widget.enableBoxShadow)
                  ? [
                      const BoxShadow(
                        color: AppColours.black26,
                        spreadRadius: -Dimensions.d10,
                        blurRadius: Dimensions.d10,
                        offset: Offset(Dimensions.d0, Dimensions.d7),
                      ),
                    ]
                  : null),
        ),
        child: AnimatedContainer(
          duration: Duration(milliseconds: widget.durationInMilliSeconds),
          height: Dimensions.d48,
          width: (!switcher) ? Dimensions.d48 : (widget.searchBoxWidth ?? MediaQuery.of(context).size.width),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Dimensions.d30),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Duration(milliseconds: widget.durationInMilliSeconds),
                top: Dimensions.d6,
                left: widget.isSearchBoxOnRightSide ? Dimensions.d7 : null,
                right: !widget.isSearchBoxOnRightSide ? Dimensions.d7 : null,
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: (!switcher) ? Dimensions.d0 : Dimensions.d1,
                  duration: const Duration(milliseconds: Dimensions.t700),
                  child: Container(
                    padding: const EdgeInsets.all(Dimensions.d8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Dimensions.d30),
                    ),
                    child: widget.trailingWidget,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: Duration(milliseconds: widget.durationInMilliSeconds),
                left: (!switcher)
                    ? Dimensions.d20
                    : (!widget.textAlignToRight)
                        ? Dimensions.d45
                        : Dimensions.d80,
                curve: Curves.easeOut,
                top: Dimensions.d11,
                child: AnimatedOpacity(
                  opacity: (!switcher) ? Dimensions.d0 : Dimensions.d1,
                  duration: const Duration(milliseconds: Dimensions.t200),
                  child: Container(
                    padding: const EdgeInsets.only(left: Dimensions.d10),
                    alignment: Alignment.topCenter,
                    width: (widget.searchBoxWidth ?? MediaQuery.of(context).size.width) / Dimensions.d1_7,
                    child: _textFormField(),
                  ),
                ),
              ),
              Align(
                alignment: widget.isSearchBoxOnRightSide ? Alignment.centerRight : Alignment.centerLeft,
                child: (widget.isOriginalAnimation)
                    ? Padding(
                        padding: const EdgeInsets.all(Dimensions.d5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: _isAnimationOn ? null : Border.all(color: widget.buttonBorderColour!),
                          ),
                          child: DecoratedBoxTransition(
                            decoration: decorationTween.animate(_animationController),
                            child: GestureDetector(
                              child: CircleAvatar(
                                backgroundColor: widget.buttonColour,
                                child: switcher ? widget.secondaryButtonWidget : widget.buttonWidget,
                              ),
                              onTap: () {
                                _onTapFunctionOriginalAnim();
                              },
                            ),
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(Dimensions.d5),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: widget.enableButtonBorder ? Border.all(color: widget.buttonBorderColour!) : null,
                            boxShadow: widget.enableButtonShadow
                                ? [
                                    BoxShadow(
                                      blurRadius: Dimensions.d5,
                                      color: widget.buttonShadowColour!,
                                      spreadRadius: widget.buttonElevation,
                                    )
                                  ]
                                : null,
                          ),
                          child: GestureDetector(
                            child: CircleAvatar(
                              backgroundColor: widget.buttonColour,
                              child: switcher ? widget.secondaryButtonWidget : widget.buttonWidget,
                            ),
                            onTap: () {
                              _onTapFunction();
                            },
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

  /// This is the tap function for the animation style not for the original animation style.
  void _onTapFunction() {
    _isAnimationOn = true;
    widget.onPressButton?.call(!switcher);
    setState(
      () {
        if (!switcher) {
          switcher = true;
          setState(() {
            if (widget.enableKeyboardFocus) {
              FocusScope.of(context).requestFocus(focusNode);
            }
          });
          _animationController.forward().then((value) {
            setState(() {
              _isAnimationOn = true;
            });
            widget.onExpansionComplete?.call();
          });
        } else {
          switcher = false;
          setState(() {
            if (widget.enableKeyboardFocus) {
              unFocusKeyboard();
            }
          });
          _animationController.reverse().then((value) {
            setState(() {
              _isAnimationOn = false;
            });
            widget.onCollapseComplete?.call();
          });
        }
      },
    );
  }

  /// This is the tap function for the original animation style.
  void _onTapFunctionOriginalAnim() {
    _isAnimationOn = true;
    widget.onPressButton?.call(!switcher);
    setState(
      () {
        if (!switcher) {
          switcher = true;
          setState(() {
            if (widget.enableKeyboardFocus) {
              FocusScope.of(context).requestFocus(focusNode);
            }
          });
          _animationController.forward().then((value) {
            widget.onExpansionComplete?.call();
          });
        } else {
          switcher = false;
          setState(() {
            if (widget.enableKeyboardFocus) {
              unFocusKeyboard();
            }
          });
          _animationController.reverse().then((value) {
            setState(() {
              _isAnimationOn = false;
            });
            widget.onCollapseComplete?.call();
          });
        }
      },
    );
    unFocusKeyboard();
  }

  /// This function is for the textFormField of searchbar.
  TextFormField _textFormField() {
    return TextFormField(
      controller: widget.textEditingController,
      inputFormatters: widget.inputFormatters,
      focusNode: focusNode,
      cursorWidth: Dimensions.d2,
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
      style: widget.enteredTextStyle ?? const TextStyle(color: AppColours.black),
      cursorColor: widget.cursorColour,
      textAlign: widget.textAlignToRight ? TextAlign.right : TextAlign.left,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.only(bottom: Dimensions.d8),
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintText: widget.hintText,
        hintStyle: TextStyle(
          color: widget.hintTextColour,
          fontSize: Dimensions.d16,
          fontWeight: FontWeight.w400,
          height: kIsWeb ? Dimensions.d1_5 : Dimensions.d1_2,
        ),
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimensions.d20),
          borderSide: BorderSide.none,
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
class AppColours {
  static const Color transparent = Colors.transparent;
  static const Color white = Colors.white;
  static const Color grey = Colors.grey;
  static const Color black12 = Colors.black12;
  static const Color black26 = Colors.black26;
  static const Color black45 = Colors.black45;
  static const Color black = Colors.black;
}

/// Dimension for searchbar widget
class Dimensions {
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
  static const double d16 = 16.0;
  static const double d17 = 17.0;
  static const double d20 = 20.0;
  static const double d30 = 30.0;
  static const double d45 = 45.0;
  static const double d48 = 48.0;
  static const double d60 = 60.0;
  static const double d80 = 80.0;

  /// Time values
  static const int t200 = 200;
  static const int t700 = 700;
  static const int t1000 = 1000;
}
