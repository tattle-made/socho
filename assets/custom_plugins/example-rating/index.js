/**
 * Example custom jsPsych plugin: a simple numeric rating scale.
 *
 * To create your own plugin:
 *   1. Copy this folder and rename it (e.g. assets/custom_plugins/my-plugin/)
 *   2. Edit index.js — update `info` and implement `trial()`
 *   3. Run:  node assets/setup_jspsych.mjs
 *   4. The plugin will appear in the Builder UI automatically.
 *
 * Naming convention: the folder name becomes the plugin identifier in the
 * Builder (e.g. "example-rating").  The JS global is derived automatically
 * (e.g. jsPsychExampleRating).
 */

import { ParameterType } from '../types.js';

export default class ExampleRating {
  static info = {
    name: 'example-rating',
    version: '1.0.0',
    description: 'Displays a question with a numeric rating scale.',
    parameters: {
      question: {
        type: ParameterType.HTML_STRING,
        default: undefined,
        array: false,
        description: 'The question text (HTML allowed).',
      },
      min: {
        type: ParameterType.INT,
        default: 1,
        array: false,
        description: 'Lowest rating value.',
      },
      max: {
        type: ParameterType.INT,
        default: 5,
        array: false,
        description: 'Highest rating value.',
      },
      labels: {
        type: ParameterType.STRING,
        default: null,
        array: true,
        description: 'Optional labels for min and max endpoints.',
      },
    },
  };

  constructor(jsPsych) {
    this.jsPsych = jsPsych;
  }

  trial(displayElement, trial) {
    const steps = trial.max - trial.min + 1;

    const buttons = Array.from({ length: steps }, (_, i) => {
      const val = trial.min + i;
      return `<button class="jspsych-btn" style="margin:4px" data-val="${val}">${val}</button>`;
    }).join('');

    const labelRow =
      trial.labels && trial.labels.length >= 2
        ? `<div style="display:flex;justify-content:space-between;margin-top:4px">
             <small>${trial.labels[0]}</small>
             <small>${trial.labels[trial.labels.length - 1]}</small>
           </div>`
        : '';

    displayElement.innerHTML = `
      <div style="text-align:center;padding:2rem">
        <div style="margin-bottom:1.5rem">${trial.question}</div>
        <div id="rating-row">${buttons}</div>
        ${labelRow}
      </div>
    `;

    const startTime = performance.now();

    displayElement.querySelectorAll('[data-val]').forEach(btn => {
      btn.addEventListener('click', () => {
        this.jsPsych.finishTrial({
          rt: Math.round(performance.now() - startTime),
          response: parseInt(btn.dataset.val, 10),
          question: trial.question,
        });
      });
    });
  }
}
