var __jsPsychCustomPlugin__ = (() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // assets/custom_plugins/example-rating/index.js
  var index_exports = {};
  __export(index_exports, {
    default: () => ExampleRating
  });

  // assets/custom_plugins/types.js
  var ParameterType = {
    BOOL: 0,
    STRING: 1,
    INT: 2,
    FLOAT: 3,
    FUNCTION: 4,
    KEY: 5,
    KEYS: 6,
    SELECT: 7,
    HTML_STRING: 8,
    IMAGE: 9,
    AUDIO: 10,
    VIDEO: 11,
    OBJECT: 12,
    COMPLEX: 13,
    TIMELINE: 14
  };

  // assets/custom_plugins/example-rating/index.js
  var ExampleRating = class {
    static info = {
      name: "example-rating",
      version: "1.0.0",
      description: "Displays a question with a numeric rating scale.",
      parameters: {
        question: {
          type: ParameterType.HTML_STRING,
          default: void 0,
          array: false,
          description: "The question text (HTML allowed)."
        },
        min: {
          type: ParameterType.INT,
          default: 1,
          array: false,
          description: "Lowest rating value."
        },
        max: {
          type: ParameterType.INT,
          default: 5,
          array: false,
          description: "Highest rating value."
        },
        labels: {
          type: ParameterType.STRING,
          default: null,
          array: true,
          description: "Optional labels for min and max endpoints."
        }
      }
    };
    constructor(jsPsych) {
      this.jsPsych = jsPsych;
    }
    trial(displayElement, trial) {
      const steps = trial.max - trial.min + 1;
      const buttons = Array.from({ length: steps }, (_, i) => {
        const val = trial.min + i;
        return `<button class="jspsych-btn" style="margin:4px" data-val="${val}">${val}</button>`;
      }).join("");
      const labelRow = trial.labels && trial.labels.length >= 2 ? `<div style="display:flex;justify-content:space-between;margin-top:4px">
             <small>${trial.labels[0]}</small>
             <small>${trial.labels[trial.labels.length - 1]}</small>
           </div>` : "";
      displayElement.innerHTML = `
      <div style="text-align:center;padding:2rem">
        <div style="margin-bottom:1.5rem">${trial.question}</div>
        <div id="rating-row">${buttons}</div>
        ${labelRow}
      </div>
    `;
      const startTime = performance.now();
      displayElement.querySelectorAll("[data-val]").forEach((btn) => {
        btn.addEventListener("click", () => {
          this.jsPsych.finishTrial({
            rt: Math.round(performance.now() - startTime),
            response: parseInt(btn.dataset.val, 10),
            question: trial.question
          });
        });
      });
    }
  };
  return __toCommonJS(index_exports);
})();
var jsPsychExampleRating = __jsPsychCustomPlugin__.default ?? __jsPsychCustomPlugin__;
