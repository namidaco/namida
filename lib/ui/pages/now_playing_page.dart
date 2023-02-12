import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/ui/widgets/waveform.dart';

// class NowPlayingPage extends StatelessWidget {
//   final Track track;
//   NowPlayingPage({super.key, required this.track});

//   @override
//   Widget build(BuildContext context) {
//     // context.theme;

//     return Obx(
//       () => SafeArea(
//         child: Container(
//           padding: EdgeInsets.all(22),
//           // color: Colors.black,
//           child: WaveformComponent(
//             waveDataList: WaveformController.inst.waveform.toList(),
//             duration: 2000,
//             color: context.theme.colorScheme.onBackground.withAlpha(150),
//             curve: Curves.easeInOutQuart,
//             boxMaxWidth: Get.size.width / 2,
//             boxMaxHeight: 55,
//           ),
//         ),
//       ),
//     );
//   }
// }
















// class NowPlayingPage extends StatelessWidget {
//   final SongModel track;
//   const NowPlayingPage({super.key, required this.track});

//   Future<List<int>> generateWaveform() async {
//     var generator = WaveGenerator(44100, BitDepth.depth8Bit);

//     var note = Note(220, track.duration!, Waveform.triangle, 1.0);

//     var file = File.fromUri(Uri(path: track.data));

//     List<int> bytes = [];
//     await for (int byte in generator.generate(note)) {
//       bytes.add(byte);
//     }

//     file.writeAsBytes(bytes, mode: FileMode.append);
//     return bytes;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder(
//       future: generateWaveform(),
//       builder: (context, data) => data.data != null && data.data!.isNotEmpty
//           ? WaveformComponent(
//               waveDataList: data.data!,
//               duration: 2000,
//               color: Theme.of(context).colorScheme.onBackground.withAlpha(150),
//               curve: Curves.easeInOutQuart,
//               boxMaxWidth: MediaQuery.of(context).size.width,
//               boxMaxHeight: 55,
//             )
//           : Container(
//               width: 50,
//               height: 10,
//               color: Colors.brown.withAlpha(100),
//             ),
//     );
//   }
// }
// class NowPlayingPage extends StatelessWidget {
//   final SongModel track;
//   const NowPlayingPage({super.key, required this.track});

//   Future<List<double>?> generateWaveform() async {
//     PlayerController controller = PlayerController();
//     try {
//       final waveformData = await controller
//           .extractWaveformData(
//         path: track.data,
//         noOfSamples: 100,
//       )
//           .then((value) {
//         print(value.length);
//         print(value);
//       });
//       return waveformData;
//     } catch (e) {
//       print(e);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder(
//         future: generateWaveform(),
//         builder: (context, data) => WaveformComponent(
//               waveDataList: data.data!,
//               duration: 2000,
//               color: Theme.of(context).colorScheme.onBackground.withAlpha(150),
//               curve: Curves.easeInOutQuart,
//               boxMaxWidth: MediaQuery.of(context).size.width,
//               boxMaxHeight: 55,
//             )

//         // data.data != null && data.data!.isNotEmpty
//         //     ? WaveformComponent(
//         //         waveDataList: data.data!,
//         //         duration: 2000,
//         //         color: Theme.of(context).colorScheme.onBackground.withAlpha(150),
//         //         curve: Curves.easeInOutQuart,
//         //         boxMaxWidth: MediaQuery.of(context).size.width,
//         //         boxMaxHeight: 55,
//         //       )
//         //     : Container(
//         //         width: 50,
//         //         height: 10,
//         //         color: Colors.brown.withAlpha(100),
//         //       ),
//         );
//   }
// }




// class NowPlayingPage extends StatelessWidget {
//   final SongModel track;
//   const NowPlayingPage({super.key, required this.track});

//   @override
//   Widget build(BuildContext context) {
//     getTemporaryDirectory().then((tempDir) {
//       final progressStream = JustWaveform.extract(
//         audioInFile: File.fromUri(Uri(path: track.data)),
//         waveOutFile: File.fromUri(Uri(path: "${tempDir.path}/${track.title}${track.artist}${track.album}.wave".replaceAll(' ', ''))),
//         zoom: const WaveformZoom.pixelsPerSecond(5),
//       );
//       progressStream.listen((waveformProgress) {
//         print('Progress: %${(100 * waveformProgress.progress).toInt()}');
//         if (waveformProgress.waveform != null) {
//           print(waveformProgress.waveform!.length);
//           print(waveformProgress.waveform!.data);
//         }
//       });

//       return StreamBuilder(stream: progressStream, builder: (context, data) => SizedBox());
//     });

//     return SizedBox();

//     // WaveformComponent(
//     //       waveDataList: data.data!.waveform!.data,
//     //       duration: 2000,
//     //       color: Theme.of(context).colorScheme.onBackground.withAlpha(150),
//     //       curve: Curves.easeInOutQuart,
//     //       boxMaxWidth: MediaQuery.of(context).size.width,
//     //       boxMaxHeight: 55,
//     //     )

//     //  data.data != null && data.data!.progress == 1.0
//     //     ? WaveformComponent(
//     //         waveDataList: data.data!.waveform!.data,
//     //         duration: 2000,
//     //         color: Theme.of(context).colorScheme.onBackground.withAlpha(150),
//     //         curve: Curves.easeInOutQuart,
//     //         boxMaxWidth: MediaQuery.of(context).size.width,
//     //         boxMaxHeight: 55,
//     //       )
//     //     : Container(
//     //         width: 50,
//     //         height: 10,
//     //         color: Colors.brown.withAlpha(100),
//     //       ),
//     // );
//   }
// }
