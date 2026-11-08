# Shop selection boundaries

Derived boundary archive, distributed under the Open Data Commons Open Database License 1.0 (ODbL): https://opendatacommons.org/licenses/odbl/1-0/ . Attribution: geoBoundaries / William & Mary geoLab; original India ADM3 source: Pathways Data Pvt. Ltd. and lgdirectory.gov.in. This archive is a derived database and retains ODbL share-alike terms. Region labels/IDs originate from the existing LGD snapshot.

Source metadata and original data: https://www.geoboundaries.org/api/current/gbOpen/IND/ADM3/ . The source represents **2018**, not current 2026 administrative divisions. Shapes were matched by normalized names and parent-state/district geometry, rounded to six decimals and simplified with topology preserved at 0.00008 degree tolerance. Ambiguous/unmatched regions are not assigned guessed polygons. See coverage.json. Map outlines are approximate; they are not legal/survey boundaries. App instructions display the source year.

`india_subdistricts.json.gz` contains the derived geometry and source IDs for 4,789 matched sub-districts. The mobile application never bundles this archive: it fetches one selected polygon from the secured RPC. Unmatched areas explicitly report that a boundary is unavailable; admins must supply verified current geometry before those areas can create/move a shop pin. Existing business pins remain stored during unrelated edits.

Apply admin/sql/24_business_category_boundary.sql before importing. A trusted database operator may load the archive using tools/import_shop_boundaries.py. Do not put database service keys into Flutter. Boundary data has RLS enabled, with no direct app writes. Future boundary updates should preserve source/licensing metadata and be reviewed against newer LGD regions before import.
