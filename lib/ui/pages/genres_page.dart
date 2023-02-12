import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/ui/widgets/library/genre_card.dart';

class GenresPage extends StatelessWidget {
  GenresPage({super.key});
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => CupertinoScrollbar(
        controller: _scrollController,
        child: AnimationLimiter(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, mainAxisSpacing: 4.0),
            controller: _scrollController,
            itemCount: Indexer.inst.genreSearchList.length,
            itemBuilder: (BuildContext context, int i) {
              final genre = Indexer.inst.genreSearchList.entries.toList()[i];
              return AnimationConfiguration.staggeredGrid(
                columnCount: Indexer.inst.genreSearchList.length,
                position: i,
                duration: const Duration(milliseconds: 400),
                child: SlideAnimation(
                  verticalOffset: 25.0,
                  child: FadeInAnimation(
                    duration: const Duration(milliseconds: 400),
                    child: GenreCard(
                      tracks: genre.value.toList(),
                      name: genre.key,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
