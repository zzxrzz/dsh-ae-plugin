# AE ExtendScript API Cheatsheet

Core objects used most in automation. All examples assume the wrapper environment (aeLog available).

## Project & Items

```javascript
app.project                                    // active project
app.project.file                               // File or null if unsaved
app.project.save(new File("D:/work/out.aep"))  // save as
app.project.save()                             // save existing
app.open(new File("D:/work/in.aep"))           // open project
var comp = app.project.items.addComp("Main", 1920, 1080, 1.0, 30.0, 29.97); // name,w,h,pixelAspect,duration,fps
app.project.items.addFolder("Assets");
app.project.item(1).remove();                  // delete item
```

## Import

```javascript
var io = new ImportOptions(File("D:/assets/logo.png"));
var item = app.project.importFile(io);

var vio = new ImportOptions(File("D:/assets/clip.mov"));
vio.importAs = ImportAsType.FOOTAGE;
var clip = app.project.importFile(vio);

var seq = new ImportOptions(File("D:/assets/frame_0001.png"));
seq.sequence = true;
seq.forceAlphabetical = true;
var seqItem = app.project.importFile(seq);
```

## Layers

```javascript
var layer = comp.layers.add(item);              // AVLayer from footage item
var solid = comp.layers.addSolid([1,0,0], "BG", comp.width, comp.height, comp.pixelAspect, comp.duration);
var text  = comp.layers.addText("Hello");
var nullL = comp.layers.addNull(comp.duration);
var light = comp.layers.addLight("Key", [960, 540]);
var cam   = comp.layers.addCamera("Cam", [960, 540]);
var pre   = comp.layers.add(comp);              // precompose via nested comp item
layer.startTime = 0;                            // seconds
layer.inPoint = 0; layer.outPoint = 5;
layer.stretch = 100;                            // time stretch %
layer.enabled = true; layer.solo = false; layer.audioEnabled = true;
layer.moveToBeginning(); layer.moveToEnd();
layer.name = "Hero";
layer.remove();
```

## Properties & Keyframes

Every animatable value is a Property reachable by matchName:

```javascript
var t = layer.property("ADBE Transform Group");          // Transform
var pos = t.property("ADBE Position");                   // Position
var scl = t.property("ADBE Scale");                      // Scale
var opa = t.property("ADBE Opacity");                    // Opacity
opa.setValueAtTime(0, 0);
opa.setValueAtTime(1, 100);                              // seconds
pos.setValueAtKey(pos.addKey(0.5), [960, 270]);
pos.setInterpolationTypeAtKey(1, KeyframeInterpolationType.BEZIER, KeyframeInterpolationType.BEZIER);
// Easy ease on selected keyframes:
pos.selectedKeys = [1, 2];
// valueAtTime(time, preExpression)
opa.expression = "wiggle(2, 30);";
opa.removeAllKeyframes();
```

Common matchNames: ADBE Position, ADBE Scale, ADBE Rotate Z, ADBE Opacity, ADBE Anchor Point, ADBE Mask Parade.

## Text

```javascript
var t = comp.layers.addText("标题");
var doc = t.property("Source Text").value;
doc.font = "SourceHanSansCN-Bold";
doc.fontSize = 72;
doc.fillColor = [1, 1, 1];
doc.applyFill = true;
doc.justification = ParagraphJustification.CENTER_JUSTIFY;
t.property("Source Text").setValue(doc);
```

## Effects

```javascript
var fx = layer.Effects.addProperty("ADBE Gaussian Blur 2");   // display name must match installed version
fx.property("ADBE Gaussian Blur 2-0001").setValue(25);        // Blurriness
fx.property("Blurriness").setValue(25);                       // often works by display name too
fx.remove();
```
Discover matchNames on an existing setup: iterate `layer.property(4)` (Effect) props and log `.matchName`/`.name`.

## Render Queue

```javascript
var rq = app.project.renderQueue;
var item = rq.items.add(comp);
item.timeSpanStart = 0; item.timeSpanDuration = 10;      // seconds (work area override)
var om = item.outputModule(1);
om.applyTemplate("HDTV 1080 29.97 H.264");               // must exist in this AE install
om.file = new File("D:/out/final.mp4");
var settings = om.getSettings(GetSettingsFormat.STRING); // inspect available templates first
rq.render();                                             // synchronous; blocks until done
```

- List templates on your machine: `om.templates` (array of names).
- AME handoff: `rq.queueInAME(true);` renders through Adobe Media Encoder if installed.
- CLI alternative: `aerender.exe -project in.aep -comp "Main" -output out.mov` for whole-comp renders without scripting.

## App / System

```javascript
app.beginUndoGroup("Build scene"); ... app.endUndoGroup();
app.version                  // e.g. "24.6.2"
app.isoLanguage              // e.g. "en_US" / "zh_CN" — effect names are localized!
$.fileName, $.line           // debug context (inside catch: e.line)
File("D:/work").exists
new Folder("D:/out").create()
```

## Gotchas

- **Localization**: `Effects.addProperty("Gaussian Blur")` fails on Chinese installs — use matchNames (language-independent) where possible.
- **Colors**: always `[r, g, b]` floats 0–1, not 0–255.
- **Time**: seconds, always floating point.
- **Dialogues**: `alert/confirm/prompt` block automation forever — never call them.
- **Missing fonts** break text renders silently (fallback font). Check `app.fonts` availability if text matters.
