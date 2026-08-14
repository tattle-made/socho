import { ParameterType } from '../types.js';

export default class MultiImageSelect {
  static info = {
    name: 'multi-image-select',
    version: '2.0.0',
    description: 'Shows a configurable grid of images; participants click to select one or more.',
    parameters: {
      images: {
        type: ParameterType.IMAGE,
        default: undefined,
        array: true,
        description: 'Array of image URLs to display in the grid.',
      },
      prompt: {
        type: ParameterType.HTML_STRING,
        default: null,
        array: false,
        description: 'Instructions or question shown above the image grid (HTML allowed).',
      },
      button_label: {
        type: ParameterType.STRING,
        default: 'Continue',
        array: false,
        description: 'Label for the submit button.',
      },
      required: {
        type: ParameterType.BOOL,
        default: false,
        array: false,
        description: 'If true, participant must select at least one image before continuing.',
      },
      multiple_select: {
        type: ParameterType.BOOL,
        default: false,
        array: false,
        description: 'If true, participant may select more than one image.',
      },
      columns: {
        type: ParameterType.INT,
        default: 3,
        array: false,
        description: 'Number of grid columns. Set to 0 for auto-fit based on image_width.',
      },
      image_width: {
        type: ParameterType.INT,
        default: 240,
        array: false,
        description: 'Width of each image in pixels (also used as min-width for auto-fit).',
      },
      image_height: {
        type: ParameterType.INT,
        default: 180,
        array: false,
        description: 'Height of each image in pixels.',
      },
    },
  };

  constructor(jsPsych) {
    this.jsPsych = jsPsych;
  }

  trial(displayElement, trial) {
    const startTime = performance.now();
    const images = trial.images || [];
    const multipleSelect = trial.multiple_select || false;

    const imageHTML = images
      .map(
        (src, i) => `
        <div
          class="mi-image-cell"
          data-index="${i}"
          style="
            width:${trial.image_width}px;
            height:${trial.image_height}px;
            overflow:hidden;
            border-radius:6px;
            background:#f0f0f0;
            cursor:pointer;
            border:3px solid transparent;
            transition:border-color 0.15s, box-shadow 0.15s;
            box-sizing:border-box;
            flex-shrink:0;
          "
        >
          <img
            src="${src}"
            style="width:100%;height:100%;object-fit:contain;display:block;pointer-events:none;"
            alt=""
            draggable="false"
          />
        </div>`
      )
      .join('');

    displayElement.innerHTML = `
      <div style="display:flex;flex-direction:column;align-items:center;width:100%;padding:2rem 1.5rem;box-sizing:border-box;">
        ${trial.prompt ? `<div style="margin-bottom:1.25rem;font-size:1.05rem;text-align:center;">${trial.prompt}</div>` : ''}

        <div id="mi-grid" style="
          display:flex;
          flex-wrap:wrap;
          justify-content:center;
          gap:12px;
          margin-bottom:1.5rem;
        ">
          ${imageHTML}
        </div>

        ${multipleSelect ? `
        <p id="mi-error" style="color:#e53e3e;font-size:0.9rem;text-align:center;display:none;margin-bottom:0.75rem;">
          Please select an image to continue.
        </p>
        <div style="text-align:center;margin-top:1rem;">
          <button id="mi-btn" class="jspsych-btn">${trial.button_label}</button>
        </div>` : ''}
      </div>
    `;

    const finish = (idx) => {
      this.jsPsych.finishTrial({
        rt: Math.round(performance.now() - startTime),
        response: images[idx],
        response_index: idx,
        images: trial.images,
        num_images: images.length,
      });
    };

    const cells = displayElement.querySelectorAll('.mi-image-cell');

    if (!multipleSelect) {
      cells.forEach(cell => {
        cell.addEventListener('click', () => finish(parseInt(cell.dataset.index, 10)));
      });
      return;
    }

    const selected = new Set();
    const errEl = displayElement.querySelector('#mi-error');

    cells.forEach(cell => {
      cell.addEventListener('click', () => {
        const idx = parseInt(cell.dataset.index, 10);

        if (selected.has(idx)) {
          selected.delete(idx);
          cell.style.border = '3px solid transparent';
          cell.style.boxShadow = '';
        } else {
          selected.add(idx);
          cell.style.border = '3px solid #4a90e2';
          cell.style.boxShadow = '0 0 0 2px #b3d4f5';
        }

        if (errEl) errEl.style.display = 'none';
      });
    });

    displayElement.querySelector('#mi-btn').addEventListener('click', () => {
      if (trial.required && selected.size === 0) {
        if (errEl) errEl.style.display = 'block';
        return;
      }

      const sortedIndices = Array.from(selected).sort((a, b) => a - b);

      this.jsPsych.finishTrial({
        rt: Math.round(performance.now() - startTime),
        response: sortedIndices.map(i => images[i]),
        response_index: sortedIndices,
        images: trial.images,
        num_images: images.length,
      });
    });
  }
}
