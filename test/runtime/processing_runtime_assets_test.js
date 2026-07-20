const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const workspaceRoot = path.resolve(__dirname, "../..");

function readRuntimeAsset(relativePath) {
  return fs.readFileSync(path.join(workspaceRoot, relativePath), "utf8");
}

function trackedClassList() {
  const classes = new Set();
  return {
    contains(name) {
      return classes.has(name);
    },
    toggle(name, force) {
      if (force) {
        classes.add(name);
      } else {
        classes.delete(name);
      }
    },
  };
}

test("PApplet uses its iframe viewport without JSBody viewport methods", () => {
  const window = {
    location: {
      href: "https://example.test/assets/runtime/processing_java/runtime.html",
    },
  };
  vm.runInNewContext(
    readRuntimeAsset(
      "assets/runtime/processing_java/src/wasmProcessingCompiler.js",
    ),
    { URL, window },
  );

  const request = window.buildTeaVmRequest("void setup() { fullScreen(); }");
  const pApplet = request.files.find((file) => file.path === "PApplet.java");

  assert.ok(pApplet);
  assert.doesNotMatch(pApplet.content, /JSBody/);
  assert.doesNotMatch(pApplet.content, /configuredPhysicalViewport/);
  assert.match(
    pApplet.content,
    /this\.width = Math\.max\(1, Window\.current\(\)\.getInnerWidth\(\)\);/,
  );
});

test("physical preview sizes and scales the child iframe viewport", async () => {
  const listeners = {};
  const style = {
    removeProperty(name) {
      const property = name.replace(/-([a-z])/g, (_, letter) =>
        letter.toUpperCase(),
      );
      delete this[property];
    },
  };
  const frame = {
    classList: { toggle() {} },
    removeAttribute() {},
    set src(value) {
      this._src = value;
    },
    style,
  };
  const message = {
    classList: { toggle() {} },
    textContent: "",
  };
  const stage = { clientWidth: 800, clientHeight: 400 };
  const document = {
    readyState: "complete",
    getElementById(id) {
      return { runtimeFrame: frame, runtimeMessage: message, runtimeStage: stage }[
        id
      ];
    },
  };
  const window = {
    addEventListener(name, listener) {
      listeners[name] = listener;
    },
    compileProcessingToWasmTarget: async () => ({
      status: "compiled",
      bootstrapHtml: "<!doctype html><html><head></head><body></body></html>",
    }),
  };
  window.parent = window;

  vm.runInNewContext(
    readRuntimeAsset("assets/runtime/processing_java/runtime_shell.js"),
    { document, JSON, Number, Object, String, window },
  );

  await window.P5deProcessingRuntime.runProcessingJava({
    code: "void setup() { fullScreen(); }",
    viewport: {
      mode: "physical",
      width: 3200,
      height: 1600,
      devicePixelRatio: 4,
    },
  });

  assert.equal(frame.style.width, "3200px");
  assert.equal(frame.style.height, "1600px");
  assert.equal(frame.style.transform, "scale(0.25,0.25)");
  assert.equal(frame.style.transformOrigin, "0 0");
  assert.doesNotMatch(frame.srcdoc, /__p5deRuntimeViewport/);

  window.P5deProcessingRuntime.stop();
  window.P5deProcessingRuntime.restart();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(frame.style.width, "3200px");
  assert.equal(frame.style.height, "1600px");
});

test("compile errors stay in the runtime surface with top-left presentation", async () => {
  const listeners = {};
  const frame = {
    classList: trackedClassList(),
    style: {
      removeProperty(name) {
        delete this[name];
      },
    },
  };
  const message = {
    classList: trackedClassList(),
    textContent: "",
  };
  const document = {
    readyState: "complete",
    getElementById(id) {
      return {
        runtimeFrame: frame,
        runtimeMessage: message,
        runtimeStage: { clientWidth: 800, clientHeight: 400 },
      }[id];
    },
  };
  const window = {
    addEventListener(name, listener) {
      listeners[name] = listener;
    },
    compileProcessingToWasmTarget: async () => ({
      status: "compile-error",
      diagnostics: [
        {
          fileName: "Sketch.java",
          lineNumber: 17,
          columnNumber: 4,
          message: "expected ';'",
        },
      ],
    }),
  };
  window.parent = window;

  vm.runInNewContext(
    readRuntimeAsset("assets/runtime/processing_java/runtime_shell.js"),
    { document, JSON, Number, Object, String, window },
  );

  await window.P5deProcessingRuntime.runProcessingJava({
    code: "void setup() { fullScreen() }",
  });

  assert.equal(message.textContent, "Sketch.pde:7:4 - expected ';'");
  assert.equal(message.classList.contains("is-error"), true);
  assert.equal(message.classList.contains("is-hidden"), false);
  assert.equal(frame.classList.contains("is-hidden"), true);

  const css = readRuntimeAsset(
    "assets/runtime/processing_java/runtime.css",
  );
  const errorRule = css.match(/\.runtime-message\.is-error\s*{[^}]+}/s)?.[0];
  assert.ok(errorRule);
  assert.match(errorRule, /overflow:\s*auto/);
  assert.match(errorRule, /text-align:\s*left/);
});
