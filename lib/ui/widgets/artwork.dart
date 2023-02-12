import 'dart:io';

import 'package:drop_shadow/drop_shadow.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';

/// Always displays compressed image, if not [compressed] then it will add the full res image on top of it.
class ArtworkWidget extends StatelessWidget {
  ArtworkWidget({
    super.key,
    required this.track,
    this.compressed = true,
    this.fadeMilliSeconds = 250,
    required this.thumnailSize,
    this.forceSquared = false,
    this.child,
    this.scale = 1.0,
    this.borderRadius = 8.0,
    this.blur = 1.5,
    this.width,
    this.height,
    this.cacheHeight,
  });

  final Track track;
  final bool compressed;
  final int fadeMilliSeconds;
  final double thumnailSize;
  final bool forceSquared;
  final Widget? child;
  final double scale;
  final double borderRadius;
  final double blur;
  final double? width;
  final double? height;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final finalPath = compressed ? track.pathToImageComp : track.pathToImage;
    final extImageChild = FileSystemEntity.typeSync(finalPath) != FileSystemEntityType.notFound
        ? Stack(
            children: [
              Image.file(
                File(track.pathToImageComp),
                gaplessPlayback: true,
                fit: BoxFit.cover,
                cacheHeight: cacheHeight ?? 240,
                filterQuality: FilterQuality.high,
                width: forceSquared ? MediaQuery.of(context).size.width : null,
                height: forceSquared ? MediaQuery.of(context).size.width : null,
                frameBuilder: ((context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedSwitcher(
                    duration: Duration(milliseconds: fadeMilliSeconds),
                    child: frame != null ? child : const SizedBox(),
                  );
                }),
              ),
              if (!compressed)
                ExtendedImage.file(
                  File(track.pathToImage),
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                  clearMemoryCacheWhenDispose: true,
                  cacheWidth: 1080,
                  filterQuality: FilterQuality.high,
                  width: forceSquared ? MediaQuery.of(context).size.width : null,
                  height: forceSquared ? MediaQuery.of(context).size.width : null,
                ),
            ],
          )
        : Container(
            width: width ?? thumnailSize,
            height: height ?? thumnailSize,
            key: const ValueKey("empty"),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.background,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: const Icon(Broken.musicnote),
          );

