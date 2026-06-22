import {
  deleteTrailingWhitespace,
  defaultKeymap,
  history,
  historyKeymap,
  indentWithTab,
  insertTab,
  redo,
  undo,
} from "@codemirror/commands";
import { javascript } from "@codemirror/lang-javascript";
import { java } from "@codemirror/lang-java";
import {
  bracketMatching,
  defaultHighlightStyle,
  forceParsing,
  indentOnInput,
  indentRange,
  syntaxHighlighting,
} from "@codemirror/language";
import {
  closeSearchPanel,
  findNext,
  findPrevious,
  getSearchQuery,
  openSearchPanel,
  search,
  searchKeymap,
  SearchQuery,
  setSearchQuery,
} from "@codemirror/search";
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

class P5deFindPanel {
  constructor(editorView) {
    this.view = editorView;
    this.query = getSearchQuery(editorView.state);
    this.commit = this.commit.bind(this);
    this.keydown = this.keydown.bind(this);

    this.searchField = document.createElement("input");
    this.searchField.value = this.query.search;
    this.searchField.placeholder = "Find";
    this.searchField.setAttribute("aria-label", "Find");
    this.searchField.setAttribute("main-field", "true");
    this.searchField.className = "cm-textfield p5de-find-input";
    this.searchField.addEventListener("input", this.commit);
    this.searchField.addEventListener("keydown", this.keydown);

    const previousButton = this.createButton("‹", "Previous match", () => {
      this.commit();
      findPrevious(this.view);
    });
    previousButton.classList.add("p5de-find-caret");
    const nextButton = this.createButton("›", "Next match", () => {
      this.commit();
      findNext(this.view);
    });
    nextButton.classList.add("p5de-find-caret");
    const closeButton = this.createButton("×", "Close find", () => {
      closeSearchPanel(this.view);
    });
    closeButton.classList.add("p5de-find-close");

    const topRow = document.createElement("div");
    topRow.className = "p5de-find-row";
    topRow.append(this.searchField, previousButton, nextButton, closeButton);

    this.dom = document.createElement("div");
    this.dom.className = "cm-search p5de-find-panel";
    this.dom.append(topRow);
  }

  createButton(label, ariaLabel, onClick) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "p5de-find-button";
    button.setAttribute("aria-label", ariaLabel);
    button.textContent = label;
    button.addEventListener("click", onClick);
    return button;
  }

  commit() {
    const nextQuery = new SearchQuery({
      search: this.searchField.value,
      caseSensitive: this.query.caseSensitive,
      literal: this.query.literal,
      regexp: this.query.regexp,
      wholeWord: this.query.wholeWord,
    });
    if (!nextQuery.eq(this.query)) {
      this.query = nextQuery;
      this.view.dispatch({ effects: setSearchQuery.of(nextQuery) });
    }
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.commit();
      if (event.shiftKey) {
        findPrevious(this.view);
      } else {
        findNext(this.view);
      }
    }
    if (event.key === "Escape") {
      event.preventDefault();
      closeSearchPanel(this.view);
      this.view.focus();
    }
  }

  update(update) {
    for (const transaction of update.transactions) {
      for (const effect of transaction.effects) {
        if (effect.is(setSearchQuery) && !effect.value.eq(this.query)) {
          this.setQuery(effect.value);
        }
      }
    }
  }

  setQuery(query) {
    this.query = query;
    if (this.searchField.value !== query.search) {
      this.searchField.value = query.search;
    }
  }

  mount() {
    this.searchField.focus();
    this.searchField.select();
  }

  get top() {
    return true;
  }
}

function createFindPanel(editorView) {
  return new P5deFindPanel(editorView);
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
          search({ top: true, createPanel: createFindPanel }),
          keymap.of([
            indentWithTab,
            { key: "Mod-Shift-f", run: formatCode },
            ...defaultKeymap,
            ...historyKeymap,
            ...searchKeymap,
          ]),
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

function formatCode(targetView) {
  const editorView = targetView || view;
  if (!editorView) return false;

  forceParsing(editorView, editorView.state.doc.length, 1000);
  const changes = indentRange(
    editorView.state,
    0,
    editorView.state.doc.length,
  );
  const didIndent = !changes.empty;
  if (didIndent) {
    editorView.dispatch({
      changes,
      annotations: Transaction.userEvent.of("input.format"),
    });
  }

  const didTrim = deleteTrailingWhitespace(editorView);
  editorView.focus();
  notifyCursor();
  if (editorView === view && (didIndent || didTrim)) {
    notifyCodeChanged();
  }
  return true;
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
  if (command === "tab") {
    insertTab(view);
  }
  if (command === "format") {
    formatCode(view);
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

function normalizeHostMessage(raw) {
  try {
    return typeof raw === "string" ? JSON.parse(raw) : raw || {};
  } catch (error) {
    return {};
  }
}

function handleHostMessage(raw) {
  const data = normalizeHostMessage(raw);
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
}

window.addEventListener("message", (event) => handleHostMessage(event.data));

if (window.__p5deQueueMessage) {
  window.removeEventListener("message", window.__p5deQueueMessage);
}
if (Array.isArray(window.__p5deQueuedMessages)) {
  window.__p5deQueuedMessages.forEach(handleHostMessage);
  window.__p5deQueuedMessages.length = 0;
}
