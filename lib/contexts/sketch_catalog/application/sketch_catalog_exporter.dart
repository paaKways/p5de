import 'package:p5de/contexts/sketch_catalog/domain/project.dart';
import 'package:p5de/contexts/sketch_catalog/domain/sketch.dart';

class SketchCatalogExportItem {
  const SketchCatalogExportItem.standalone(this.sketch) : project = null;

  const SketchCatalogExportItem.project({
    required this.project,
    required this.sketch,
  }) : assert(project != null);

  final Project? project;
  final Sketch sketch;
}

abstract class SketchCatalogExporter {
  Future<String> exportAll();

  Future<String> exportItems(Iterable<SketchCatalogExportItem> items);
}