    return SettingsController.inst.enableGlowEffect.value
        ? SizedBox(
            width: width ?? thumnailSize * scale,
            height: height ?? thumnailSize * scale,
            child: Center(
              child: SettingsController.inst.borderRadiusMultiplier.value == 0.0
                  ? DropShadow(
                      borderRadius: borderRadius.multipliedRadius,
                      blurRadius: blur,
                      spread: 0.8,
                      offset: const Offset(0, 1),
                      child: child ?? extImageChild,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
                      child: DropShadow(
                        borderRadius: borderRadius.multipliedRadius,
                        blurRadius: blur,
                        spread: 0.8,
                        offset: const Offset(0, 1),
                        child: child ?? extImageChild,
                      ),
                    ),
            ),
          )
        : SizedBox(
            width: thumnailSize * scale,
            height: thumnailSize * scale,
            child: Center(
              child: SettingsController.inst.borderRadiusMultiplier.value == 0.0
                  ? child ?? extImageChild
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
                      child: child ?? extImageChild,
                    ),
            ),
          );
    // return Stack(
    //   alignment: Alignment.center,
    //   children: [
    //     // Container(
    //     //   width: thumnailSize / 2.5,
    //     //   height: thumnailSize / 2.5,
    //     //   decoration: BoxDecoration(
    //     //     boxShadow: [
    //     //       BoxShadow(
    //     //         color: context.theme.shadowColor.withAlpha(100),
    //     //         blurRadius: 22.0,
    //     //         offset: const Offset(0, 2),
    //     //         spreadRadius: 13,
    //     //       )
    //     //     ],
    //     //   ),
    //     // ),
    //     AnimatedSwitcher(
    //       duration: Duration(milliseconds: fadeMilliSeconds),
    //       child: FileSystemEntity.typeSync(finalPath) != FileSystemEntityType.notFound
    //           ? DropShadow(
    //               blurRadius: SettingsController.inst.enableGlowEffect.value ? 1.2 : 0,
    //               spread: 1.6,
    //               offset: const Offset(0, 1.5),
    //               child: SizedBox(
    //                 width: forceSquared ? thumnailSize : null,
    //                 height: forceSquared ? thumnailSize : null,
    //                 child: ClipRRect(
    //                   clipBehavior: Clip.antiAlias,
    //                   borderRadius: BorderRadius.circular(borderRadiusValue.multipliedRadius),
    //                   child: Stack(
    //                     alignment: Alignment.center,
    //                     fit: forceSquared ? StackFit.passthrough : StackFit.loose,
    //                     children: [
    //                       ExtendedImage.file(
    //                         // clearMemoryCacheWhenDispose: true,
    //                         cacheWidth: 240,
    //                         File(track.pathToImageComp),
    //                         gaplessPlayback: true,
    //                         fit: BoxFit.cover,
    //                       ),
    //                       if (!compressed)
    //                         ExtendedImage.file(
    //                           // clearMemoryCacheWhenDispose: true,
    //                           cacheWidth: 240,
    //                           filterQuality: FilterQuality.high,
    //                           File(track.pathToImage),
    //                           gaplessPlayback: true,
    //                           fit: BoxFit.cover,
    //                         ),
    //                     ],
    //                   ),
    //                 ),
    //               ),
    //             )
    //           : Container(
    //               width: thumnailSize,
    //               height: thumnailSize,
    //               key: const ValueKey("empty"),
    //               decoration: BoxDecoration(
    //                 color: Colors.grey,
    //                 borderRadius: BorderRadius.circular(borderRadiusValue),
    //               ),
    //               child: const Icon(Broken.musicnote),
    //             ),
    //     ),
    //   ],
    // );
  }
}

// class ArtworkWidget extends StatelessWidget {
//   ArtworkWidget(
//       {super.key,
//       required this.id,
//       this.type = ArtworkType.AUDIO,
//       this.format = ArtworkFormat.PNG,
//       this.size = 720,
//       this.quality = 100,
//       this.fadeMilliSeconds = 150,
//       this.borderRadiusValue = 8.0,
//       required this.thumnailSize,
//       this.forceSquared = false,
//       this.heroTag = '',
//       this.artwork});

//   final int id;
//   final Uint8List? artwork;
//   final ArtworkType type;
//   final ArtworkFormat? format;
//   final int size;
//   final int quality;
//   final int fadeMilliSeconds;
//   final double borderRadiusValue;
//   final double thumnailSize;
//   final bool forceSquared;
//   final Object heroTag;

//   @override
//   Widget build(BuildContext context) {
//     return AnimatedSwitcher(
//       duration: Duration(milliseconds: fadeMilliSeconds),
//       child: artwork != null && artwork!.isNotEmpty
//           ? DropShadow(
//               blurRadius: SettingsController.inst.enableGlowEffect.value ? 1 : 0,
//               offset: const Offset(0, 1.5),
//               child: SizedBox(
//                 width: forceSquared ? thumnailSize : null,
//                 height: forceSquared ? thumnailSize : null,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(borderRadiusValue.multipliedRadius),
//                   child: Image.memory(
//                     artwork!,
//                     gaplessPlayback: true,
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//               ),
//             )
//           : Container(
//               width: thumnailSize,
//               height: thumnailSize,
//               key: const ValueKey("empty"),
//               decoration: BoxDecoration(
//                 color: Colors.grey,
//                 borderRadius: BorderRadius.circular(borderRadiusValue),
//               ),
//               child: const Icon(Broken.musicnote),
//             ),
//     );
//   }
// }

