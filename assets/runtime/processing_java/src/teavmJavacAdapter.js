(function () {
  function assetUrl(relativePath) {
    return new URL(relativePath, document.currentScript.src).toString();
  }

  var assetPaths = {
    compilerRuntime: assetUrl("../vendor/teavm-javac/compiler.wasm-runtime.js"),
    compilerWasm: assetUrl("../vendor/teavm-javac/compiler.wasm"),
    sdk: assetUrl("../vendor/teavm-javac/compile-classlib-teavm.bin"),
    runtimeClasslib: assetUrl("../vendor/teavm-javac/runtime-classlib-teavm.bin")
  };

  var compilerStatePromise;
  var classpathCache = {};

  async function fetchBinary(url) {
    var response = await fetch(url);
    if (!response.ok) {
      throw new Error("Failed to fetch " + url + ": HTTP " + response.status);
    }
    return new Int8Array(await response.arrayBuffer());
  }

  async function getCompilerState() {
    if (!compilerStatePromise) {
      compilerStatePromise = (async function () {
        var runtimeModule = await import(assetPaths.compilerRuntime);
        var teavm = await runtimeModule.load(assetPaths.compilerWasm);
        var compiler = teavm.exports.createCompiler();
        var sdk = await fetchBinary(assetPaths.sdk);
        var runtimeClasslib = await fetchBinary(assetPaths.runtimeClasslib);
        compiler.setSdk(sdk);
        compiler.setTeaVMClasslib(runtimeClasslib);
        return {
          load: runtimeModule.load,
          compiler: compiler
        };
      })();
    }

    return compilerStatePromise;
  }

  async function getClasspathBinary(entry) {
    if (!classpathCache[entry.url]) {
      classpathCache[entry.url] = fetchBinary(entry.url);
    }
    return classpathCache[entry.url];
  }

  function formatDiagnostic(diagnostic) {
    var location = diagnostic.fileName ? diagnostic.fileName + ":" + diagnostic.lineNumber : "<unknown>";
    return "[" + diagnostic.type + "/" + diagnostic.severity + "] " + location + " - " + diagnostic.message;
  }

  function normalizeNameList(names) {
    if (!names) {
      return [];
    }
    if (Array.isArray(names)) {
      return names.slice();
    }
    if (typeof names.length === "number") {
      return Array.prototype.slice.call(names);
    }
    return Object.keys(names).map(function (key) {
      return names[key];
    });
  }

  function summarizeOutputFiles(names, getter) {
    return normalizeNameList(names).map(function (name) {
      var content = getter(name);
      return {
        path: name,
        bytes: content ? content.length : 0
      };
    });
  }

  function toBase64(bytes) {
    var binary = "";
    for (var i = 0; i < bytes.length; ++i) {
      binary += String.fromCharCode(bytes[i] & 0xFF);
    }
    return btoa(binary);
  }

  function crc32(bytes) {
    var crc = -1;
    for (var i = 0; i < bytes.length; ++i) {
      crc ^= bytes[i] & 0xFF;
      for (var j = 0; j < 8; ++j) {
        var mask = -(crc & 1);
        crc = (crc >>> 1) ^ (0xEDB88320 & mask);
      }
    }
    return (crc ^ -1) >>> 0;
  }

  function writeUint16(target, offset, value) {
    target[offset] = value & 0xFF;
    target[offset + 1] = (value >>> 8) & 0xFF;
  }

  function writeUint32(target, offset, value) {
    target[offset] = value & 0xFF;
    target[offset + 1] = (value >>> 8) & 0xFF;
    target[offset + 2] = (value >>> 16) & 0xFF;
    target[offset + 3] = (value >>> 24) & 0xFF;
  }

  function encodeAscii(text) {
    var bytes = new Uint8Array(text.length);
    for (var i = 0; i < text.length; ++i) {
      bytes[i] = text.charCodeAt(i) & 0x7F;
    }
    return bytes;
  }

  function concatUint8Arrays(parts) {
    var total = 0;
    for (var i = 0; i < parts.length; ++i) {
      total += parts[i].length;
    }
    var result = new Uint8Array(total);
    var offset = 0;
    for (var j = 0; j < parts.length; ++j) {
      result.set(parts[j], offset);
      offset += parts[j].length;
    }
    return result;
  }

  function buildOutputJarFromFiles(files) {
    var localParts = [];
    var centralParts = [];
    var localOffset = 0;

    for (var i = 0; i < files.length; ++i) {
      var file = files[i];
      var fileNameBytes = encodeAscii(file.path);
      var fileData = file.content;
      var crc = crc32(fileData);

      var localHeader = new Uint8Array(30 + fileNameBytes.length);
      writeUint32(localHeader, 0, 0x04034b50);
      writeUint16(localHeader, 4, 20);
      writeUint16(localHeader, 6, 0);
      writeUint16(localHeader, 8, 0);
      writeUint16(localHeader, 10, 0);
      writeUint16(localHeader, 12, 0);
      writeUint32(localHeader, 14, crc);
      writeUint32(localHeader, 18, fileData.length);
      writeUint32(localHeader, 22, fileData.length);
      writeUint16(localHeader, 26, fileNameBytes.length);
      writeUint16(localHeader, 28, 0);
      localHeader.set(fileNameBytes, 30);
      localParts.push(localHeader, fileData);

      var centralHeader = new Uint8Array(46 + fileNameBytes.length);
      writeUint32(centralHeader, 0, 0x02014b50);
      writeUint16(centralHeader, 4, 20);
      writeUint16(centralHeader, 6, 20);
      writeUint16(centralHeader, 8, 0);
      writeUint16(centralHeader, 10, 0);
      writeUint16(centralHeader, 12, 0);
      writeUint16(centralHeader, 14, 0);
      writeUint32(centralHeader, 16, crc);
      writeUint32(centralHeader, 20, fileData.length);
      writeUint32(centralHeader, 24, fileData.length);
      writeUint16(centralHeader, 28, fileNameBytes.length);
      writeUint16(centralHeader, 30, 0);
      writeUint16(centralHeader, 32, 0);
      writeUint16(centralHeader, 34, 0);
      writeUint16(centralHeader, 36, 0);
      writeUint32(centralHeader, 38, 0);
      writeUint32(centralHeader, 42, localOffset);
      centralHeader.set(fileNameBytes, 46);
      centralParts.push(centralHeader);

      localOffset += localHeader.length + fileData.length;
    }

    var localData = concatUint8Arrays(localParts);
    var centralData = concatUint8Arrays(centralParts);
    var end = new Uint8Array(22);
    writeUint32(end, 0, 0x06054b50);
    writeUint16(end, 4, 0);
    writeUint16(end, 6, 0);
    writeUint16(end, 8, files.length);
    writeUint16(end, 10, files.length);
    writeUint32(end, 12, centralData.length);
    writeUint32(end, 16, localData.length);
    writeUint16(end, 20, 0);

    return concatUint8Arrays([localData, centralData, end]);
  }

  function selectOutputJar(outputJar, classOutputEntries, request, phaseLog) {
    if (request.target === "java-bytecode" && classOutputEntries.length) {
      recordPhase(phaseLog, "Repacked output jar from normalized class files for CheerpJ");
      return buildOutputJarFromFiles(classOutputEntries);
    }
    if ((!outputJar || !outputJar.length) && classOutputEntries.length) {
      return buildOutputJarFromFiles(classOutputEntries);
    }
    return outputJar;
  }

  function readClassFileMajorVersion(bytes) {
    if (!bytes || bytes.length < 8) {
      return null;
    }
    if ((bytes[0] & 0xFF) !== 0xCA || (bytes[1] & 0xFF) !== 0xFE || (bytes[2] & 0xFF) !== 0xBA || (bytes[3] & 0xFF) !== 0xBE) {
      return null;
    }
    return ((bytes[6] & 0xFF) << 8) | (bytes[7] & 0xFF);
  }

  function rewriteClassFileMajorVersion(bytes, majorVersion) {
    var next = new Int8Array(bytes);
    next[6] = (majorVersion >>> 8) & 0xFF;
    next[7] = majorVersion & 0xFF;
    return next;
  }

  function normalizeClassOutputsForTarget(entries, request, phaseLog) {
    var targetMajor = request && typeof request.classMajorVersion === "number" ? request.classMajorVersion : null;
    if (!targetMajor) {
      return entries;
    }

    var rewritten = 0;
    var highestMajor = 0;
    var normalized = entries.map(function (entry) {
      if (!/.class$/i.test(entry.path || "")) {
        return entry;
      }
      var major = readClassFileMajorVersion(entry.content);
      if (major && major > highestMajor) {
        highestMajor = major;
      }
      if (!major || major <= targetMajor) {
        return entry;
      }
      rewritten += 1;
      return {
        path: entry.path,
        content: rewriteClassFileMajorVersion(entry.content, targetMajor)
      };
    });

    if (rewritten) {
      recordPhase(phaseLog, "Rewrote " + rewritten + " class file(s) from major version " + highestMajor + " to " + targetMajor + " for runtime compatibility");
    }

    return normalized;
  }

  function createBootstrapHtml(wasmBytes, mainClass) {
    var wasmBlobUrl = URL.createObjectURL(new Blob([wasmBytes], { type: "application/wasm" }));
    var runtimeUrl = assetPaths.compilerRuntime;

    return [
      "<!doctype html>",
      "<html lang='en'>",
      "<head>",
      "  <meta charset='utf-8'>",
      "  <meta name='viewport' content='width=device-width, initial-scale=1'>",
      "  <title>TeaVM Output</title>",
      "  <style>",
      "    body { margin: 0; background: #f8f0e4; color: #26170a; font-family: Georgia, serif; }",
      "    .shell { padding: 18px; }",
      "    p, pre { margin: 0 0 8px; line-height: 1.45; white-space: pre-wrap; }",
      "  </style>",
      "</head>",
      "<body>",
      "  <div class='shell'><p>Running TeaVM output...</p><pre id='log'></pre></div>",
      "  <script type='module'>",
      "    import { load } from '" + runtimeUrl + "';",
      "    const logNode = document.getElementById('log');",
      "    const write = (value) => { logNode.textContent += value + '\\n'; console.log(value); };",
      "    const app = await load('" + wasmBlobUrl + "');",
      "    const exportsObject = app && app.exports ? app.exports : (app && app.instance ? app.instance.exports : null);",
      "    const exportKeys = exportsObject ? Object.keys(exportsObject) : [];",
      "    write('TeaVM exports: ' + (exportKeys.length ? exportKeys.join(', ') : '(none)'));",
      "    const desiredMainClass = " + JSON.stringify(mainClass) + ";",
      "    const candidates = [];",
      "    if (exportsObject) {",
      "      if (typeof exportsObject.main === 'function') candidates.push({ name: 'main', fn: exportsObject.main });",
      "      if (typeof exportsObject.start === 'function') candidates.push({ name: 'start', fn: exportsObject.start });",
      "      exportKeys.forEach((key) => {",
      "        if (typeof exportsObject[key] !== 'function') return;",
      "        const lower = key.toLowerCase();",
      "        if (lower === 'main' || lower === 'start') return;",
      "        if (lower.includes('main') || lower.includes(desiredMainClass.toLowerCase())) {",
      "          candidates.push({ name: key, fn: exportsObject[key] });",
      "        }",
      "      });",
      "    }",
      "    const seen = new Set();",
      "    const uniqueCandidates = candidates.filter((candidate) => {",
      "      if (seen.has(candidate.name)) return false;",
      "      seen.add(candidate.name);",
      "      return true;",
      "    });",
      "    if (!uniqueCandidates.length) {",
      "      write('No callable main export was found.');",
      "      throw new Error('TeaVM module loaded, but no callable main export was found.');",
      "    }",
      "    const entry = uniqueCandidates[0];",
      "    write('Invoking export: ' + entry.name);",
      "    document.body.innerHTML = \"<pre id=\\\"log\\\"></pre>\";",
      "    try {",
      "      if (entry.fn.length > 0) {",
      "        entry.fn([]);",
      "      } else {",
      "        entry.fn();",
      "      }",
      "    } catch (error) {",
      "      const target = document.getElementById('log');",
      "      if (target) target.textContent = (error && error.stack) ? error.stack : String(error);",
      "      throw error;",
      "    }",
      "  </script>",
      "</body>",
      "</html>"
    ].join("\n");
  }

  function joinLogs(phaseLog, diagnostics, fallback) {
    var sections = [];
    if (phaseLog.length) {
      sections.push("Phase log:\n" + phaseLog.join("\n"));
    }
    if (diagnostics.length) {
      sections.push("Diagnostics:\n" + diagnostics.map(formatDiagnostic).join("\n"));
    }
    if (!sections.length && fallback) {
      sections.push(fallback);
    }
    return sections.join("\n\n");
  }

  function recordPhase(phaseLog, message) {
    phaseLog.push("- " + message);
  }

  function normalizeClassName(className) {
    return String(className || "").replace(/\//g, ".");
  }

  async function compile(request) {
    var phaseLog = [];
    recordPhase(phaseLog, "Loading teavm-javac runtime");
    var state = await getCompilerState();
    var compiler = state.compiler;
    var diagnostics = [];
    var classpathEntries = Array.isArray(request.classpathEntries) ? request.classpathEntries : [];
    var listenerRegistration = compiler.onDiagnostic(function (diagnostic) {
      diagnostics.push({
        type: diagnostic.type,
        severity: diagnostic.severity,
        fileName: diagnostic.fileName,
        lineNumber: diagnostic.lineNumber,
        message: diagnostic.message
      });
    });

    try {
      recordPhase(phaseLog, "Clearing compiler state");
      compiler.clearSourceFiles();
      compiler.clearInputClassFiles();
      compiler.clearOutputFiles();

      recordPhase(phaseLog, "Adding source files: " + request.files.map(function (file) {
        return file.path;
      }).join(", "));
      request.files.forEach(function (file) {
        compiler.addSourceFile(file.path, file.content);
      });

      if (classpathEntries.length) {
        recordPhase(phaseLog, "Loading classpath jars: " + classpathEntries.map(function (entry) {
          return entry.path;
        }).join(", "));
      }

      for (var i = 0; i < classpathEntries.length; ++i) {
        var classpathEntry = classpathEntries[i];
        var jarBytes = await getClasspathBinary(classpathEntry);
        compiler.addJarFile(jarBytes);
      }

      recordPhase(phaseLog, "Running javac");
      if (!compiler.compile()) {
        return {
          status: "compile-error",
          log: joinLogs(phaseLog, diagnostics, "javac compilation failed."),
          diagnostics: diagnostics,
          outputs: []
        };
      }

      recordPhase(phaseLog, "Detecting main classes");
      var mainClasses = compiler.detectMainClasses().map(normalizeClassName);
      var requestedMainClass = normalizeClassName(request.entryClass);
      var mainClass = requestedMainClass;
      if (mainClasses.indexOf(requestedMainClass) < 0 && mainClasses.length > 0) {
        mainClass = mainClasses[0];
      }
      recordPhase(phaseLog, "Detected main classes: " + (mainClasses.length ? mainClasses.join(", ") : "(none)"));
      recordPhase(phaseLog, "Using main class: " + mainClass);

      recordPhase(phaseLog, "Collecting javac output files");
      var classOutputNames = typeof compiler.listOutputFiles === "function"
        ? compiler.listOutputFiles()
        : compiler.listOutputFiles || [];
      var classOutputEntries = normalizeNameList(classOutputNames).map(function (name) {
        return {
          path: name,
          content: compiler.getOutputFile(name)
        };
      }).filter(function (entry) {
        return entry.content && entry.content.length;
      });
      classOutputEntries = normalizeClassOutputsForTarget(classOutputEntries, request, phaseLog);
      var classOutputs = classOutputEntries.map(function (entry) {
        return {
          path: entry.path,
          bytes: entry.content.length
        };
      });
      var outputJar = compiler.getOutputJar ? compiler.getOutputJar() : null;
      if (request.target === "java-bytecode" && classOutputEntries.length) {
        outputJar = buildOutputJarFromFiles(classOutputEntries);
        recordPhase(phaseLog, "Repacked output jar from normalized class files for CheerpJ");
      } else if ((!outputJar || !outputJar.length) && classOutputEntries.length) {
        outputJar = buildOutputJarFromFiles(classOutputEntries);
      }
      var cheerpjArtifact = outputJar && outputJar.length ? {
        mainClass: mainClass,
        jarBase64: toBase64(outputJar),
        jarFileName: (request.outputName || "app") + ".jar",
        classpath: classpathEntries.map(function (entry) {
          return entry.cheerpjPath || null;
        }).filter(function (entry) {
          return !!entry;
        })
      } : null;
      recordPhase(phaseLog, "javac output file count: " + classOutputs.length);
      recordPhase(phaseLog, "javac output jar bytes: " + (outputJar ? outputJar.length : 0));

      var javacOutputs = classOutputs.slice();
      if (outputJar && outputJar.length) {
        javacOutputs.push({
          path: (request.outputName || "app") + ".jar",
          bytes: outputJar.length
        });
      }

      if (request.target === "java-bytecode") {
        recordPhase(phaseLog, "Skipping WebAssembly generation for Java bytecode target");
        return {
          status: "compiled",
          log: joinLogs(phaseLog, diagnostics, [
            "Compiled sketch with teavm-javac.",
            "Detected main class: " + mainClass,
            "Prepared Java bytecode for the CheerpJ runtime.",
            "Output jar bytes: " + (outputJar ? outputJar.length : 0)
          ].join("\n")),
          diagnostics: diagnostics,
          outputs: javacOutputs,
          classOutputs: classOutputs,
          cheerpj: cheerpjArtifact
        };
      }

      recordPhase(phaseLog, "Generating WebAssembly");
      if (!compiler.generateWebAssembly({
        outputName: request.outputName || "app",
        mainClass: mainClass
      })) {
        return {
          status: "compile-error",
          log: joinLogs(phaseLog, diagnostics, "TeaVM generation failed."),
          diagnostics: diagnostics,
          outputs: []
        };
      }

      recordPhase(phaseLog, "Collecting WebAssembly output files");
      var outputNames = compiler.listWebAssemblyOutputFiles();
      var outputs = summarizeOutputFiles(outputNames, function (name) {
        return compiler.getWebAssemblyOutputFile(name);
      });
      var wasmBytes = compiler.getWebAssemblyOutputFile((request.outputName || "app") + ".wasm");

      return {
        status: "compiled",
        log: joinLogs(phaseLog, diagnostics, [
          "Compiled sketch with teavm-javac.",
          "Detected main class: " + mainClass,
          diagnostics.length ? "Diagnostics emitted: " + diagnostics.length : "No diagnostics emitted."
        ].join("\n")),
        diagnostics: diagnostics,
        outputs: outputs,
        classOutputs: classOutputs,
        cheerpj: cheerpjArtifact,
        bootstrapHtml: createBootstrapHtml(wasmBytes, mainClass)
      };
    } catch (error) {
      return {
        status: "compile-error",
        log: joinLogs(phaseLog, diagnostics, "Compiler crashed.") + "\n\nThrown error:\n" + ((error && error.stack) ? error.stack : String(error)),
        diagnostics: diagnostics,
        outputs: []
      };
    } finally {
      if (listenerRegistration && typeof listenerRegistration.destroy === "function") {
        listenerRegistration.destroy();
      }
    }
  }

  async function selfTest() {
    return compile({
      entryClass: "canary.Main",
      outputName: "canary",
      files: [
        {
          path: "Main.java",
          content: [
            "package canary;",
            "",
            "public class Main {",
            "  public static void main(String[] args) {",
            "    int x = 2 + 2;",
            "    if (x == 4) {",
            "      x = x + 1;",
            "    }",
            "  }",
            "}"
          ].join("\n")
        }
      ],
      classpathEntries: []
    });
  }


  async function selfTestJsBody() {
    return compile({
      entryClass: "canary.Main",
      outputName: "canary-jsbody",
      files: [
        {
          path: "Main.java",
          content: [
            "package canary;",
            "",
            "import org.teavm.jso.JSBody;",
            "",
            "public class Main {",
            "  @JSBody(script = \"document.body.style.background = '#e8f5e9';\")",
            "  private static native void paint();",
            "",
            "  public static void main(String[] args) {",
            "    paint();",
            "  }",
            "}"
          ].join("\n")
        }
      ],
      classpathEntries: []
    });
  }

  async function selfTestJsoCanvas() {
    return compile({
      entryClass: "canary.Main",
      outputName: "canary-jso-canvas",
      files: [
        {
          path: "Main.java",
          content: [
            "package canary;",
            "",
            "import org.teavm.jso.canvas.CanvasRenderingContext2D;",
            "import org.teavm.jso.dom.html.HTMLCanvasElement;",
            "import org.teavm.jso.dom.html.HTMLDocument;",
            "",
            "public class Main {",
            "  public static void main(String[] args) {",
            "    HTMLDocument document = HTMLDocument.current();",
            "    HTMLCanvasElement canvas = (HTMLCanvasElement) document.createElement(\"canvas\");",
            "    canvas.setWidth(320);",
            "    canvas.setHeight(180);",
            "    document.getBody().setInnerHTML(\"\");",
            "    document.getBody().appendChild(canvas);",
            "    CanvasRenderingContext2D ctx = (CanvasRenderingContext2D) canvas.getContext(\"2d\");",
            "    ctx.setFillStyle(\"#222\");",
            "    ctx.fillRect(0, 0, 320, 180);",
            "    ctx.setFillStyle(\"#ff6a3d\");",
            "    ctx.beginPath();",
            "    ctx.save();",
            "    ctx.translate(160, 90);",
            "    ctx.scale(48, 48);",
            "    ctx.arc(0, 0, 1, 0, Math.PI * 2, false);",
            "    ctx.fill();",
            "    ctx.restore();",
            "  }",
            "}"
          ].join("\n")
        }
      ],
      classpathEntries: []
    });
  }

  async function inspectCompilerApi() {
    var state = await getCompilerState();
    var compiler = state.compiler;
    var prototype = Object.getPrototypeOf(compiler);
    var methods = Object.getOwnPropertyNames(prototype)
      .filter(function (name) {
        return name !== "constructor" && typeof compiler[name] === "function";
      })
      .sort();

    return {
      methods: methods,
      methodCount: methods.length
    };
  }

  async function probeClassFileOutputs() {
    var state = await getCompilerState();
    var compiler = state.compiler;
    var methodNames = Object.getOwnPropertyNames(Object.getPrototypeOf(compiler))
      .filter(function (name) {
        return typeof compiler[name] === "function";
      })
      .sort();
    var classRelated = methodNames.filter(function (name) {
      return /class|jar|output|file/i.test(name);
    });

    return {
      allMethods: methodNames,
      classRelatedMethods: classRelated
    };
  }
  if (typeof fetch === "function" && typeof WebAssembly !== "undefined") {
    window.WasmProcessingCompiler = {
      compile: compile,
      selfTest: selfTest,
      selfTestJsBody: selfTestJsBody,
      selfTestJsoCanvas: selfTestJsoCanvas,
      inspectCompilerApi: inspectCompilerApi,
      probeClassFileOutputs: probeClassFileOutputs,
      __test: {
        readClassFileMajorVersion: readClassFileMajorVersion,
        rewriteClassFileMajorVersion: rewriteClassFileMajorVersion,
        normalizeClassOutputsForTarget: normalizeClassOutputsForTarget,
        buildOutputJarFromFiles: buildOutputJarFromFiles,
        selectOutputJar: selectOutputJar
      },
      assets: assetPaths
    };
  }
})();
