# Third-Party Notices

This project separates third-party anatomy/exercise assets from app-authored rehabilitation content. Preserve the source, license, author, and derivative metadata stored with each imported asset.

## Z-Anatomy

**Project:** Z-Anatomy — The libre 3D atlas of anatomy  
**Source:** `Z-Anatomy/Models-of-human-anatomy`  
**License:** CC BY-SA 4.0

The app imports Terminologia Anatomica (TA2) mapping data from Z-Anatomy's `TA2.csv` and uses web-ready 3D derivatives generated from the Z-Anatomy Blender atlas.

Required attribution for the Z-Anatomy layer should include:

> Z-Anatomy — The libre 3D atlas of anatomy — CC BY-SA 4.0

Any redistributed derivative of the Z-Anatomy model/data layer must retain the applicable attribution and ShareAlike terms. App-authored rehabilitation text and business logic are kept in separate database tables/fields and are not copied from Z-Anatomy.

## BodyParts3D / DBCLS

Z-Anatomy's human model incorporates geometry derived from BodyParts3D.

**Project:** BodyParts3D  
**Author:** The Database Center for Life Science (DBCLS)  
**License:** CC BY-SA 2.1 Japan

Attribution used in this project:

> BodyParts3D — The Database Center for Life Science (DBCLS) — CC BY-SA 2.1 Japan

## Web-ready GLB conversion

The mobile/web-ready system-level GLB files imported into Supabase Storage are derived from the open-source repository:

**Repository:** `DrMuratAltun/anatomi-simulatoru`  
**Pinned source commit:** `37e85dfbbb398e11ba33c8f0e411f06f9bba592f`

Its `systems/*.glb` files were exported from Z-Anatomy `Startup.blend` using its `tools/export_systems.py` pipeline. The exporter preserves individual object names while reducing geometry for browser/mobile use. The derivative repository distributes those GLBs under CC BY-SA 4.0 and requires attribution to the upstream anatomy sources.

The app copies the seven system layers into its own Supabase Storage bucket and stores the source URL, pinned source version, attribution, derivative notice, and license alongside each asset in `z_anatomy_assets`.

Current imported layers:

- muscular
- skeletal
- joints
- cardiovascular
- nervous
- lymphatic
- visceral / internal organs

## wger

wger supplies general exercise, muscle, equipment, translation, image, and video reference data. License and author metadata from wger entries are preserved in the corresponding database records. The application-specific rehabilitation fields are maintained independently and are not overwritten by upstream synchronization.

## Important provenance rule

Third-party projects can contain components or referenced material with licenses that differ from the main project license. Before publishing or redistributing a specific third-party asset outside the app's current imported set, review that asset's upstream notice and the metadata stored in `z_anatomy_assets` / wger media records. This notice is a technical provenance record, not legal advice.