// class ArtworkWidget extends StatelessWidget {
//   ArtworkWidget(
//       {super.key, required this.id, this.type = ArtworkType.AUDIO, this.format = ArtworkFormat.PNG, this.size = 720, this.quality = 100, this.fadeMilliSeconds = 150, this.borderRadiusValue = 8.0, required this.thumnailSize, this.forceSquared = false, this.heroTag = ''});

//   final int id;
//   final ArtworkType type;
//   final ArtworkFormat? format;
//   final int size;
//   final int quality;
//   final int fadeMilliSeconds;
//   final double borderRadiusValue;
//   final double thumnailSize;
//   final bool forceSquared;
//   final Object heroTag;

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<Uint8List?>(
//       future: OnAudioQuery().queryArtwork(
//         id,
//         type,
//         format: format ?? ArtworkFormat.PNG,
//         size: size,
//         quality: quality,
//       ),
//       builder: (context, item) {
//         return AnimatedSwitcher(
//           duration: Duration(milliseconds: fadeMilliSeconds),
//           child: item.data != null && item.data!.isNotEmpty
//               ? DropShadow(
//                   blurRadius: SettingsController.inst.enableGlowEffect.value ? 1 : 0,
//                   offset: const Offset(0, 1.5),
//                   child: SizedBox(
//                     width: forceSquared ? thumnailSize : null,
//                     height: forceSquared ? thumnailSize : null,
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(borderRadiusValue.multipliedRadius),
//                       child: Image.memory(
//                         item.data!,
//                         gaplessPlayback: true,
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//                   ),
//                 )
//               : Container(
//                   width: thumnailSize,
//                   height: thumnailSize,
//                   key: const ValueKey("empty"),
//                   decoration: BoxDecoration(
//                     color: Colors.grey,
//                     borderRadius: BorderRadius.circular(borderRadiusValue),
//                   ),
//                   child: const Icon(Broken.musicnote),
//                 ),
//         );
//       },
//     );
//   }
// }

// class ArtworkWidget extends StatelessWidget {
//   ArtworkWidget({
//     super.key,
//     required this.id,
//     this.type = ArtworkType.AUDIO,
//     this.format = ArtworkFormat.PNG,
//     this.size = 720,
//     this.quality = 100,
//     this.fadeMilliSeconds = 150,
//     this.borderRadiusValue = 8.0,
//     required this.thumnailSize,
//     this.forceSquared = false,
//   });

//   final int id;
//   final ArtworkType type;
//   final ArtworkFormat? format;
//   final int size;
//   final int quality;
//   final int fadeMilliSeconds;
//   final double borderRadiusValue;
//   final double thumnailSize;
//   final bool forceSquared;

//   @override
//   Widget build(BuildContext context) {
//     final albumArtworkController = Get.put(ArtworkController(id, type, format: format, size: size, quality: quality), tag: "$id");

//     return Obx(
//       () => AnimatedSwitcher(
//         duration: Duration(milliseconds: fadeMilliSeconds),
//         child: albumArtworkController.artwork.isNotEmpty || albumArtworkController.artwork.first != null
//             ? DropShadow(
//                 blurRadius: SettingsController.inst.enableGlowEffect.value ? 1 : 0,
//                 offset: Offset(0, 1),
//                 child: Container(
//                   width: forceSquared ? thumnailSize : null,
//                   height: forceSquared ? thumnailSize : null,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(borderRadiusValue.multipliedRadius),
//                     child: Image.memory(
//                       key: Key("$id"),
//                       gaplessPlayback: true,
//                       albumArtworkController.artwork.first ?? Uint8List.fromList([0]),
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, exception, stackTrace) {
//                         return const SizedBox();
//                       },
//                     ),
//                   ),
//                 ),
//               )
//             : Container(
//                 width: thumnailSize,
//                 height: thumnailSize,
//                 key: Key("empty"),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withAlpha(20),
//                   borderRadius: BorderRadius.circular(borderRadiusValue),
//                 ),
//                 child: Icon(Broken.musicnote),
//               ),
//       ),
//     );
//   }
// }

/// latest
// class ArtworkWidget extends StatelessWidget {
//   ArtworkWidget({
//     super.key,
//     required this.id,
//     this.type = ArtworkType.AUDIO,
//     this.format = ArtworkFormat.PNG,
//     this.size = 720,
//     this.quality = 100,
//     this.fadeMilliSeconds = 250,
//     this.borderRadiusValue = 8.0,
//     required this.thumnailSize,
//     this.forceSquared = false,
//     this.fullRes = false,
//   });

//   final int id;
//   final ArtworkType type;
//   final ArtworkFormat? format;
//   final int size;
//   final int quality;
//   final int fadeMilliSeconds;
//   final double borderRadiusValue;
//   final double thumnailSize;
//   final bool forceSquared;
//   final bool fullRes;

//   @override
//   Widget build(BuildContext context) {
//     Library lib = Get.put(Library());
//     // // Uint8List imageData;
//     lib.fetchArtwork(id, type, fullRes: fullRes);
//     // Uint8List? imageData = Library.inst.artwork[id];
//     // if (Library.inst.artwork.containsKey(id)) {
//     //   // Uint8List? imageData = Library.inst.artwork[id]!;
//     // } else {
//     //   Library.inst.fetchArtwork(id, type);
//     // }
//     // if(fullRes){
//     //   Library.inst.fetchArtwork(id, type);
//     // }
//     return Obx(
//       () {
//         return AnimatedSwitcher(
//             duration: Duration(milliseconds: fadeMilliSeconds),
//             child: DropShadow(
//               blurRadius: SettingsController.inst.enableGlowEffect.value ? 1 : 0,
//               offset: Offset(0, 1),
//               child: Container(
//                 width: forceSquared ? thumnailSize : null,
//                 height: forceSquared ? thumnailSize : null,
//                 child: ClipRRect(
//                   borderRadius: BorderRadius.circular(borderRadiusValue.multipliedRadius),
//                   child: lib.artworkFullRes[id] != null || lib.artwork[id] != null
//                       ? Image.memory(
//                           key: Key("$id"),
//                           gaplessPlayback: true,
//                           (fullRes ? lib.artworkFullRes[id]! : lib.artwork[id]!),
//                           fit: BoxFit.cover,
//                           errorBuilder: (context, exception, stackTrace) {
//                             return const SizedBox();
//                           },
//                         )
//                       : Container(
//                           width: thumnailSize,
//                           height: thumnailSize,
//                           key: ValueKey("empty"),
//                           decoration: BoxDecoration(
//                             color: Colors.grey,
//                             borderRadius: BorderRadius.circular(borderRadiusValue),
//                           ),
//                           child: Icon(Broken.musicnote),
//                         ),
//                 ),
//               ),
//             ));
//       },
//     );
//   }
// }

// class ArtworkWidget extends StatelessWidget {
//   ArtworkWidget({
//     super.key,
//     required this.id,
//     this.type = ArtworkType.AUDIO,
//     this.format = ArtworkFormat.PNG,
//     this.size = 720,
//     this.quality = 100,
//     this.fadeMilliSeconds = 150,
//     this.borderRadiusValue = 8.0,
//     required this.thumnailSize,
//     this.forceSquared = false,
//   });

//   final int id;
//   final ArtworkType type;
//   final ArtworkFormat? format;
//   final int size;
//   final int quality;
//   final int fadeMilliSeconds;
//   final double borderRadiusValue;
//   final double thumnailSize;
//   final bool forceSquared;

//   @override
//   Widget build(BuildContext context) {
//     //  return CacheMemoryImageProvider(id, )
//     return FutureBuilder<Uint8List?>(
//       future: OnAudioQuery().queryArtwork(
//         id,
//         type,
//         format: format ?? ArtworkFormat.PNG,
//         size: size,
//         quality: quality,
//       ),
//       builder: (context, item) {
//         if (item.data != null && item.data!.isNotEmpty) {
//           return ClipRRect(
//               borderRadius: BorderRadius.circular(10),
//               clipBehavior: Clip.antiAlias,
//               child: ExtendedImage.memory(
//                 item.data!,
//                 cacheRawData: true, gaplessPlayback: true,
//                 imageCacheName: id.toString(),
//                 enableMemoryCache: true,
//                 clearMemoryCacheWhenDispose: false,
//                 clearMemoryCacheIfFailed: false,
//                 // cacheHeight: 100,
//                 // cacheWidth: 100,
//               )

//               // Container(
//               //   decoration: BoxDecoration(image: DecorationImage(image: CacheMemoryImageProvider(id.toString(), item.data!))),
//               // )
//               );
//         }
//         return const Icon(
//           Icons.image_not_supported,
//           size: 50,
//         );
//       },
//     );
//   }
// }

// class ArtworkWidget extends StatefulWidget {
//   ArtworkWidget({
//     super.key,
//     required this.id,
//     this.type = ArtworkType.AUDIO,
//     this.format = ArtworkFormat.PNG,
//     this.size = 720,
//     this.quality = 100,
//     this.fadeMilliSeconds = 300,
//     this.borderRadiusValue = 8.0,
//     required this.thumnailSize,
//     this.forceSquared = false,
//   });

//   final int id;
//   final ArtworkType type;
//   final ArtworkFormat? format;
//   final int size;
//   final int quality;
//   final int fadeMilliSeconds;
//   final double borderRadiusValue;
//   final double thumnailSize;
//   final bool forceSquared;

//   @override
//   _ArtworkWidgetState createState() => _ArtworkWidgetState();
// }

// class _ArtworkWidgetState extends State<ArtworkWidget> {
//   Uint8List? _imageData;

//   @override
//   void initState() {
//     super.initState();
//     _loadImage();
//   }

//   Future<void> _loadImage() async {
//     final response = await OnAudioQuery().queryArtwork(
//       widget.id,
//       widget.type,
//       format: widget.format,
//       size: 720,
//       quality: widget.quality,
//     );

//     if (response != null) {
//       setState(() {
//         _imageData = response;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(widget.borderRadiusValue),
//       child: AnimatedSwitcher(
//         duration: Duration(milliseconds: widget.fadeMilliSeconds),
//         child: _imageData != null && _imageData!.isNotEmpty
//             ? DropShadow(
//                 blurRadius: SettingsController.inst.enableGlowEffect.value ? 1 : 0,
//                 offset: Offset(0, 1.5),
//                 child: Container(
//                   width: widget.forceSquared ? widget.thumnailSize : null,
//                   height: widget.forceSquared ? widget.thumnailSize : null,
//                   child: ClipRRect(
//                       borderRadius: BorderRadius.circular(widget.borderRadiusValue.multipliedRadius),
//                       child: ExtendedImage.memory(
//                         _imageData!,
//                         cacheRawData: true,
//                         imageCacheName: widget.id.toString(),
//                         enableMemoryCache: true,
//                         clearMemoryCacheWhenDispose: false,
//                         clearMemoryCacheIfFailed: false, gaplessPlayback: true,
//                         // cacheHeight: 100,
//                         cacheWidth: 720,
//                       )

//                       // Image.memory(
//                       //   key: Key("${widget.id}"),
//                       //   gaplessPlayback: true,
//                       //   _imageData!,
//                       //   fit: BoxFit.cover,
//                       //   errorBuilder: (context, exception, stackTrace) {
//                       //     return const SizedBox();
//                       //   },
//                       // ),
//                       ),
//                 ),
//               )
//             : Container(
//                 width: widget.thumnailSize,
//                 height: widget.thumnailSize,
//                 key: ValueKey("empty"),
//                 decoration: BoxDecoration(
//                   color: Colors.grey,
//                   borderRadius: BorderRadius.circular(widget.borderRadiusValue),
//                 ),
//                 child: Icon(Broken.musicnote),
//               ),
//       ),
//     );
//   }
// }
