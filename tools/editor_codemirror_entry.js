import {
  defaultKeymap,
  history,
  historyKeymap,
  redo,
  undo,
} from "@codemirror/commands";
import { javascript } from "@codemirror/lang-javascript";
import { java } from "@codemirror/lang-java";
import {
  bracketMatching,
  defaultHighlightStyle,
  indentOnInput,
  syntaxHighlighting,
} from "@codemirror/language";
import { openSearchPanel, search, searchKeymap } from "@codemirror/search";
import { EditorState, Transaction } from "@codemirror/state";
import {
  EditorView,
  drawSelection,
  highlightActiveLine,
  highlightSpecialChars,
  keymap,
  lineNumbers,
} from "@codemirror/view";

let view;
let changeTimer;

function languageExtension(language) {
  if (language === "processing_java") {
    return java();
  }
  return javascript();
}

function postMessage(name, payload) {
  const message = JSON.stringify(payload || {});
  if (window.flutter_inappwebview?.callHandler) {
    window.flutter_inappwebview.callHandler(name, message);
    return;
  }
  window.parent?.postMessage(
    JSON.stringify({ source: "p5de-codemirror", name, payload }),
    "*",
  );
}

function notifyCursor() {
  if (!view) return;
  const head = view.state.selection.main.head;
  const line = view.state.doc.lineAt(head);
  postMessage("editorCursorChanged", {
    line: line.number,
    column: head - line.from + 1,
  });
}

function notifyCodeChanged() {
  if (!view) return;
  postMessage("editorCodeChanged", { code: view.state.doc.toString() });
  notifyCursor();
}

function createEditor(options) {
  const mount = document.getElementById("editor");
  const code = options.code || "";
  const language = options.language || "p5js";

  try {
    if (view) {
      view.destroy();
      view = undefined;
    }
    mount.textContent = "";

    view = new EditorView({
      parent: mount,
      state: EditorState.create({
        doc: code,
        extensions: [
          lineNumbers(),
          highlightSpecialChars(),
          history(),
          drawSelection(),
          indentOnInput(),
          bracketMatching(),
          highlightActiveLine(),
          syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
          languageExtension(language),
          search({ top: true }),
          keymap.of([...defaultKeymap, ...historyKeymap, ...searchKeymap]),
          EditorView.lineWrapping,
          EditorView.updateListener.of((update) => {
            if (update.docChanged) {
              window.clearTimeout(changeTimer);
              changeTimer = window.setTimeout(notifyCodeChanged, 120);
            }
            if (update.selectionSet) {
              notifyCursor();
            }
          }),
        ],
      }),
    });

    notifyCursor();
    postMessage("editorReady", { ready: true });
  } catch (error) {
    console.error(error);
    mount.textContent = `Editor failed to load: ${error?.message || error}`;
  }
}

function setCode(code) {
  if (!view) return;
  view.dispatch({
    changes: { from: 0, to: view.state.doc.length, insert: code || "" },
  });
  notifyCodeChanged();
}

function getCode() {
  return view?.state.doc.toString() || "";
}

function insertText(text, cursorOffset) {
  if (!view) return;
  const inserted = text || "";
  const offset =
    Number.isInteger(cursorOffset) && cursorOffset >= 0
      ? cursorOffset
      : inserted.length;
  const selection = view.state.selection.main;
  view.dispatch({
    changes: { from: selection.from, to: selection.to, insert: inserted },
    selection: { anchor: selection.from + offset },
    annotations: Transaction.userEvent.of("input.type"),
  });
  view.focus();
}

function focus() {
  view?.focus();
}

function runCommand(command) {
  if (!view) return;
  if (command === "undo") {
    undo(view);
  }
  if (command === "redo") {
    redo(view);
  }
  if (command === "find") {
    openSearchPanel(view);
  }
  view.focus();
  notifyCursor();
}

window.P5deEditor = {
  createEditor,
  focus,
  getCode,
  insertText,
  runCommand,
  setCode,
};

window.addEventListener("message", (event) => {
  const data =
    typeof event.data === "string" ? JSON.parse(event.data) : event.data || {};
  if (data.source !== "p5de-flutter") return;

  const payload = data.payload || {};
  if (data.command === "createEditor") {
    createEditor(payload);
  }
  if (data.command === "setCode") {
    setCode(payload.code || "");
  }
  if (data.command === "insertText") {
    insertText(payload.text || "", payload.cursorOffset);
  }
  if (data.command === "runCommand") {
    runCommand(payload.command || "");
  }
  if (data.command === "focus") {
    focus();
  }
});
