(function () {
  var runtimeSource = "p5de-processing-runtime";
  var frameSource = "p5de-processing-runtime-frame";
  var flutterSource = "p5de-flutter-runtime";
  var sketchLineOffset = 10;
  var runGeneration = 0;
  var lastRunPayload = null;
  var ready = false;

  var frame = document.getElementById("runtimeFrame");
  var message = document.getElementById("runtimeMessage");
  var stage = document.getElementById("runtimeStage");
  var activeViewportConfig = null;

  function normalizePayload(raw) {
    if (!raw) {
      return {};
    }
    if (typeof raw === "string") {
      try {
        return JSON.parse(raw) || {};
      } catch (_error) {
        return {};
      }
    }
    if (typeof raw === "object") {
      return raw;
    }
    return {};
  }

  function post(name, payload) {
    var nextPayload = payload || {};
    var envelope = {
      source: runtimeSource,
      name: name,
      payload: nextPayload
    };

    if (window.flutter_inappwebview && typeof window.flutter_inappwebview.callHandler === "function") {
      window.flutter_inappwebview.callHandler(name, JSON.stringify(nextPayload));
    }

    if (window.parent && window.parent !== window) {
      window.parent.postMessage(JSON.stringify(envelope), "*");
    }
  }

  function setMessage(text, presentation) {
    message.textContent = text || "";
    message.classList.toggle("is-error", presentation === "error");
    message.classList.toggle("is-hidden", !text);
    frame.classList.toggle("is-hidden", !!text);
  }

  function mapDiagnostic(diagnostic) {
    var line = typeof diagnostic.lineNumber === "number" ? diagnostic.lineNumber : null;
    var fileName = diagnostic.fileName || null;
    if (fileName && /Sketch\.java$/i.test(fileName) && line && line > sketchLineOffset) {
      return Object.assign({}, diagnostic, {
        fileName: "Sketch.pde",
        lineNumber: line - sketchLineOffset
      });
    }
    return diagnostic;
  }

  function mappedDiagnostics(result) {
    return (result && Array.isArray(result.diagnostics) ? result.diagnostics : []).map(mapDiagnostic);
  }

  function summarizeDiagnostics(diagnostics) {
    if (!diagnostics.length) {
      return "";
    }
    return diagnostics.map(function (diagnostic) {
      var location = diagnostic.fileName || "Sketch.pde";
      if (diagnostic.lineNumber) {
        location += ":" + diagnostic.lineNumber;
        if (diagnostic.columnNumber) {
          location += ":" + diagnostic.columnNumber;
        }
      }
      return location + " - " + (diagnostic.message || "Compiler diagnostic");
    }).join("\n");
  }

  function runtimeErrorText(payload) {
    var errorPayload = payload || {};
    var diagnosticsText = summarizeDiagnostics(
      Array.isArray(errorPayload.diagnostics) ? errorPayload.diagnostics : []
    );
    if (diagnosticsText) {
      return diagnosticsText;
    }

    var messageText = String(errorPayload.message || "").trim();
    var stackText = stripPhaseLog(errorPayload.stack);
    if (stackText) {
      return stackText;
    }

    var logText = stripPhaseLog(errorPayload.log);
    if (logText) {
      if (!messageText || messageText === "Processing Java compile error.") {
        return logText;
      }
      return logText.indexOf(messageText) >= 0
        ? logText
        : messageText + "\n\n" + logText;
    }

    return messageText || "Processing Java runtime error.";
  }

  function showRuntimeError(payload) {
    setMessage(runtimeErrorText(payload), "error");
  }

  function logResult(result) {
    var log = result && result.log ? String(result.log) : "";
    var diagnosticsText = summarizeDiagnostics(mappedDiagnostics(result));
    var text = diagnosticsText || stripPhaseLog(log);
    if (text.trim()) {
      post("runtimeLog", {
        level: result && result.status === "compile-error" ? "error" : "info",
        message: text.trim()
      });
    }
  }

  function stripPhaseLog(text) {
    return String(text || "")
      .replace(/(^|\n)Phase log:\n(?:- .*(?:\n|$))+/g, "$1")
      .trim();
  }

  function createFrameBridgeScript(generation) {
    var bridge = function (source, activeGeneration) {
      function send(name, payload) {
        var nextPayload = payload || {};
        nextPayload.generation = activeGeneration;
        window.parent.postMessage(JSON.stringify({
          source: source,
          name: name,
          payload: nextPayload
        }), "*");
      }

      function serializeArgs(args) {
        return Array.prototype.slice.call(args).map(function (value) {
          if (value instanceof Error) {
            return value.stack || value.message;
          }
          if (typeof value === "object") {
            try {
              return JSON.stringify(value);
            } catch (_error) {
              return String(value);
            }
          }
          return String(value);
        }).join(" ");
      }

      var originalLog = console.log;
      var originalWarn = console.warn;
      var originalError = console.error;

      console.log = function () {
        send("runtimeLog", { level: "info", message: serializeArgs(arguments) });
        originalLog.apply(console, arguments);
      };
      console.warn = function () {
        send("runtimeLog", { level: "warning", message: serializeArgs(arguments) });
        originalWarn.apply(console, arguments);
      };
      console.error = function () {
        send("runtimeLog", { level: "error", message: serializeArgs(arguments) });
        originalError.apply(console, arguments);
      };

      window.addEventListener("error", function (event) {
        send("runtimeError", {
          message: event.message || String(event.error || "Runtime error"),
          stack: event.error && event.error.stack ? event.error.stack : null,
          line: event.lineno || null,
          column: event.colno || null
        });
      });

      window.addEventListener("unhandledrejection", function (event) {
        var reason = event.reason;
        send("runtimeError", {
          message: reason && reason.message ? reason.message : String(reason || "Unhandled promise rejection"),
          stack: reason && reason.stack ? reason.stack : null
        });
      });

      var firstFrameSent = false;
      function waitForFirstFrame(attempt) {
        if (firstFrameSent) {
          return;
        }
        var canvas = document.querySelector("canvas");
        if (canvas) {
          window.requestAnimationFrame(function () {
            window.requestAnimationFrame(function () {
              if (!firstFrameSent) {
                firstFrameSent = true;
                send("runtimeFirstFrame", {});
              }
            });
          });
          return;
        }
        if (attempt < 120) {
          window.setTimeout(function () {
            waitForFirstFrame(attempt + 1);
          }, 50);
        }
      }

      window.addEventListener("DOMContentLoaded", function () {
        waitForFirstFrame(0);
      });
      window.setTimeout(function () {
        waitForFirstFrame(0);
      }, 0);
    };

    return "<script>(" + bridge.toString() + ")(" + JSON.stringify(frameSource) + "," + JSON.stringify(generation) + ");<\/script>";
  }

  function createPreviewFitStyle() {
    return [
      "<style id=\"p5de-preview-fit-style\">",
      "  html, body {",
      "    width: 100% !important;",
      "    height: 100% !important;",
      "    margin: 0 !important;",
      "    overflow: hidden !important;",
      "    background: #f8f0e4 !important;",
      "  }",
      "  body {",
      "    display: grid !important;",
      "    place-items: stretch !important;",
      "  }",
      "  canvas {",
      "    display: block !important;",
      "    width: 100% !important;",
      "    height: 100% !important;",
      "    max-width: none !important;",
      "    margin: 0 !important;",
      "    object-fit: fill !important;",
      "    touch-action: none !important;",
      "  }",
      "  #log {",
      "    display: none !important;",
      "  }",
      "</style>"
    ].join("\n");
  }

  function normalizeViewportConfig(raw) {
    if (!raw || raw.mode !== "physical") {
      return null;
    }
    var rawWidth = Number(raw.width);
    var rawHeight = Number(raw.height);
    var rawDevicePixelRatio = Number(raw.devicePixelRatio);
    if (!Number.isFinite(rawWidth) || rawWidth <= 0 ||
        !Number.isFinite(rawHeight) || rawHeight <= 0) {
      return null;
    }
    return {
      mode: "physical",
      width: Math.max(1, Math.round(rawWidth)),
      height: Math.max(1, Math.round(rawHeight)),
      devicePixelRatio: Number.isFinite(rawDevicePixelRatio) && rawDevicePixelRatio > 0
        ? rawDevicePixelRatio
        : 1
    };
  }

  function updatePhysicalFrameTransform() {
    if (!activeViewportConfig) {
      return;
    }
    var stageWidth = Math.max(1, stage.clientWidth);
    var stageHeight = Math.max(1, stage.clientHeight);
    frame.style.transform = "scale(" +
      (stageWidth / activeViewportConfig.width) + "," +
      (stageHeight / activeViewportConfig.height) + ")";
  }

  function configurePreviewFrame(viewportConfig) {
    activeViewportConfig = viewportConfig;
    frame.style.removeProperty("inset");
    frame.style.removeProperty("right");
    frame.style.removeProperty("bottom");
    frame.style.removeProperty("transform");
    frame.style.removeProperty("transform-origin");

    if (!viewportConfig) {
      frame.style.left = "0";
      frame.style.top = "0";
      frame.style.width = "100%";
      frame.style.height = "100%";
      return;
    }

    // Give the child browsing context a physical-pixel-sized CSS viewport.
    // Scaling the iframe back to the visible stage keeps one sketch pixel
    // aligned with one device pixel without adding JS interop to PApplet.
    frame.style.left = "0";
    frame.style.top = "0";
    frame.style.right = "auto";
    frame.style.bottom = "auto";
    frame.style.width = viewportConfig.width + "px";
    frame.style.height = viewportConfig.height + "px";
    frame.style.transformOrigin = "0 0";
    updatePhysicalFrameTransform();
  }

  function instrumentBootstrapHtml(html, generation) {
    var bridgeScript = createFrameBridgeScript(generation);
    var fitStyle = createPreviewFitStyle();
    if (html.indexOf("</head>") >= 0) {
      return html.replace("</head>", fitStyle + "\n" + bridgeScript + "\n</head>");
    }
    return fitStyle + "\n" + bridgeScript + html;
  }

  async function runProcessingJava(payload) {
    var code = payload && typeof payload.code === "string" ? payload.code : "";
    var viewportConfig = normalizeViewportConfig(payload && payload.viewport);
    var generation = ++runGeneration;
    lastRunPayload = viewportConfig
      ? { code: code, viewport: viewportConfig }
      : { code: code };
    post("runtimeStatusChanged", { status: "compiling" });
    setMessage("Compiling Processing Java sketch...");

    try {
      if (typeof window.compileProcessingToWasmTarget !== "function") {
        throw new Error("Processing Java compiler adapter is not loaded.");
      }

      var result = await window.compileProcessingToWasmTarget(code, "teavm");
      if (generation !== runGeneration) {
        return;
      }

      logResult(result);

      if (!result || result.status !== "compiled") {
        var diagnostics = mappedDiagnostics(result);
        var compileError = {
          message: diagnostics.length ? diagnostics[0].message : "Processing Java compile error.",
          diagnostics: diagnostics,
          log: result && result.log ? result.log : null
        };
        showRuntimeError(compileError);
        post("runtimeError", compileError);
        post("runtimeStatusChanged", { status: "failure" });
        return;
      }

      var bootstrapHtml = result.bootstrapHtml || (result.artifact && result.artifact.bootstrapHtml);
      if (!bootstrapHtml) {
        throw new Error("Compiled Processing Java artifact did not include runnable HTML.");
      }

      post("runtimeStatusChanged", { status: "loading" });
      setMessage("");
      configurePreviewFrame(viewportConfig);
      frame.srcdoc = instrumentBootstrapHtml(bootstrapHtml, generation);
    } catch (error) {
      if (generation !== runGeneration) {
        return;
      }
      var messageText = error && error.stack ? error.stack : String(error);
      var runtimeError = {
        message: error && error.message ? error.message : String(error),
        stack: messageText
      };
      showRuntimeError(runtimeError);
      post("runtimeError", runtimeError);
      post("runtimeStatusChanged", { status: "failure" });
    }
  }

  function stopRuntime() {
    runGeneration += 1;
    configurePreviewFrame(null);
    frame.removeAttribute("srcdoc");
    frame.src = "about:blank";
    setMessage("Runtime stopped");
    post("runtimeStatusChanged", { status: "stopped" });
  }

  function restartRuntime() {
    if (lastRunPayload) {
      runProcessingJava(lastRunPayload);
    }
  }

  function handleFrameMessage(event) {
    var data = normalizePayload(event.data);
    if (data.source !== frameSource) {
      return;
    }

    var payload = normalizePayload(data.payload);
    if (payload.generation !== runGeneration) {
      return;
    }

    if (data.name === "runtimeFirstFrame") {
      post("runtimeFirstFrame", {});
      post("runtimeStatusChanged", { status: "running" });
      return;
    }

    post(data.name, payload);
    if (data.name === "runtimeError") {
      showRuntimeError(payload);
      post("runtimeStatusChanged", { status: "failure" });
    }
  }

  function handleHostMessage(event) {
    var data = normalizePayload(event.data);
    if (data.source === frameSource) {
      handleFrameMessage(event);
      return;
    }
    if (data.source !== flutterSource) {
      return;
    }

    var payload = normalizePayload(data.payload);
    if (data.command === "ping") {
      signalReady();
    } else if (data.command === "runProcessingJava") {
      runProcessingJava(payload);
    } else if (data.command === "stop") {
      stopRuntime();
    } else if (data.command === "restart") {
      restartRuntime();
    } else if (data.command === "showError") {
      showRuntimeError(payload);
    }
  }

  window.addEventListener("message", handleHostMessage);
  window.addEventListener("resize", updatePhysicalFrameTransform);

  window.P5deProcessingRuntime = {
    runProcessingJava: runProcessingJava,
    stop: stopRuntime,
    restart: restartRuntime,
    showError: function (text) {
      showRuntimeError({ message: text });
    }
  };

  function signalReady() {
    if (!ready) {
      ready = true;
      setMessage("Runtime ready");
    }
    post("runtimeReady", { ready: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", signalReady);
  } else {
    signalReady();
  }
})();
