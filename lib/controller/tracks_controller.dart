// import 'dart:typed_data';

// import 'package:get/get.dart';
// import 'package:on_audio_query/on_audio_query.dart';

// class TracksController extends GetxController {
//   final OnAudioQuery _query = OnAudioQuery();
//   final tracksList = <SongModel>[].obs;
//   RxList<Uint8List> tracksArtworkList = <Uint8List>[].obs;
//   TracksController() {
//     fetchTracks();
//     // fetchAlbumArtworks();
//   }

//   void fetchTracks() async {
//     List<SongModel> tracks = await _query.querySongs();
//     tracksList.assignAll(tracks);
//   }

//   // fetchAlbumArtworks() async {
//   //   Future.delayed(Duration(seconds: 1), () async {
//   //     List<int> songsIds = [];
//   //     songsIds = List.generate(tracksList.length, (index) => tracksList[index].id);
//   //     print("IDDDDDDD ${songsIds.length}");
//   //     print("IDDDDDDD ${songsIds}");
//   //     for (int i = 0; i < tracksList.length; i++) {
//   //       Uint8List artwork = await OnAudioQuery().queryArtwork(
//   //             songsIds[i],
//   //             ArtworkType.AUDIO,
//   //             format: ArtworkFormat.PNG,
//   //             size: 100,
//   //             quality: 100,
//   //           ) ??
//   //           Uint8List.fromList([0]);
//   //       tracksArtworkList.add(artwork);
//   //       print("LENGTHH:${tracksArtworkList.length}");
//   //     }
//   //   });
//   // }

//   @override
//   void onClose() {
//     Get.delete();
//     super.onClose();
//   }
// }
// //   Future<Uint8List> loadImage() async {
// //   final byteData = await rootBundle.load('assets/image.png');
// //   return byteData.buffer.asUint8List();
// // }
