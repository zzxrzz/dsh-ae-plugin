# AE Automation Recipes

Copy a recipe into a `.jsx` task script and adapt. All assume the run_ae_script.ps1 wrapper (`aeLog()` available, auto exit unless -KeepOpen).

## 1. Title card: fade-up text on solid, render mp4

```javascript
var comp = app.project.items.addComp("Title", 1920, 1080, 1.0, 5, 30);
var bg = comp.layers.addSolid([0.05,0.06,0.12], "BG", 1920, 1080, 1.0, 5);
var t = comp.layers.addText("HELLO WORLD");
var d = t.property("Source Text").value;
d.fontSize = 120; d.fillColor = [1,1,1]; d.justification = ParagraphJustification.CENTER_JUSTIFY;
t.property("Source Text").setValue(d);
t.property("Position").setValue([960, 540]);
var opa = t.property("Opacity");
opa.setValueAtTime(0, 0); opa.setValueAtTime(1, 100);
var rq = app.project.renderQueue.items.add(comp);
rq.outputModule(1).applyTemplate("HDTV 1080 29.97 H.264");
rq.outputModule(1).file = new File("D:/work/title.mp4");
app.project.renderQueue.render();
aeLog("rendered D:/work/title.mp4");
```

## 2. Assemble clips sequentially with crossfades

```javascript
var comp = app.project.items.addComp("Edit", 1920, 1080, 1.0, 0, 30); // duration set later
var files = ["D:/clips/a.mp4", "D:/clips/b.mp4", "D:/clips/c.mp4"];
var cursor = 0, fade = 0.5;
for (var i = 0; i < files.length; i++) {
  var item = app.project.importFile(new ImportOptions(File(files[i])));
  var l = comp.layers.add(item);
  l.startTime = cursor;
  // set comp duration on last clip
  if (i === files.length - 1) comp.duration = cursor + l.source.duration;
  if (i > 0) {
    var opa = l.property("Opacity");
    opa.setValueAtTime(cursor, 0);
    opa.setValueAtTime(cursor + fade, 100);
  }
  cursor += l.source.duration - fade;
}
aeLog("timeline length " + comp.duration);
```

## 3. Bounce-in logo with ease keyframes

```javascript
var item = app.project.importFile(new ImportOptions(File("D:/assets/logo.png")));
var comp = app.project.items.addComp("Logo", 1920, 1080, 1.0, 4, 30);
var l = comp.layers.add(item);
var s = l.property("Scale");
s.setValueAtTime(0, [0,0]);
s.setValueAtTime(0.6, [115,115]);
s.setValueAtTime(0.8, [95,95]);
s.setValueAtTime(1.0, [100,100]);
// smooth temporal ease on all keys
for (var k = 1; k <= s.numKeys; k++) {
  s.setInterpolationTypeAtKey(k, KeyframeInterpolationType.BEZIER, KeyframeInterpolationType.BEZIER);
}
```

## 4. Apply blur + color correction to footage layer

```javascript
var l = comp.layer("Plate");
var blur = l.Effects.addProperty("ADBE Gaussian Blur 2");
blur.property("Blurriness").setValue(12);
var lum = l.Effects.addProperty("ADBE Lumetri");   // Lumetri Color (CC 2015+)
// Lumetri props are indexed; inspect via getSettings on a live layer if unsure
```

## 5. Save project snapshot then render in AME (old AE without H.264 template)

```javascript
app.project.save(new File("D:/work/edit.aep"));
var rq = app.project.renderQueue.items.add(app.project.item(1));
app.project.renderQueue.queueInAME(true);   // needs Adobe Media Encoder installed
aeLog("queued to AME");
```

## 6. Batch: render every comp whose name starts with "EXPORT_"

```javascript
for (var i = 1; i <= app.project.numItems; i++) {
  var it = app.project.item(i);
  if (it instanceof CompItem && it.name.indexOf("EXPORT_") === 0) {
    var rq = app.project.renderQueue.items.add(it);
    rq.outputModule(1).file = new File("D:/out/" + it.name + ".mp4");
  }
}
app.project.renderQueue.render();
```

## 7. Debug helper — dump effect matchNames of a layer

```javascript
var fxParent = comp.layer(1).property("Effects");
for (var i = 1; i <= fxParent.numProperties; i++) {
  aeLog(fxParent.property(i).name + " => " + fxParent.property(i).matchName);
}
```
