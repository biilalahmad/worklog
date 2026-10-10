import 'package:flutter/material.dart';

import 'diet_tab.dart';
import 'progress_tab.dart';
import 'routines_tab.dart';
import 'workout_tab.dart';

/// Keeps the full-height working areas separate from the compact Gym Home.
class GymSectionsScreen extends StatefulWidget {
  const GymSectionsScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<GymSectionsScreen> createState() => _GymSectionsScreenState();
}

class _GymSectionsScreenState extends State<GymSectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 4, vsync: this, initialIndex: widget.initialIndex.clamp(0, 3));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Gym'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: const [
              Tab(icon: Icon(Icons.fitness_center_rounded), text: 'Workout'),
              Tab(icon: Icon(Icons.view_list_rounded), text: 'Routines'),
              Tab(icon: Icon(Icons.insights_rounded), text: 'Progress'),
              Tab(icon: Icon(Icons.restaurant_rounded), text: 'Diet'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: const [
            WorkoutTab(),
            RoutinesTab(),
            ProgressTab(),
            DietTab()
          ],
        ),
      );
}
